import 'package:flutter/foundation.dart';

/// Nonsecret recovery state for one authenticated session, shared by screens.
class PasswordOperationState extends ChangeNotifier {
  int _generation = 0, _operation = 0;
  bool pending = false, reconciliationRequired = false;
  DateTime? blockedUntil, resendUntil;

  bool get blocked => blockedUntil?.isAfter(DateTime.now()) == true;
  bool get resendBlocked => resendUntil?.isAfter(DateTime.now()) == true;

  (int, int)? begin({required bool confirm}) {
    if (pending ||
        reconciliationRequired ||
        blocked ||
        (!confirm && resendBlocked)) {
      return null;
    }
    pending = true;
    final ticket = (_generation, ++_operation);
    notifyListeners();
    return ticket;
  }

  bool isCurrent((int, int) ticket) =>
      ticket.$1 == _generation && ticket.$2 == _operation;

  void settle(
    (int, int) ticket, {
    bool uncertain = false,
    DateTime? blockedUntil,
    DateTime? resendUntil,
  }) {
    if (!isCurrent(ticket)) return;
    pending = false;
    reconciliationRequired = uncertain;
    if (blockedUntil != null &&
        (this.blockedUntil == null ||
            blockedUntil.isAfter(this.blockedUntil!))) {
      this.blockedUntil = blockedUntil;
    }
    if (resendUntil != null &&
        (this.resendUntil == null || resendUntil.isAfter(this.resendUntil!))) {
      this.resendUntil = resendUntil;
    }
    notifyListeners();
  }

  void reset() {
    _generation++;
    pending = false;
    reconciliationRequired = false;
    blockedUntil = resendUntil = null;
    notifyListeners();
  }
}
