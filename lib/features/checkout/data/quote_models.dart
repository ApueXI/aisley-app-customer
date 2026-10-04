import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import 'commerce_address.dart';
import 'voucher_models.dart';

class CheckoutQuote {
  CheckoutQuote.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('quoteId');
    expiresAt = requiredTime(w, 'expiresAt');
    mode = w.string('mode');
    paymentMethod = w.string('paymentMethod');
    address = CommerceAddress.parse(w.object('address'), quote: true);
    groups = w.list('groups', QuoteGroup.parse);
    summary = CommerceTotals.parse(w.object('summary'));
    orderCount = Wire(w.object('summary')).positiveInt('orderCount');
    if (groups.isEmpty ||
        orderCount != groups.length ||
        groups.map((g) => g.shop.id).toSet().length != groups.length) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final String id, mode, paymentMethod;
  late final DateTime expiresAt;
  late final CommerceAddress address;
  late final List<QuoteGroup> groups;
  late final CommerceTotals summary;
  late final int orderCount;
}

class QuoteGroup {
  QuoteGroup.parse(Object? json) {
    final w = Wire(json);
    shop = CommerceShop.parse(w.object('shop'));
    items = w.list('items', QuoteItem.parse);
    candidates = w.list('availableVouchers', CheckoutVoucher.parse);
    applied = w.list('appliedVouchers', AppliedVoucher.parse);
    shipping = ShippingQuote.parse(w.object('shippingQuote'));
    totals = CommerceTotals.parse(w.object('totals'));
    if (items.isEmpty || !shipping.serviceable) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final CommerceShop shop;
  late final List<QuoteItem> items;
  late final List<CheckoutVoucher> candidates;
  late final List<AppliedVoucher> applied;
  late final ShippingQuote shipping;
  late final CommerceTotals totals;
}

class QuoteItem {
  QuoteItem.parse(Object? json) {
    final w = Wire(json);
    cartItemId = nullableUuid(w, 'cartItemId');
    productId = w.uuid('productId');
    variantId = nullableUuid(w, 'variantId');
    name = w.string('productName');
    sku = w.nullableString('sku');
    options = w.list('selectedOptions', SelectedOption.parse);
    unitPrice = Money.parse(w.field('unitPrice'));
    quantity = w.positiveInt('quantity');
    subtotal = Money.parse(w.field('lineSubtotal'));
  }
  late final String productId, name;
  late final String? cartItemId, variantId, sku;
  late final List<SelectedOption> options;
  late final Money unitPrice, subtotal;
  late final int quantity;
}

class ShippingQuote {
  ShippingQuote.parse(Object? json) {
    final w = Wire(json);
    serviceable = w.boolean('serviceable');
    rateId = w.uuid('rateVersionId');
    version = w.positiveInt('rateVersion');
    weight = nonnegative(w, 'billableWeightGrams');
    baseFee = Money.parse(w.field('baseFee'));
    additionalFee = Money.parse(w.field('additionalWeightFee'));
    surcharge = Money.parse(w.field('destinationSurcharge'));
    logisticsCount = nonnegative(w, 'eligibleLogisticsCount');
  }
  late final bool serviceable;
  late final String rateId;
  late final int version, weight, logisticsCount;
  late final Money baseFee, additionalFee, surcharge;
}
