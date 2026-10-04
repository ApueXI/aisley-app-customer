import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_models.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/policies/data/policy_models.dart';
import '../../features/policies/data/policy_repository.dart';
import '../networking/api_client.dart';
import '../networking/api_failure.dart';
import 'token_store.dart';

enum SessionPhase {
  checkingStorage,
  checkingIdentity,
  checkingConsent,
  signedOut,
  signingIn,
  active,
  accountDenied,
  storageUnavailable,
  identityUnavailable,
  consentUnavailable,
  consentRequired,
}

class SessionController extends ChangeNotifier {
  SessionController(this.auth, this.policies, this.store);
  final AuthRepository auth;
  final PolicyRepository policies;
  final TokenStore store;
  SessionPhase phase = SessionPhase.checkingStorage;
  CustomerIdentity? customer;
  ConsentStatus? consent;
  ApiFailure? failure;
  String? notice;
  int generation = 0;
  int _consentQuery = 0;
  SessionLease? _lease;
  bool _deletePending = false,
      _disposed = false,
      _signingIn = false,
      _signingOut = false;
  Future<void>? _bootstrap, _refreshFlight;
  Future<void>? _storageTail;
  final List<VoidCallback> _privateCleanup = [];

  bool get active => phase == SessionPhase.active;
  bool get signingOut => _signingOut;
  bool get checking => const [
    SessionPhase.checkingStorage,
    SessionPhase.checkingIdentity,
    SessionPhase.checkingConsent,
    SessionPhase.signingIn,
  ].contains(phase);
  SessionLease? get verifiedLease => customer != null ? _lease : null;
  void registerPrivateCleanup(VoidCallback callback) =>
      _privateCleanup.add(callback);
  void unregisterPrivateCleanup(VoidCallback callback) =>
      _privateCleanup.remove(callback);

