import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/account_repository.dart';
import '../data/account_models.dart';

class PromotionPreferenceController extends PrivateFeatureController {
  PromotionPreferenceController(super.session, this.repository);
  final AccountRepository repository;
  PromotionPreference? preference;
  bool loading = false, saving = false;

  Future<void> load() async {
    final lease = currentLease;
    if (lease == null || loading || saving || coolingDown) return;
    final generation = featureGeneration;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await repository.promotionPreference(lease);
      if (isCurrentEpoch(generation, lease)) preference = value;
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) error = describeFailure(failure);
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> set(bool value) async {
    final lease = currentLease;
    if (lease == null || saving || coolingDown || requiresReconciliation) {
      return false;
    }
    final generation = featureGeneration;
    final before = preference;
    saving = true;
    error = null;
    notifyListeners();
    try {
      final updated = await repository.setPromotionPreference(lease, value);
      if (isCurrentEpoch(generation, lease)) preference = updated;
      return isCurrentEpoch(generation, lease);
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        if (failure.uncertain) {
          try {
            final value = await repository.promotionPreference(lease);
            if (isCurrentEpoch(generation, lease)) preference = value;
          } catch (_) {
            if (isCurrentEpoch(generation, lease)) preference = null;
          }
        } else {
          preference = before;
        }
        if (isCurrentEpoch(generation, lease)) error = describeFailure(failure);
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
    preference = null;
    loading = false;
    saving = false;
  }
}
