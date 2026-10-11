import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import '../../checkout/data/voucher_models.dart';
import '../../discovery/data/catalog_models.dart';

class VoucherShop {
  VoucherShop.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    name = w.string('name');
    slug = w.string('slug');
    if (!validShopSlug(slug)) throw const ApiFailure(FailureKind.decode);
  }
  late final String id, name, slug;
}

bool validShopSlug(String slug) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,254}$').hasMatch(slug);

class CustomerVoucher {
  CustomerVoucher.parse(Object? json, {required bool private}) {
    final w = Wire(json);
    id = w.uuid('id');
    name = w.string('name');
    code = w.string('code');
    issuer = w.string('issuerType');
    benefit = w.string('benefitType');
    valueType = w.string('valueType');
    value = Money.parse(w.field('value'));
    minimumSpend = Money.parse(w.field('minimumSpend'));
    maximumDiscount = w.field('maximumDiscount') == null
        ? null
        : Money.parse(w.field('maximumDiscount'));
    currency = w.string('currency');
    validFrom = requiredTime(w, 'validFrom');
    validUntil = requiredTime(w, 'validUntil');
    paymentMethod = w.nullableString('paymentMethod');
    terms = w.nullableString('termsSummary');
    distribution = w.string('distributionMode');
    scope = VoucherScope.parse(w.object('scope'));
    shop = w.field('shop') == null ? null : VoucherShop.parse(w.object('shop'));
    collectionUrl = w.nullableString('collectionUrl');
    final flag = w.field('collected');
    if (flag != null && flag is! bool) {
      throw const ApiFailure(FailureKind.decode);
    }
    collected = flag as bool?;
    collectedAt = w.timestamp('collectedAt');
    remainingUses = w.nullableInt('remainingPersonalUses');
    reason = w.nullableString('availabilityReason');
    canCollect = w.boolean('canCollect');
    walletStatus = w.nullableString('walletStatus');
    if (remainingUses != null && remainingUses! < 0 ||
        private && collected == null ||
        !private &&
            (collected != null ||
                collectedAt != null ||
                remainingUses != null ||
                walletStatus != null) ||
        issuer == 'app' && shop != null ||
        validUntil.isBefore(validFrom)) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final String id,
      name,
      code,
      issuer,
      benefit,
      valueType,
      currency,
      distribution;
  late final Money value, minimumSpend;
  late final Money? maximumDiscount;
  late final DateTime validFrom, validUntil;
  late final DateTime? collectedAt;
  late final String? paymentMethod, terms, collectionUrl, reason, walletStatus;
  late final VoucherScope scope;
  late final VoucherShop? shop;
  late final bool? collected;
  late final bool canCollect;
  late final int? remainingUses;

  bool get supported =>
      const ['app', 'shop'].contains(issuer) &&
      const ['discount', 'shipping'].contains(benefit) &&
      const ['fixed', 'percent'].contains(valueType) &&
      const ['automatic', 'claim_required'].contains(distribution) &&
      currency == 'PHP' &&
      (paymentMethod == null || paymentMethod == 'cod');
  bool get collectable =>
      supported &&
      collected == false &&
      canCollect &&
      distribution == 'claim_required' &&
      (issuer == 'app' || shop != null);
  String get benefitLabel =>
      benefit == 'shipping' ? 'Shipping savings' : 'Discount';
  String get valueLabel => valueType == 'percent'
      ? '${value.minorUnits / 100}% $benefitLabel'
      : '${value.display(currency)} $benefitLabel';
}

class VoucherPage {
  VoucherPage.parse(Object? json, {required bool private}) {
    final w = Wire(json);
    items = w.list('items', (v) => CustomerVoucher.parse(v, private: private));
    pagination = Pagination.parse(w.object('pagination'));
    if (items.map((v) => v.id).toSet().length != items.length ||
        pagination.total < 0 ||
        pagination.perPage > 50 ||
        items.length > pagination.perPage) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final List<CustomerVoucher> items;
  late final Pagination pagination;
}

String voucherReason(String? reason) => switch (reason) {
  'VOUCHER_NOT_CLAIMED' =>
    'Collect this voucher before selecting it at Checkout.',
  'VOUCHER_NOT_STARTED' => 'This voucher is not available yet.',
  'VOUCHER_EXPIRED' => 'This voucher has expired.',
  'VOUCHER_INACTIVE' => 'This voucher is paused.',
  'VOUCHER_ENDED' => 'This offer has ended.',
  'VOUCHER_EXHAUSTED' => 'All uses of this offer have been redeemed.',
  'VOUCHER_CUSTOMER_LIMIT' => 'You have used all your redemptions.',
  'VOUCHER_CUSTOMER_INELIGIBLE' =>
    'This offer is unavailable for your account.',
  'VOUCHER_PAYMENT_INELIGIBLE' => 'This offer does not support COD.',
  'VOUCHER_SHOP_UNAVAILABLE' => 'The issuing Shop is unavailable.',
  'VOUCHER_MINIMUM_SPEND' => 'The minimum spend is not met.',
  'VOUCHER_SCOPE_INELIGIBLE' => 'These items do not qualify.',
  'VOUCHER_FUNDING_INSUFFICIENT' => 'This offer cannot fund this order.',
  'VOUCHER_TERMS_INVALID' => 'This offer is currently unavailable.',
  null => '',
  _ => 'This voucher is unavailable for this purchase.',
};

String manilaVoucherTime(DateTime utc) {
  final date = utc.toUtc().add(const Duration(hours: 8));
  String pad(int v) => v.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)}';
}