  // Serialize platform operations: a delayed login write must finish before a
  // logout delete, even when the screen/account changed during the write.
  Future<T> _storage<T>(Future<T> Function() action) {
    final result = _storageTail == null
        ? action()
        : _storageTail!.then((_) => action());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _storageTail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_storageTail, tail)) _storageTail = null;
      }),
    );
    return result;
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int epoch) => !_disposed && epoch == generation;
  void _invalidate() {
    generation++;
    _consentQuery++;
    _lease?.cancellation.cancel();
    _lease = null;
    customer = null;
    consent = null;
    _refreshFlight = null;
    _clearPrivateState();
  }

  void _clearPrivateState() {
    for (final cleanup in List<VoidCallback>.of(_privateCleanup)) {
      cleanup();
    }
  }

  Future<void> refreshNavigation() async {
    final lease = active ? verifiedLease : null;
    if (lease == null) return;
    final epoch = generation;
    try {
      final identity = await auth.me(lease);
      if (!_current(epoch) || !active) return;
      if (!identity.isActiveCustomer || identity.id != customer?.id) {
        await _loseIdentity(_denial(identity));
        return;
      }
      customer = identity;
      _emit();
    } on ApiFailure catch (error) {
      if (_current(epoch) && error.identityLost) await _loseIdentity(error);
    }
  }

  SessionLease _newLease(String token, int epoch) => SessionLease(
    token,
    () => _current(epoch),
    (error) => _onPrivateFailure(error, epoch),
  );

  Future<void> bootstrap() => _bootstrap ??= _restore();
  Future<void> _restore() async {
    final epoch = generation;
    phase = SessionPhase.checkingStorage;
    failure = null;
    _emit();
    try {
      final token = await _storage(store.read);
      if (!_current(epoch)) return;
      if (token == null || token.isEmpty) {
        phase = SessionPhase.signedOut;
        _emit();
        return;
      }
      _lease = _newLease(token, epoch);
      await refresh();
    } catch (_) {
      if (_current(epoch)) {
        failure = const ApiFailure(FailureKind.storage);
        phase = SessionPhase.storageUnavailable;
        _emit();
      }
    }
  }

  Future<void> refresh() {
    if (_signingOut || _signingIn) return Future.value();
    final epoch = generation;
    return _refreshFlight ??= _verify().whenComplete(() {
      if (_current(epoch)) _refreshFlight = null;
    });
  }

  Future<void> _verify() async {
    final epoch = generation, lease = _lease;
    if (lease == null) return;
    phase = SessionPhase.checkingIdentity;
    failure = null;
    _emit();
    try {
      final identity = await auth.me(lease);
      if (!_current(epoch)) return;
      if (!identity.isActiveCustomer) {
        await _loseIdentity(_denial(identity));
        return;
      }
      if (customer != null && customer!.id != identity.id) {
        await _loseIdentity(
          const ApiFailure(
            FailureKind.http,
            status: 403,
            code: 'FORBIDDEN_ROLE',
          ),
        );
        return;
      }
      customer = identity;
      await _checkConsent(epoch, lease);
    } on ApiFailure catch (error) {
      if (!_current(epoch)) return;
      if (error.identityLost) {
        await _loseIdentity(error);
        return;
      }
      failure = error;
      phase = SessionPhase.identityUnavailable;
      _emit();
    }
  }

  Future<void> _checkConsent(int epoch, SessionLease lease) async {
    final query = ++_consentQuery;
    phase = SessionPhase.checkingConsent;
    consent = null;
    _emit();
    try {
      final status = await policies.status(lease);
      if (!_current(epoch) || query != _consentQuery) return;
      consent = status;
      failure = null;
      phase = status.allRequiredAccepted
          ? SessionPhase.active
          : SessionPhase.consentRequired;
      if (!status.allRequiredAccepted) _clearPrivateState();
      _emit();
    } on ApiFailure catch (error) {
      if (!_current(epoch) || query != _consentQuery) return;
      if (error.identityLost) {
        await _loseIdentity(error);
        return;
      }
      failure = error;
      phase = SessionPhase.consentUnavailable;
      _clearPrivateState();
      _emit();
    }
  }

  Future<void> refreshConsent() async {
    final lease = verifiedLease;
    if (lease != null && !_signingOut) await _checkConsent(generation, lease);
  }

  ApiFailure _denial(CustomerIdentity identity) => ApiFailure(
    FailureKind.http,
    status: 403,
    code: identity.role != 'customer'
        ? 'FORBIDDEN_ROLE'
        : switch (identity.status) {
            'pending' => 'ACCOUNT_PENDING_APPROVAL',
            'rejected' => 'ACCOUNT_REJECTED',
            'suspended' => 'ACCOUNT_SUSPENDED',
            'deactivated' => 'ACCOUNT_INACTIVE',
            _ => null,
          },
  );

  Future<void> signIn(String email, String password) async {
    if (_signingIn || _signingOut || checking) return;
    _signingIn = true;
    _invalidate();
    final epoch = generation;
    phase = SessionPhase.signingIn;
    failure = null;
    notice = null;
    _emit();
    try {
      // Remove any earlier credential before obtaining another identity.
      await _storage(store.delete);
      _deletePending = false;
      if (!_current(epoch)) return;
      final result = await auth.login(email, password);
      if (!_current(epoch)) {
        await _bestEffortRevoke(result.token);
        return;
      }
      if (!result.customer.isActiveCustomer) {
        await _bestEffortRevoke(result.token);
        throw _denial(result.customer);
      }
      try {
        await _storage(() => store.write(result.token));
      } catch (_) {
        await _bestEffortRevoke(result.token);
        _deletePending = true;
        throw const ApiFailure(FailureKind.storage);
      }
      if (!_current(epoch)) {
        await _bestEffortRevoke(result.token);
        return;
      }
      _lease = _newLease(result.token, epoch);
      await _verify();
    } on ApiFailure catch (error) {
      if (_current(epoch)) {
        failure = error;
        phase = error.kind == FailureKind.storage
            ? SessionPhase.storageUnavailable
            : error.identityLost
            ? SessionPhase.accountDenied
            : SessionPhase.signedOut;
        _emit();
      }
      rethrow;
    } catch (_) {
      if (_current(epoch)) {
        _deletePending = true;
        failure = const ApiFailure(FailureKind.storage);
        phase = SessionPhase.storageUnavailable;
        _emit();
      }
      throw const ApiFailure(FailureKind.storage);
    } finally {
      _signingIn = false;
      _emit();
    }
  }

  Future<void> _bestEffortRevoke(String token) async {
    try {
      await auth.logout(SessionLease(token, () => true, (_) {}));
    } catch (_) {
      /* No replay. */
    }
  }

  void _onPrivateFailure(ApiFailure error, int epoch) {
    if (!_current(epoch)) return;
    if (error.identityLost) {
      unawaited(_loseIdentity(error));
    } else if (error.code == 'POLICY_CONSENT_REQUIRED') {
      consent = null;
      phase = SessionPhase.consentRequired;
      failure = error;
      _clearPrivateState();
      _emit();
      unawaited(refreshConsent());
    }
  }

  Future<void> _loseIdentity(ApiFailure error) async {
    _invalidate();
    final epoch = generation;
    failure = error;
    _deletePending = true;
    phase = error.status == 401
        ? SessionPhase.signedOut
        : SessionPhase.accountDenied;
    _emit();
    await _deleteCredential(epoch);
  }

  Future<void> _deleteCredential(int epoch) async {
    try {
      await _storage(store.delete);
      if (_current(epoch)) {
        _deletePending = false;
        _emit();
      }
    } catch (_) {
      if (_current(epoch)) {
        failure = const ApiFailure(FailureKind.storage);
        phase = SessionPhase.storageUnavailable;
        _emit();
      }
    }
  }

  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    final authenticationPending = _signingIn;
    final token = _lease?.bearer;
    _invalidate();
    final epoch = generation;
    phase = SessionPhase.checkingStorage;
    _deletePending = true;
    failure = null;
    notice = null;
    _emit();
    bool revoked = false;
    if (token != null) {
      try {
        await auth.logout(SessionLease(token, () => _current(epoch), (_) {}));
        revoked = true;
      } on ApiFailure catch (error) {
        revoked = error.status == 401;
      } catch (_) {
        /* Local cleanup still proceeds. */
      }
    }
    await _deleteCredential(epoch);
    if (_current(epoch) && !_deletePending) {
      phase = SessionPhase.signedOut;
      notice = token != null && !revoked || authenticationPending
          ? 'Signed out locally. Remote revocation could not be confirmed.'
          : 'Signed out.';
    }
    _signingOut = false;
    _emit();
  }

  Future<void> retry() async {
    if (_deletePending) {
      final epoch = generation;
      await _deleteCredential(epoch);
      if (_current(epoch) && !_deletePending) {
        phase = SessionPhase.signedOut;
        failure = null;
        _emit();
      }
    } else if (_lease != null) {
      await refresh();
    } else {
      _bootstrap = null;
      await bootstrap();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidate();
    super.dispose();
  }
}
