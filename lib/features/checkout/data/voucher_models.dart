import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/wire.dart';

class VoucherScope {
  VoucherScope.parse(Object? json) {
    final w = Wire(json);
    productIds = List.unmodifiable(w.strings('productIds').map(requireUuid));
    categoryIds = List.unmodifiable(w.strings('categoryIds').map(requireUuid));
    excludedProducts = List.unmodifiable(
      w.strings('excludedProductIds').map(requireUuid),
    );
    excludedCategories = List.unmodifiable(
      w.strings('excludedCategoryIds').map(requireUuid),
    );
  }
  late final List<String> productIds,
      categoryIds,
      excludedProducts,
      excludedCategories;
}

class CheckoutVoucher {
  CheckoutVoucher.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    code = w.string('code');
    issuer = w.string('issuerType');
    benefit = w.string('benefitType');
    valueType = w.string('valueType');
    value = Money.parse(w.field('value'));
    final maximum = w.field('maximumDiscount');
    maximumDiscount = maximum == null ? null : Money.parse(maximum);
    minimumSpend = Money.parse(w.field('minimumSpend'));
    terms = w.string('termsSummary');
    validFrom = requiredTime(w, 'validFrom');
    validUntil = requiredTime(w, 'validUntil');
    paymentMethod = w.nullableString('paymentMethod');
    stackableWith = w.strings('stackableWith');
    scope = VoucherScope.parse(w.object('scope'));
    eligible = w.boolean('eligible');
    reason = w.nullableString('reason');
    saving = Money.parse(w.field('saving'));
  }
  late final String id, code, issuer, benefit, valueType, terms;
  late final String? paymentMethod, reason;
  late final Money value, minimumSpend, saving;
  late final Money? maximumDiscount;
  late final DateTime validFrom, validUntil;
  late final List<String> stackableWith;
  late final VoucherScope scope;
  late final bool eligible;
  bool get selectable =>
      eligible &&
      const ['app', 'shop'].contains(issuer) &&
      const ['discount', 'shipping'].contains(benefit) &&
      const ['fixed', 'percent'].contains(valueType) &&
      (paymentMethod == null || paymentMethod == 'cod');
}

class AppliedVoucher {
  AppliedVoucher.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    code = w.string('code');
    issuer = w.string('issuerType');
    benefit = w.string('benefitType');
    qualifyingBasis = Money.parse(w.field('qualifyingBasis'));
    discount = Money.parse(w.field('discountAmount'));
  }
  late final String id, code, issuer, benefit;
  late final Money qualifyingBasis, discount;
}

class SnapshotVoucher {
  SnapshotVoucher.parse(Object? json, {bool batch = false}) {
    final w = Wire(json);
    id = nullableUuid(w, 'id');
    code = w.string('code');
    issuer = w.string('issuerType');
    benefit = w.string('benefitType');
    terms = w.string('termsSummary');
    discount = Money.parse(w.field('discountAmount'));
    qualifyingBasis = batch ? Money.parse(w.field('qualifyingBasis')) : null;
    currency = batch ? null : w.string('currency');
  }
  late final String? id, currency;
  late final String code, issuer, benefit, terms;
  late final Money discount;
  late final Money? qualifyingBasis;
}
