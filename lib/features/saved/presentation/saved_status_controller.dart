import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/networking/request_cooldown.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/security/session_controller.dart';
import '../data/saved_repository.dart';

class SavedStatusController extends ChangeNotifier with RequestCooldown {
  SavedStatusController(this.session, this.repository) {
    session.registerPrivateCleanup(clearPrivate);
  }
  final SessionController session;
  final WishlistRepository repository;
  final _saved = <String, bool>{};
  final _pending = <String>{};
  final _tails = <String, Future<void>>{};
  String? error;
  int _epoch = 0;
  bool _disposed = false;

  bool _current(int epoch, SessionLease lease) =>
      !_disposed && session.active && epoch == _epoch && lease.isCurrent();

  bool? isSaved(String productId) => _saved[productId];
  bool isPending(String productId) => _pending.contains(productId);

  Future<void> loadStatuses(Iterable<String> productIds) async {
    final lease = session.active ? session.verifiedLease : null;
    if (lease == null) return;
    final ids = productIds
        .toSet()
        .where((id) => !_saved.containsKey(id))
        .toList();
    final epoch = _epoch;
    try {
      for (var offset = 0; offset < ids.length; offset += 50) {
        final batch = ids.skip(offset).take(50).toList();
        final statuses = await repository.statuses(lease, batch);
        if (!_current(epoch, lease)) return;
        _saved.addAll(statuses);
      }
      if (!_current(epoch, lease)) return;
      error = null;
      notifyListeners();
    } on ApiFailure catch (failure) {
      if (_current(epoch, lease)) {
        error = describeFailure(failure);
        notifyListeners();
      }
    }
  }

  Future<void> setSaved(String productId, bool desired) {
    if (coolingDown) return Future.value();
    final queuedEpoch = _epoch;
    final queuedGeneration = session.generation;
    final previous = _tails[productId] ?? Future<void>.value();
    final operation = previous.catchError((Object _) {}).then((_) async {
      final lease = session.active ? session.verifiedLease : null;
      if (lease == null ||
          queuedGeneration != session.generation ||
          !_current(queuedEpoch, lease)) {
        return;
      }
      final before = _saved[productId];
      final epoch = _epoch;
      _pending.add(productId);
      _saved[productId] = desired;
      error = null;
      notifyListeners();
      try {
        final result = await repository.setSaved(lease, productId, desired);
        if (!_current(epoch, lease)) return;
        if (result.productId != productId || result.saved != desired) {
          throw const ApiFailure(FailureKind.decode);
        }
        _saved[productId] = result.saved;
      } on ApiFailure catch (failure) {
        if (!_current(epoch, lease)) return;
        if (failure.uncertain) {
          try {
            final state = await repository.savedState(lease, productId);
            if (!_current(epoch, lease)) return;
            _saved[productId] = state.saved;
            error = 'Saved state was checked again.';
          } catch (_) {
            if (!_current(epoch, lease)) return;
            _saved.remove(productId);
            error = 'Could not confirm the saved state. Refresh to check.';
          }
        } else {
          if (before == null) {
            _saved.remove(productId);
          } else {
            _saved[productId] = before;
          }
          error = describeFailure(failure);
        }
      } finally {
        if (!_disposed && epoch == _epoch && lease.isCurrent()) {
          if (!session.active) _saved.remove(productId);
          _pending.remove(productId);
          notifyListeners();
        }
      }
    });
    _tails[productId] = operation;
    return operation.whenComplete(() {
      if (identical(_tails[productId], operation)) _tails.remove(productId);
    });
  }

  void clearPrivate() {
    _epoch++;
    clearCooldown();
    _saved.clear();
    _pending.clear();
    _tails.clear();
    error = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    session.unregisterPrivateCleanup(clearPrivate);
    clearPrivate();
    super.dispose();
  }
}
