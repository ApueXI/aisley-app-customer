import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_failure.dart';
import '../data/checkout_repository.dart';
import '../data/shipping_models.dart';
import '../domain/checkout_intent.dart';

/// Options are private reads; they never grant placement eligibility.
class CheckoutShippingController extends CommerceController {
  CheckoutShippingController(super.session, this.repository);
  final CheckoutRepository repository;
  LogisticsOptions? options;
  List<LogisticsSelection> selections = const [];
  Set<String> needsConfirmation = const {};
  bool loading = false, fresh = false;
  int _query = 0;

  String? selectedProvider(LogisticsOptionGroup group) => selections
      .where((s) => s.shopId == group.shop.id.toLowerCase())
      .firstOrNull
      ?.organizationId;

  bool get ready =>
      fresh &&
      !loading &&
      needsConfirmation.isEmpty &&
      options != null &&
      options!.groups.every((group) {
        final selected = selectedProvider(group);
        return selected != null
            ? group.options.any(
                (o) => o.organizationId == selected && o.supported,
              )
            : group.options.length == 1 && group.options.single.supported;
      });

  void invalidate() {
    _query++;
    fresh = false;
    loading = false;
    error = null;
    fieldErrors = const {};
  }

  bool select(String shopId, String organizationId) {
    if (!fresh || loading || coolingDown) return false;
    final group = options?.groups
        .where((g) => g.shop.id.toLowerCase() == shopId.toLowerCase())
        .firstOrNull;
    final option = group?.options
        .where(
          (o) =>
              o.organizationId == organizationId.toLowerCase() && o.supported,
        )
        .firstOrNull;
    if (group == null || option == null) return false;
    final normalizedShop = group.shop.id.toLowerCase();
    if (selectedProvider(group) == option.organizationId &&
        !needsConfirmation.contains(normalizedShop)) {
      return false;
    }
    if (selections.length >= 50 &&
        !selections.any((s) => s.shopId == normalizedShop)) {
      error = 'Shipping provider choices are limited to 50 Shops per checkout.';
      notifyListeners();
      return false;
    }
    selections = List.unmodifiable(
      [
        ...selections.where((s) => s.shopId != normalizedShop),
        LogisticsSelection(normalizedShop, option.organizationId),
      ]..sort((a, b) => a.shopId.compareTo(b.shopId)),
    );
    needsConfirmation = Set.unmodifiable(
      needsConfirmation.where((id) => id != normalizedShop),
    );
    error = null;
    return true;
  }

  Future<void> load(CheckoutInput input) async {
    final credential = lease;
    if (credential == null || coolingDown) return;
    invalidate();
    final query = _query, generation = epoch;
    loading = true;
    notifyListeners();
    try {
      final value = await repository.logisticsOptions(credential, input);
      if (!current(generation, credential) || query != _query) return;
      if (value.address.id?.toLowerCase() != input.addressId.toLowerCase()) {
        throw const ApiFailure(FailureKind.decode);
      }
      final remaining = <LogisticsSelection>[];
      final removed = <String>{...needsConfirmation};
      final shopIds = value.groups.map((g) => g.shop.id.toLowerCase()).toSet();
      removed.removeWhere((id) => !shopIds.contains(id));
      for (final selection in selections) {
        final group = value.groups
            .where((g) => g.shop.id.toLowerCase() == selection.shopId)
            .firstOrNull;
        if (group == null) continue;
        if (group.options.any(
          (o) => o.organizationId == selection.organizationId && o.supported,
        )) {
          remaining.add(selection);
        } else {
          removed.add(selection.shopId);
        }
      }
      selections = List.unmodifiable(remaining);
      needsConfirmation = Set.unmodifiable(removed);
      options = value;
      fresh = true;
    } on ApiFailure catch (value) {
      if (current(generation, credential) && query == _query) {
        if (value.status == 403 || value.status == 404) {
          options = null;
          selections = const [];
          needsConfirmation = const {};
        }
        failure(value);
      }
    } finally {
      if (current(generation, credential) && query == _query) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    invalidate();
    options = null;
    selections = const [];
    needsConfirmation = const {};
  }
}
