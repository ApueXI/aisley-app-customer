import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/security/session_controller.dart';
import '../../auth/presentation/action_view_model.dart';
import '../data/policy_models.dart';
import '../data/policy_repository.dart';

class PolicyReaderViewModel extends ChangeNotifier {
  PolicyReaderViewModel(this.repository, this.type, this.version);
  final PolicyRepository repository;
  final PolicyType type;
  final int? version;
  PublicPolicy? policy;
  PolicyHistory? history;
  ApiFailure? failure, historyFailure;
  bool loading = false, historyLoading = false, _disposed = false;
  int _query = 0;

  Future<void> load() async {
    final query = ++_query;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = version == null
          ? await repository.current(type, refresh: true)
          : await repository.version(type, version!);
      if (!_disposed && query == _query) policy = result;
    } on ApiFailure catch (error) {
      if (!_disposed && query == _query) failure = error;
    } finally {
      if (!_disposed && query == _query) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadHistory() async {
    if (historyLoading) return;
    historyLoading = true;
    historyFailure = null;
    notifyListeners();
    try {
      final result = await repository.history(type);
      if (!_disposed) history = result;
    } on ApiFailure catch (error) {
      if (!_disposed) historyFailure = error;
    } finally {
      if (!_disposed) {
        historyLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _query++;
    super.dispose();
  }
}

class ConsentViewModel extends ActionViewModel {
  ConsentViewModel(this.repository, this.session)
    : _generation = session.generation {
    session.addListener(_sessionChanged);
  }
  final PolicyRepository repository;
  final SessionController session;
  PublicPolicy? policy;
  bool confirmed = false, loading = false;
  int _generation, _query = 0;
  bool _closed = false;
  void _sessionChanged() {
    if (_generation != session.generation) {
      _generation = session.generation;
      _query++;
      policy = null;
      confirmed = false;
      loading = false;
      reset();
    } else if (session.phase == SessionPhase.consentRequired &&
        session.consent != null &&
        policy != null &&
        !_matchesRequired()) {
      _query++;
      policy = null;
      confirmed = false;
      loading = false;
      notifyListeners();
      if (!busy) unawaited(load());
    }
  }

  bool _matchesRequired() =>
      policy != null &&
      session.consent?.policies.any(
            (status) =>
                status.required &&
                status.type == policy!.type &&
                status.currentVersion?.id == policy!.version.id &&
                status.currentVersion?.version == policy!.version.version,
          ) ==
          true;

  void confirm(bool value) {
    confirmed = value;
    notifyListeners();
  }

  bool get mayAccept =>
      confirmed &&
      policy != null &&
      enabled &&
      !loading &&
      session.phase == SessionPhase.consentRequired &&
      _matchesRequired() &&
      session.verifiedLease != null;

  Future<void> load() async {
    final query = ++_query, epoch = session.generation;
    policy = null;
    confirmed = false;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      if (session.consent == null) await session.refreshConsent();
      if (_closed || epoch != session.generation || query != _query) return;
      final required =
          session.consent?.policies.where((p) => p.required).toList() ?? [];
      if (required.isEmpty) {
        if (!session.active) throw const ApiFailure(FailureKind.decode);
        return;
      }
      final status = required.first;
      final type = PolicyType.fromWire(status.type),
          expected = status.currentVersion;
      if (type == null || expected == null) {
        throw const ApiFailure(FailureKind.decode);
      }
      final result = await repository.current(type, refresh: true);
      if (_closed || epoch != session.generation || query != _query) return;
      if (result.version.version != expected.version ||
          result.version.id != expected.id) {
        await session.refreshConsent();
        throw const ApiFailure(
          FailureKind.http,
          status: 409,
          code: 'POLICY_VERSION_STALE',
        );
      }
      policy = result;
    } on ApiFailure catch (error) {
      if (!_closed && epoch == session.generation && query == _query) {
        failure = error;
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
    final epoch = session.generation,
        selected = policy!,
        lease = session.verifiedLease!;
    final success = await submit(() async {
      await repository.accept(
        lease,
        PolicyType.fromWire(selected.type)!,
        selected.version.version,
      );
      if (!_closed && epoch == session.generation) {
        await session.refreshConsent();
      }
    });
    if (_closed || epoch != session.generation) return;
    if (success) {
      await load();
    } else if (failure?.code == 'POLICY_VERSION_STALE') {
      final stale = failure;
      confirmed = false;
      await session.refreshConsent();
      await load();
      if (!_closed && epoch == session.generation) {
        failure = stale;
        notifyListeners();
      }
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
