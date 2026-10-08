import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/networking/request_cooldown.dart';
import '../data/discovery_repository.dart';
import '../data/product_detail_model.dart';

class ProductDetailController extends ChangeNotifier with RequestCooldown {
  ProductDetailController(this.repository, this.productId);
  final DiscoveryRepository repository;
  final String productId;
  ProductDetail? product;
  String? error;
  bool loading = false, _disposed = false;
  int quantity = 1, _generation = 0;
  final _selectedValues = <String, String>{};

  Map<String, String> get selectedValues => Map.unmodifiable(_selectedValues);
  ProductVariant? get selectedVariant {
    final current = product;
    if (current == null ||
        current.optionGroups.isEmpty ||
        _selectedValues.length != current.optionGroups.length) {
      return null;
    }
    final selectedIds = _selectedValues.values.toSet();
    if (selectedIds.length != current.optionGroups.length) return null;
    for (final variant in current.variants) {
      if (variant.optionValueIds.length == selectedIds.length &&
          variant.optionValueIds.toSet().containsAll(selectedIds)) {
        return variant;
      }
    }
    return null;
  }

  bool get requiresVariantSelection =>
      product?.availability.requiresVariantSelection == true;
  int? get availableStock =>
      selectedVariant?.stockQuantity ??
      (requiresVariantSelection ? null : product?.availability.stockQuantity);
  bool get selectionValid =>
      !requiresVariantSelection || selectedVariant != null;
  bool get available =>
      selectionValid &&
      (selectedVariant?.inStock ?? product?.availability.inStock ?? false);
  bool get canPurchaseQuantity {
    final stock = availableStock;
    return available && quantity > 0 && (stock == null || quantity <= stock);
  }

  bool canChoose(String groupId, String valueId) =>
      product?.variants.any(
        (variant) =>
            variant.inStock &&
            variant.stockQuantity > 0 &&
            variant.optionValueIds.contains(valueId) &&
            _selectedValues.entries.every(
              (entry) =>
                  entry.key == groupId ||
                  variant.optionValueIds.contains(entry.value),
            ),
      ) ==
      true;
  void resetChoices() {
    _selectedValues.clear();
    quantity = 1;
    notifyListeners();
  }

  double? get currentPrice => selectedVariant?.price ?? product?.price;

  Future<void> load() async {
    if (coolingDown) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    product = null;
    _selectedValues.clear();
    notifyListeners();
    try {
      final value = await repository.product(productId, refresh: true);
      if (!_disposed && generation == _generation) {
        product = value;
        quantity = availableStock == 0 ? 0 : 1;
      }
    } on ApiFailure catch (failure) {
      if (!_disposed && generation == _generation) {
        error = describeFailure(failure);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void choose(String groupId, String valueId) {
    final current = product;
    if (current == null ||
        !current.optionGroups.any(
          (group) =>
              group.id == groupId &&
              group.values.any((value) => value.id == valueId),
        )) {
      return;
    }
    _selectedValues[groupId] = valueId;
    // A quantity belongs to one exact option combination. Start with one
    // after any option changes so stale stock from the previous choice cannot
    // leave the new selection in an invalid state.
    quantity = 1;
    notifyListeners();
  }

  bool chooseVariantId(String? variantId) {
    if (variantId == null) return false;
    final current = product;
    if (current == null) return false;
    ProductVariant? match;
    for (final variant in current.variants) {
      if (variant.id == variantId) match = variant;
    }
    if (match == null) return false;
    _selectedValues.clear();
    for (final group in current.optionGroups) {
      final value = group.values.where(
        (value) => match!.optionValueIds.contains(value.id),
      );
      if (value.length != 1) {
        _selectedValues.clear();
        return false;
      }
      _selectedValues[group.id] = value.first.id;
    }
    notifyListeners();
    return selectedVariant?.id == variantId;
  }

  void setQuantity(int value) {
    if (value < 1) return;
    quantity = value;
    notifyListeners();
  }

  void increment() {
    final stock = availableStock;
    if (stock != null && quantity < stock && available) {
      quantity++;
      notifyListeners();
    }
  }

  void decrement() {
    if (quantity > 1) {
      quantity--;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
