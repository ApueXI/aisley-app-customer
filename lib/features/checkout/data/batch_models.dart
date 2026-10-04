import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import 'commerce_address.dart';
import 'voucher_models.dart';

class CheckoutBatch {
  CheckoutBatch.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    currency = w.string('currency');
    placedAt = requiredTime(w, 'placedAt');
    orders = w.list('orders', BatchOrder.parse);
    if (orders.isEmpty ||
        orders.map((o) => o.id).toSet().length != orders.length ||
        orders.map((o) => o.shop.id).toSet().length != orders.length) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final String id, currency;
  late final DateTime placedAt;
  late final List<BatchOrder> orders;
}

class BatchOrder {
  BatchOrder.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    reference = w.string('reference');
    status = w.string('status');
    paymentMethod = w.string('paymentMethod');
    paymentStatus = w.string('paymentStatus');
    shop = CommerceShop.parse(w.object('shop'));
    items = w.list('items', SnapshotItem.parse);
    address = CommerceAddress.parse(w.object('address'), batch: true);
    vouchers = w.list('vouchers', (v) => SnapshotVoucher.parse(v, batch: true));
    final shippingJson = w.field('shippingQuote');
    shipping = shippingJson == null ? null : BatchShipping.parse(shippingJson);
    totals = CommerceTotals.parse(w.object('totals'));
    detailUrl = w.string('detailUrl');
    if (items.isEmpty) throw const ApiFailure(FailureKind.decode);
  }
  late final String id,
      reference,
      status,
      paymentMethod,
      paymentStatus,
      detailUrl;
  late final CommerceShop shop;
  late final List<SnapshotItem> items;
  late final CommerceAddress address;
  late final List<SnapshotVoucher> vouchers;
  late final BatchShipping? shipping;
  late final CommerceTotals totals;
}

class SnapshotItem {
  SnapshotItem.parse(Object? json, {bool reviewable = false}) {
    final w = Wire(json);
    id = w.uuid('id');
    productId = nullableUuid(w, 'productId');
    variantId = nullableUuid(w, 'variantId');
    name = w.string('productName');
    variantName = w.nullableString('variantName');
    sku = w.nullableString('sku');
    options = w.list('selectedOptions', SelectedOption.parse);
    unitPrice = Money.parse(w.field('unitPrice'));
    quantity = w.positiveInt('quantity');
    subtotal = Money.parse(w.field('lineSubtotal'));
    currency = w.string('currency');
    canReview = reviewable ? w.boolean('canReview') : false;
    reviewId = reviewable ? nullableUuid(w, 'reviewId') : null;
  }
  late final String id, name, currency;
  late final String? productId, variantId, variantName, sku, reviewId;
  late final bool canReview;
  late final List<SelectedOption> options;
  late final Money unitPrice, subtotal;
  late final int quantity;
}

class BatchShipping {
  BatchShipping.parse(Object? json) {
    final w = Wire(json);
    rateId = w.uuid('rateVersionId');
    version = w.positiveInt('rateVersion');
    weight = nonnegative(w, 'billableWeightGrams');
    logisticsCount = nonnegative(w, 'eligibleLogisticsCount');
  }
  late final String rateId;
  late final int version, weight, logisticsCount;
}
