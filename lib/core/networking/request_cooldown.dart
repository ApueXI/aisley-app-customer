import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_failure.dart';

mixin RequestCooldown on ChangeNotifier {
  DateTime? _retryAt;
  Timer? _cooldownTimer;
  bool get coolingDown => _retryAt?.isAfter(DateTime.now()) == true;

  String describeFailure(ApiFailure failure) {
    _retryAt = failure.retryAt;
    _cooldownTimer?.cancel();
    if (coolingDown) {
      _cooldownTimer = Timer(
        _retryAt!.difference(DateTime.now()),
        notifyListeners,
      );
    }
    return failure.description;
  }

  void clearCooldown() {
    _cooldownTimer?.cancel();
    _retryAt = null;
  }

  @override
  void dispose() {
    clearCooldown();
    super.dispose();
  }
}
