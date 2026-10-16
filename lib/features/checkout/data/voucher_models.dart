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
    name = w.optionalString('name') ?? code;
    distributionMode = w.optionalString('distributionMode');
    collectionUrl = w.optionalString('collectionUrl');
    issuer = w.string('issuerType');
    benefit = w.string('benefitType');
    valueType = w.string('valueType');
    value = Money.parse(w.field('value'));
    final maximum = w.field('maximumDiscount');
    maximumDiscount = maximum == null ? null : Money.parse(maximum);
    minimumSpend = Money.parse(w.field('minimumSpend'));
    terms = w.nullableString('termsSummary') ?? '';
    validFrom = requiredTime(w, 'validFrom');
    validUntil = requiredTime(w, 'validUntil');
    paymentMethod = w.nullableString('paymentMethod');
    stackableWith = w.strings('stackableWith');
    scope = VoucherScope.parse(w.object('scope'));
    eligible = w.boolean('eligible');
    reason = w.nullableString('reason');
    saving = Money.parse(w.field('saving'));
  }
  late final String id, code, name, issuer, benefit, valueType, terms;
  late final String? distributionMode, collectionUrl;
  late final String? paymentMethod, reason;
  late final Money value, minimumSpend, saving;
  late final Money? maximumDiscount;
  late final DateTime validFrom, validUntil;
  late final List<String> stackableWith;
  late final VoucherScope scope;
  late final bool eligible;
  bool get selectable =>
      eligible &&
      (distributionMode == null ||
          const ['automatic', 'claim_required'].contains(distributionMode)) &&
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
    name = w.optionalString('name') ?? code;
    issuer = w.string('issuerType');
    benefit = w.string('benefitType');
    qualifyingBasis = Money.parse(w.field('qualifyingBasis'));
    discount = Money.parse(w.field('discountAmount'));
  }
  late final String id, code, name, issuer, benefit;
  late final Money qualifyingBasis, discount;
}

class SnapshotVoucher {
  SnapshotVoucher.parse(Object? json, {bool batch = false}) {
    final w = Wire(json);
    id = nullableUuid(w, 'id');
    code = w.string('code');
    name = batch ? w.optionalString('name') ?? code : code;
    issuer = w.string('issuerType');
    benefit = w.string('benefitType');
    terms = w.string('termsSummary');
    discount = Money.parse(w.field('discountAmount'));
    qualifyingBasis = batch ? Money.parse(w.field('qualifyingBasis')) : null;
    currency = batch ? null : w.string('currency');
  }
  late final String? id, currency;
  late final String code, name, issuer, benefit, terms;
  late final Money discount;
  late final Money? qualifyingBasis;
}
