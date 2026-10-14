import 'dart:async';

import '../data/password_challenge.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/account_repository.dart';

class PasswordController extends PrivateFeatureController {
  PasswordController(super.session, this.repository);
  final AccountRepository repository;
  bool saving = false, changed = false;
  PasswordChallenge? challenge;
  Timer? _timer;
  DateTime? requestBlockedUntil;
  bool get requestBlocked =>
      requestBlockedUntil?.isAfter(DateTime.now()) == true;

  void cancelVerification() {
    if (saving) return;
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
      if (!isCurrentEpoch(generation, lease)) return false;
      challenge = result;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isDisposed) notifyListeners();
      });
      return true;
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        fieldErrors = validationFields(failure);
        error = describeFailure(failure);
        if (failure.uncertain) {
          requestBlockedUntil = DateTime.now().add(const Duration(seconds: 60));
        }
      }
      return false;
    } on FormatException {
      if (isCurrentEpoch(generation, lease)) {
        error = 'Unexpected verification response. Wait one minute before requesting another code.';
        requestBlockedUntil = DateTime.now().add(const Duration(seconds: 60));
      }
      return false;
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        saving = false;
        if (requestBlocked || challenge != null) {
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (!isDisposed) notifyListeners();
          });
        }
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
      if (!isCurrentEpoch(generation, lease)) return false;
      challenge = null;
      _timer?.cancel();
      changed = true;
      return true;
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        fieldErrors = validationFields(failure);
        requiresReconciliation = failure.uncertain;
        error = failure.uncertain
            ? 'The password change outcome is uncertain. Check sign-in with your current password before making another change.'
            : describeFailure(failure);
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
  void onClear() {
    _timer?.cancel();
    challenge = null;
    requestBlockedUntil = null;
    saving = false;
    changed = false;
  }
}
