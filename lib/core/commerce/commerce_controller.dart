import 'package:flutter/foundation.dart';

import '../networking/api_client.dart';
import '../networking/api_failure.dart';
import '../networking/request_cooldown.dart';
import '../security/private_feature_controller.dart';
import '../security/session_controller.dart';

/// Commerce controllers live for the session, including navigation away from a write.
abstract class CommerceController extends ChangeNotifier with RequestCooldown {
  CommerceController(this.session) {
    session.registerPrivateCleanup(clearPrivate);
  }
  final SessionController session;
  int epoch = 0;
  bool disposed = false;
  String? error;
  Map<String, String> fieldErrors = const {};
  SessionLease? get lease => session.active ? session.verifiedLease : null;
  bool current(int value, SessionLease credential) =>
      !disposed && epoch == value && session.active && credential.isCurrent();
  bool get sameIdentity =>
      session.customer != null && session.verifiedLease?.isCurrent() == true;
  void failure(ApiFailure value) {
    error = describeFailure(value);
    fieldErrors = validationFields(value);
  }

  void clearPrivate() {
    epoch++;
    clearCooldown();
    reset(preserveUnresolved: sameIdentity);
    error = null;
    fieldErrors = const {};
    if (!disposed) notifyListeners();
  }

  void reset({required bool preserveUnresolved});
  @override
  void dispose() {
    disposed = true;
    session.unregisterPrivateCleanup(clearPrivate);
    epoch++;
    reset(preserveUnresolved: false);
    super.dispose();
  }
}
