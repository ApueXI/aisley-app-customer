import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/networking/request_cooldown.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/security/session_controller.dart';
import '../data/saved_repository.dart';

class RecentMergeCoordinator extends ChangeNotifier with RequestCooldown {
  RecentMergeCoordinator({
    required this.session,
    required this.repository,
    required this.guestStore,
  }) {
    session.addListener(_sessionChanged);
    session.registerPrivateCleanup(clearPrivate);
    _sessionChanged();
  }
  final SessionController session;
  final RecentlyViewedRepository repository;
  final GuestRecentStore guestStore;
  int _attemptedGeneration = -1;
  String? _customerId;
  bool busy = false;
  bool failed = false;
  String? error;
  int _epoch = 0;
  bool _disposed = false;
  bool _current(int epoch, SessionLease lease) =>
      !_disposed && session.active && epoch == _epoch && lease.isCurrent();

  void clearPrivate() {
    _epoch++;
    clearCooldown();
    _customerId = null;
    _attemptedGeneration = -1;
    busy = false;
    failed = false;
    error = null;
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    final id = session.customer?.id;
    if (!session.active || id == null) {
      if (_customerId != null || busy || failed) clearPrivate();
      return;
    }
    if (_customerId != id || _attemptedGeneration != session.generation) {
      _epoch++;
      busy = false;
      failed = false;
      error = null;
      _customerId = id;
      _attemptedGeneration = session.generation;
      unawaited(mergePending());
    }
  }

  Future<void> mergePending({bool retry = false}) async {
    if (busy || coolingDown || !session.active) return;
    if (!retry && failed) return;
    final lease = session.verifiedLease;
    if (lease == null) return;
    final epoch = ++_epoch;
    busy = true;
    failed = false;
    error = null;
    notifyListeners();
    try {
      final hints = await guestStore.read();
      if (!_current(epoch, lease)) return;
      if (hints.isEmpty) return;
      final result = await repository.merge(lease, hints);
      if (!_current(epoch, lease)) return;
      await guestStore.removeAcknowledged(
        result.productIds,
        hints: hints,
        canCommit: () => _current(epoch, lease),
      );
      if (_current(epoch, lease)) failed = false;
    } on ApiFailure catch (failure) {
      if (_current(epoch, lease)) {
        failed = true;
        error = describeFailure(failure);
      }
    } catch (_) {
      if (_current(epoch, lease)) {
        failed = true;
        error = 'Guest browsing history could not be synchronized.';
      }
    } finally {
      if (_current(epoch, lease)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    session.removeListener(_sessionChanged);
    session.unregisterPrivateCleanup(clearPrivate);
    super.dispose();
  }
}
