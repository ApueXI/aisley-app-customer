import '../../../core/networking/api_failure.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/security/private_feature_controller.dart';
import '../data/address_models.dart';
import '../data/address_repository.dart';

class AddressController extends PrivateFeatureController {
  AddressController(super.session, this.repository);
  final AddressRepository repository;
  List<BuyerAddress> addresses = const [];
  bool loading = false, saving = false;
  String? deletingId;
  bool reconciliationAvailable = false;

  Future<void> load() async {
    final lease = session.active ? session.verifiedLease : null;
    if (lease == null ||
        loading ||
        saving ||
        deletingId != null ||
        coolingDown) {
      return;
    }
    final generation = featureGeneration;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final values = await repository.list(lease);
      if (isCurrentEpoch(generation, lease)) {
        addresses = values;
        reconciliationAvailable = true;
      }
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        if (failure.status == 403 || failure.status == 404) {
          addresses = const [];
          reconciliationAvailable = false;
        }
        error = describeFailure(failure);
      }
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(AddressInput input, {String? id}) async {
    final lease = session.active ? session.verifiedLease : null;
    if (lease == null ||
        loading ||
        saving ||
        deletingId != null ||
        coolingDown ||
        requiresReconciliation) {
      return false;
    }
    final generation = featureGeneration;
    saving = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      if (id == null) {
        final created = await repository.create(lease, input);
        if (!isCurrentEpoch(generation, lease)) return false;
        addresses = [
          created,
          ...addresses.where((row) => row.id != created.id),
        ];
      } else {
        final updated = await repository.update(lease, id, input);
        if (!isCurrentEpoch(generation, lease)) return false;
        addresses = [for (final row in addresses) row.id == id ? updated : row];
      }
      // Defaults can clear overlapping types transactionally, so refresh the list.
      await _reload(lease, generation);
      return isCurrentEpoch(generation, lease);
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        fieldErrors = {
          for (final entry in failure.fields.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.first,
        };
        if (failure.uncertain) {
          requiresReconciliation = true;
          reconciliationAvailable = false;
          error = 'The save outcome is uncertain. Checking saved addresses…';
          await _reload(lease, generation);
          if (isCurrentEpoch(generation, lease)) {
            error ??= 'Review the address list before submitting again.';
          }
        } else {
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

  Future<bool> delete(String id) async {
    final lease = session.active ? session.verifiedLease : null;
    if (lease == null ||
        loading ||
        saving ||
        coolingDown ||
        requiresReconciliation ||
        deletingId != null) {
      return false;
    }
    final generation = featureGeneration;
    deletingId = id;
    error = null;
    notifyListeners();
    try {
      await repository.delete(lease, id);
      if (!isCurrentEpoch(generation, lease)) return false;
      addresses = addresses.where((row) => row.id != id).toList();
      await _reload(lease, generation);
      return isCurrentEpoch(generation, lease);
    } on ApiFailure catch (failure) {
      if (isCurrentEpoch(generation, lease)) {
        fieldErrors = {
          for (final entry in failure.fields.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.first,
        };
        if (failure.uncertain) {
          await _reload(lease, generation);
          if (isCurrentEpoch(generation, lease)) {
            error = 'Review the refreshed address list to confirm removal.';
          }
        } else {
          error = describeFailure(failure);
        }
      }
      return false;
    } finally {
      if (isCurrentEpoch(generation, lease)) {
        deletingId = null;
        notifyListeners();
      }
    }
  }

  Future<void> _reload(SessionLease lease, int generation) async {
    try {
      final values = await repository.list(lease);
      if (isCurrentEpoch(generation, lease)) {
        addresses = values;
        reconciliationAvailable = true;
      }
    } on ApiFailure {
      if (isCurrentEpoch(generation, lease)) {
        reconciliationAvailable = false;
        error = 'Could not refresh addresses. Retry before another change.';
      }
    }
  }

  @override
  void onClear() {
    addresses = const [];
    loading = false;
    saving = false;
    deletingId = null;
    reconciliationAvailable = false;
  }
}
