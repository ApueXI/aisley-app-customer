import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/account_repository.dart';

class PasswordController extends PrivateFeatureController {
  PasswordController(super.session, this.repository);
  final AccountRepository repository;
  bool saving = false, changed = false;

  Future<bool> change({
    required String currentPassword,
    required String password,
    required String confirmation,
  }) async {
    final lease = currentLease;
    if (lease == null || saving || coolingDown || requiresReconciliation) {
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
      );
      if (!isCurrentEpoch(generation, lease)) return false;
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
    saving = false;
    changed = false;
  }
}
