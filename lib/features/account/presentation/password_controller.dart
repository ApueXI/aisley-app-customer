import 'dart:async';

import '../data/password_challenge.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/account_repository.dart';

class PasswordController extends PrivateFeatureController {
  PasswordController(super.session, this.repository) {
    session.passwordChanges.addListener(_operationChanged);
    _startTimer();
  }

  void _operationChanged() {
    if (!isDisposed) notifyListeners();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isDisposed) notifyListeners();
    });
  }

  // The base controller clears screen-local flags on consent/disposal. This
  // getter intentionally reads session recovery, which only identity loss resets.
  @override
  bool get requiresReconciliation =>
      session.passwordChanges.reconciliationRequired;
  bool get resendBlocked => session.passwordChanges.resendBlocked;
  int get requestSeconds {
    final until = session.passwordChanges.blockedUntil;
    final resend = session.passwordChanges.resendUntil;
    final latest = until == null
        ? resend
        : resend == null || until.isAfter(resend)
        ? until
        : resend;
    return latest == null
        ? 0
        : latest.difference(DateTime.now()).inSeconds.clamp(0, 3600) +
              (latest.isAfter(DateTime.now()) ? 1 : 0);
  }

  bool get operationPending => session.passwordChanges.pending;
  String? get recoveryMessage => requiresReconciliation
      ? 'The password change outcome is uncertain. Sign out and check sign-in with the password you believe is current before another change.'
      : operationPending
      ? 'A password request is still pending. Wait for its outcome before another change.'
      : null;
  final AccountRepository repository;
  bool saving = false, changed = false;
  PasswordChallenge? challenge;
  Timer? _timer;
  DateTime? get requestBlockedUntil => session.passwordChanges.blockedUntil;
  bool get requestBlocked =>
      requestBlockedUntil?.isAfter(DateTime.now()) == true;

  void cancelVerification() {
    if (saving || operationPending) return;
    challenge = null;
    fieldErrors = const {};
    notifyListeners();
  }

  Future<bool> requestCode({
    required String currentPassword,
    required String password,
    required String confirmation,
  }) async {
    final lease = currentLease;
    if (lease == null ||
        saving ||
        coolingDown ||
        requestBlocked ||
        requiresReconciliation ||
        (challenge?.resendSeconds ?? 0) > 0) {
      return false;
    }
    final ticket = session.passwordChanges.begin(confirm: false);
    if (ticket == null) return false;
    final generation = featureGeneration;
    saving = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final result = await repository.requestPasswordCode(
        lease,
        currentPassword: currentPassword,
        password: password,
        confirmation: confirmation,
      );
      if (lease.isCurrent()) {
        session.passwordChanges.settle(ticket, resendUntil: result.resendAt);
      }
      if (!isCurrentEpoch(generation, lease)) return false;
      challenge = result;
      _startTimer();
      return true;
    } on ApiFailure catch (failure) {
      if (lease.isCurrent()) {
        session.passwordChanges.settle(
          ticket,
          blockedUntil:
              failure.retryAt ??
              (failure.uncertain || failure.status == 408
                  ? DateTime.now().add(const Duration(seconds: 60))
                  : null),
        );
      }
      if (isCurrentEpoch(generation, lease)) {
        fieldErrors = validationFields(failure);
        error = describeFailure(failure);
      }
      return false;
    } on FormatException {
      if (lease.isCurrent()) {
        session.passwordChanges.settle(
          ticket,
          blockedUntil: DateTime.now().add(const Duration(seconds: 60)),
        );
      }
      if (isCurrentEpoch(generation, lease)) {
        error = 'Unexpected verification response. Wait one minute before requesting another code.';
      }
      return false;
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        saving = false;
        _startTimer();
        notifyListeners();
      }
    }
  }

  Future<bool> change({
    required String currentPassword,
    required String password,
    required String confirmation,
    required String verificationCode,
  }) async {
    final lease = currentLease;
    if (lease == null ||
        saving ||
        coolingDown ||
        requiresReconciliation ||
        challenge == null ||
        challenge!.expired) {
      return false;
    }
    final ticket = session.passwordChanges.begin(confirm: true);
    if (ticket == null) return false;
    final generation = featureGeneration;
    saving = true;
    changed = false;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      await repository.updatePassword(
        lease,
        currentPassword: currentPassword,
        password: password,
        confirmation: confirmation,
        challengeId: challenge!.id,
        verificationCode: verificationCode,
      );
      if (lease.isCurrent()) session.passwordChanges.settle(ticket);
      if (!isCurrentEpoch(generation, lease)) return false;
      challenge = null;
      changed = true;
      return true;
    } on ApiFailure catch (failure) {
      final uncertain = failure.uncertain || failure.status == 408;
      if (lease.isCurrent()) {
        session.passwordChanges.settle(
          ticket,
          uncertain: uncertain,
          blockedUntil: failure.retryAt,
        );
      }
      if (isCurrentEpoch(generation, lease)) {
        if (uncertain) challenge = null;
        fieldErrors = validationFields(failure);
        error = uncertain
            ? 'The password change outcome is uncertain. Check sign-in with your current password before making another change.'
            : describeFailure(failure);
      }
      return false;
    } on FormatException {
      if (lease.isCurrent()) {
        session.passwordChanges.settle(ticket, uncertain: true);
      }
      if (isCurrentEpoch(generation, lease)) {
        challenge = null;
        error = recoveryMessage;
      }
      return false;
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    session.passwordChanges.removeListener(_operationChanged);
    super.dispose();
  }

  @override
  void onClear() {
    _timer?.cancel();
    _timer = null;
    challenge = null;
    saving = false;
    changed = false;
  }
}
