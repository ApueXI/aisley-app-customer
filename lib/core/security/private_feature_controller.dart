import 'package:flutter/foundation.dart';

import '../networking/api_failure.dart';
import '../networking/request_cooldown.dart';
import '../networking/api_client.dart';
import 'session_controller.dart';

abstract class PrivateFeatureController extends ChangeNotifier
    with RequestCooldown {
  PrivateFeatureController(this.session) {
    session.registerPrivateCleanup(clearPrivate);
  }
  final SessionController session;
  String? error;
  Map<String, String> fieldErrors = const {};
  int featureGeneration = 0;
  bool requiresReconciliation = false;

  SessionLease? get currentLease =>
      session.active ? session.verifiedLease : null;
  bool isCurrentEpoch(int generation, SessionLease lease) =>
      generation == featureGeneration &&
      lease.isCurrent() &&
      session.active &&
      !isDisposed;

  bool isDisposed = false;

  void clearPrivate() {
    featureGeneration++;
    clearCooldown();
    onClear();
    error = null;
    fieldErrors = const {};
    requiresReconciliation = false;
    if (!isDisposed) notifyListeners();
  }

  void onClear() {}

  @override
  void dispose() {
    isDisposed = true;
    session.unregisterPrivateCleanup(clearPrivate);
    featureGeneration++;
    onClear();
    error = null;
    fieldErrors = const {};
    super.dispose();
  }
}

Map<String, String> validationFields(ApiFailure failure) => {
  for (final entry in failure.fields.entries)
    if (entry.value.isNotEmpty) entry.key: entry.value.first,
};
