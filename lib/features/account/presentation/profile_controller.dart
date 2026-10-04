import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/account_repository.dart';
import '../data/account_models.dart';

class ProfileController extends PrivateFeatureController {
  ProfileController(super.session, this.repository);
  final AccountRepository repository;
  CustomerAccount? account;
  bool loading = false, saving = false;

  Future<void> load() async {
    final lease = currentLease;
    if (lease == null || loading || saving || coolingDown) return;
    final generation = featureGeneration;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await repository.account(lease);
      if (isCurrentEpoch(generation, lease)) {
        if (value.id != session.customer?.id) {
          throw const ApiFailure(FailureKind.decode);
        }
        account = value;
        requiresReconciliation = false;
      }
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        if (failure.status == 403 || failure.status == 404) account = null;
        error = describeFailure(failure);
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(ProfileInput input) async {
    final lease = currentLease;
    if (lease == null || saving || coolingDown || requiresReconciliation) {
      return false;
    }
    final generation = featureGeneration;
    saving = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final updated = await repository.updateProfile(lease, input);
      if (!isCurrentEpoch(generation, lease)) return false;
      if (updated.id != session.customer?.id) {
        throw const ApiFailure(FailureKind.decode);
      }
      account = updated;
      await session.refreshNavigation();
      return isCurrentEpoch(generation, lease);
    } on ApiFailure catch (failure) {
      if (!isCurrentEpoch(generation, lease)) return false;
      fieldErrors = validationFields(failure);
      if (failure.uncertain) {
        requiresReconciliation = true;
        error = 'The save outcome is uncertain. Checking the current profile…';
        try {
          final latest = await repository.account(lease);
          if (!isCurrentEpoch(generation, lease)) return false;
          if (latest.id != session.customer?.id) {
            throw const ApiFailure(FailureKind.decode);
          }
          account = latest;
          requiresReconciliation = false;
          if (_matches(latest.profile, input)) {
            error = null;
            await session.refreshNavigation();
            return isCurrentEpoch(generation, lease);
          }
          error = 'The profile did not match the submitted values. Review it before saving again.';
        } on ApiFailure {
          if (isCurrentEpoch(generation, lease)) {
            error = 'The save outcome is uncertain. Refresh this profile before another change.';
          }
        }
      } else {
        if (isCurrentEpoch(generation, lease)) {
          if (failure.status == 403 || failure.status == 404) account = null;
          error = describeFailure(failure);
        }
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
    account = null;
    loading = false;
    saving = false;
  }

  bool _matches(CustomerProfile profile, ProfileInput input) =>
      profile.firstName == input.firstName.trim() &&
      profile.middleName ==
          (input.middleName.trim().isEmpty ? null : input.middleName.trim()) &&
      profile.lastName == input.lastName.trim() &&
      profile.contactNumber == input.contactNumber.trim() &&
      profile.sex == input.sex &&
      profile.birthDate == input.birthDate;
}
