import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';

class ActionViewModel extends ChangeNotifier {
  ActionViewModel({DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  bool busy = false, succeeded = false, _disposed = false;
  ApiFailure? failure;
  Timer? _timer;
  int _epoch = 0;
  bool get coolingDown => failure?.retryAt?.isAfter(clock()) == true;
  bool get enabled => !busy && !coolingDown;

  Future<bool> submit(Future<void> Function() action) async {
    if (!enabled) return false;
    final epoch = ++_epoch;
    busy = true;
    succeeded = false;
    failure = null;
    notifyListeners();
    try {
      await action();
      if (!_disposed && epoch == _epoch) succeeded = true;
    } on ApiFailure catch (error) {
      if (!_disposed && epoch == _epoch) {
        failure = error;
        if (coolingDown) {
          _timer?.cancel();
          _timer = Timer(error.retryAt!.difference(clock()), () {
            if (!_disposed) notifyListeners();
          });
        }
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
    return !_disposed && epoch == _epoch && succeeded;
  }

  void reset() {
    _epoch++;
    _timer?.cancel();
    busy = false;
    succeeded = false;
    failure = null;
    notifyListeners();
  }

  void clearField(String key) {
    final error = failure;
    if (error == null || !error.fields.containsKey(key)) return;
    failure = ApiFailure(
      error.kind,
      status: error.status,
      code: error.code,
      retryAt: error.retryAt,
      fields: Map.unmodifiable({...error.fields}..remove(key)),
    );
    notifyListeners();
  }

  String? fieldError(String key) => failure?.fields[key]?.first;
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
