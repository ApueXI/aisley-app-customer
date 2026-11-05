import 'dart:async';

import '../../../core/networking/api_failure.dart';
import '../../../core/security/session_controller.dart';
import '../../auth/presentation/action_view_model.dart';
import '../data/policy_models.dart';
import '../data/policy_repository.dart';

class ConsentViewModel extends ActionViewModel {
  ConsentViewModel(this.repository, this.session)
    : _generation = session.generation {
    session.addListener(_sessionChanged);
  }
  final PolicyRepository repository;
  final SessionController session;
  final Map<PolicyType, PublicPolicy> documents = {};
  final Map<PolicyType, String> confirmations = {};
  bool loading = false;
  int _generation, _query = 0;
  bool _closed = false;

  String _key(PublicPolicy policy) =>
      '${policy.version.id}:${policy.version.version}';
  List<PolicyStatus> get pending =>
      session.consent?.policies.where((item) => item.required).toList() ?? [];
  PolicyStatus? statusFor(PolicyType type) {
    for (final item in session.consent?.policies ?? <PolicyStatus>[]) {
      if (item.type == type.wire) return item;
    }
    return null;
  }

  bool covered(PolicyType type) =>
      statusFor(type)?.currentVersion != null &&
      statusFor(type)?.required == false;
  bool confirmed(PolicyType type) =>
      covered(type) ||
      (documents[type] != null &&
          confirmations[type] == _key(documents[type]!));
  void confirm(PolicyType type, bool value) {
    if (busy || !enabled || covered(type) || documents[type] == null) return;
    if (value) {
      confirmations[type] = _key(documents[type]!);
    } else {
      confirmations.remove(type);
    }
    notifyListeners();
  }

  bool _matches(PolicyStatus item) {
    final type = PolicyType.fromWire(item.type);
    final document = documents[type];
    return type != null &&
        document != null &&
        document.type == item.type &&
        document.version.id == item.currentVersion?.id &&
        document.version.version == item.currentVersion?.version;
  }

  bool get mayAccept =>
      enabled &&
      !loading &&
      pending.isNotEmpty &&
      session.phase == SessionPhase.consentRequired &&
      session.verifiedLease != null &&
      pending.every(
        (item) => _matches(item) && confirmed(PolicyType.fromWire(item.type)!),
      );

  void _sessionChanged() {
    if (_generation != session.generation) {
      _generation = session.generation;
      _query++;
      documents.clear();
      confirmations.clear();
      loading = false;
      reset();
    } else if (!busy &&
        !loading &&
        session.phase == SessionPhase.consentRequired &&
        documents.isNotEmpty &&
        pending.any((item) => !_matches(item))) {
      confirmations.removeWhere(
        (type, _) =>
            pending.any((item) => item.type == type.wire && !_matches(item)),
      );
      notifyListeners();
      unawaited(load());
    }
  }

  Future<void> load() async {
    if (loading || busy) return;
    final query = ++_query, epoch = session.generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      await session.refreshConsent();
      if (_closed || epoch != session.generation || query != _query) return;
      if (session.consent == null) {
        throw session.failure ?? const ApiFailure(FailureKind.decode);
      }
      final next = <PolicyType, PublicPolicy>{};
      for (final item in session.consent!.policies) {
        final type = PolicyType.fromWire(item.type);
        if (type == null || item.currentVersion == null) {
          if (item.required) throw const ApiFailure(FailureKind.decode);
          continue;
        }
        final document = await repository.current(type, refresh: true);
        if (_closed || epoch != session.generation || query != _query) return;
        if (document.type != item.type ||
            document.version.id != item.currentVersion!.id ||
            document.version.version != item.currentVersion!.version) {
          throw const ApiFailure(
            FailureKind.http,
            status: 409,
            code: 'POLICY_VERSION_STALE',
          );
        }
        next[type] = document;
      }
      documents
        ..clear()
        ..addAll(next);
      confirmations.removeWhere(
        (type, value) =>
            documents[type] == null || value != _key(documents[type]!),
      );
    } on ApiFailure catch (error) {
      if (!_closed && epoch == session.generation && query == _query) {
        failure = error;
        if (error.code == 'POLICY_VERSION_STALE') {
          documents.clear();
          confirmations.clear();
        }
      }
    } finally {
      if (!_closed && epoch == session.generation && query == _query) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> accept() async {
    if (!mayAccept) return;
    final epoch = session.generation, lease = session.verifiedLease!;
    final selected = {
      for (final item in pending)
        PolicyType.fromWire(item.type)!: item.currentVersion!.version,
    };
    final success = await submit(() async {
      await session.refreshConsent();
      if (_closed || epoch != session.generation) return;
      if (session.active) return;
      if (session.consent == null) {
        throw session.failure ?? const ApiFailure(FailureKind.decode);
      }
      if (pending.any(
        (item) =>
            !_matches(item) ||
            selected[PolicyType.fromWire(item.type)] !=
                item.currentVersion?.version,
      )) {
        throw const ApiFailure(
          FailureKind.http,
          status: 409,
          code: 'POLICY_VERSION_STALE',
        );
      }
      await repository.acceptTogether(lease, selected);
      if (!_closed && epoch == session.generation) {
        await session.refreshConsent();
      }
    });
    if (_closed || epoch != session.generation) return;
    if (!success && failure?.code == 'POLICY_VERSION_STALE') {
      final stale = failure;
      await load();
      if (!_closed && epoch == session.generation) {
        failure = stale;
        notifyListeners();
      }
    } else if (!success && failure?.uncertain == true) {
      final original = failure;
      await session.refreshConsent();
      if (_closed || epoch != session.generation) return;
      if (session.active) {
        failure = null;
        succeeded = true;
      } else {
        failure = original;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _query++;
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
