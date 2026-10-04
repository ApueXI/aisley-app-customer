import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';

class BuyNowItem {
  BuyNowItem(this.productId, this.variantId, this.quantity) {
    requireUuid(productId);
    if (variantId != null) requireUuid(variantId!);
    if (quantity < 1 || quantity > 2147483647) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  final String productId;
  final String? variantId;
  final int quantity;
  Map<String, dynamic> toJson() => Map.unmodifiable({
    'product_id': productId,
    'variant_id': variantId,
    'quantity': quantity,
  });
}

class CheckoutIntent {
  CheckoutIntent.cart(Iterable<String> ids)
    : cartIds = List.unmodifiable(ids),
      buyNow = null {
    if (cartIds.isEmpty || cartIds.toSet().length != cartIds.length) {
      throw const ApiFailure(FailureKind.decode);
    }
    for (final id in cartIds) {
      requireUuid(id);
    }
  }
  CheckoutIntent.buyNow(BuyNowItem item) : buyNow = item, cartIds = const [];
  final List<String> cartIds;
  final BuyNowItem? buyNow;
  String get mode => buyNow == null ? 'cart' : 'buy_now';
  Map<String, dynamic> toJson() => {
    'mode': mode,
    if (buyNow != null)
      'buy_now': buyNow!.toJson()
    else
      'cart_item_ids': cartIds,
  };
}

class VoucherSelection {
  VoucherSelection(this.voucherId, this.shopId) {
    requireUuid(voucherId);
    requireUuid(shopId);
  }
  final String voucherId, shopId;
  Map<String, dynamic> toJson() =>
      Map.unmodifiable({'voucher_id': voucherId, 'target_shop_id': shopId});
}

/// The exact reviewed request is immutable, including every nested value.
class CheckoutInput {
  CheckoutInput(
    this.intent,
    this.addressId,
    Iterable<VoucherSelection> selections,
  ) : vouchers = List.unmodifiable(selections) {
    requireUuid(addressId);
    if (vouchers.length > 20 ||
        vouchers.map((v) => v.voucherId).toSet().length != vouchers.length) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  final CheckoutIntent intent;
  final String addressId;
  final List<VoucherSelection> vouchers;
  Map<String, dynamic> toJson({String? quoteId}) => Map.unmodifiable({
    ...intent.toJson(),
    'address_id': addressId,
    'payment_method': 'cod',
    'vouchers': List.unmodifiable(vouchers.map((v) => v.toJson())),
    if (quoteId != null) 'quote_id': requireUuid(quoteId),
  });
}

class PendingPlacement {
  PendingPlacement({
    required this.key,
    required Map<String, dynamic> payload,
    required this.customerId,
    required this.sessionGeneration,
    required this.cartMode,
  }) : payload = freezePayload(payload);
  final String key, customerId;
  final Map<String, dynamic> payload;
  final int sessionGeneration;
  final bool cartMode;
  @override
  String toString() => 'PendingPlacement';
}

Map<String, dynamic> freezePayload(Map<String, dynamic> payload) {
  Object? freeze(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key, freeze(item))),
      );
    }
    if (value is List) return List<Object?>.unmodifiable(value.map(freeze));
    if (value == null || value is String || value is int || value is bool) {
      return value;
    }
    throw const ApiFailure(FailureKind.decode);
  }

  return freeze(payload) as Map<String, dynamic>;
}
