import '../../../core/networking/api_failure.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/customer_voucher.dart';
import '../data/voucher_repository.dart';
import 'voucher_collection_controller.dart';

class VoucherDetailController extends PrivateFeatureController {
  VoucherDetailController(
    super.session,
    this.repository,
    this.collection,
    this.id,
  );
  final VoucherRepository repository;
  final VoucherCollectionController collection;
  final String id;
  CustomerVoucher? result;
  bool loading = false;
  Future<void> load({bool refresh = false}) async {
    final lease = currentLease;
    if (lease == null || isDisposed || loading || coolingDown) return;
    final generation = ++featureGeneration;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await collection.refresh([id]);
      if (!isCurrentEpoch(generation, lease)) return;
      final value =
          rows.firstOrNull ?? await repository.detail(id, refresh: refresh);
      if (isCurrentEpoch(generation, lease)) result = value;
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        error = describeFailure(failure);
        if (failure.status == 403 || failure.status == 404) result = null;
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void onClear() {
    result = null;
    loading = false;
  }
}
