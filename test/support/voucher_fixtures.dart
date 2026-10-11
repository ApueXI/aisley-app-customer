import 'fakes.dart';

Map<String, dynamic> voucherJson({
  String id = otherId,
  String issuer = 'shop',
  bool private = true,
  bool collected = false,
  String distribution = 'claim_required',
  String? reason,
  String status = 'available',
}) => {
  'id': id,
  'name': 'Synthetic voucher',
  'code': 'DEMO',
  'issuerType': issuer,
  'benefitType': 'discount',
  'valueType': 'percent',
  'value': '10.00',
  'minimumSpend': '100.00',
  'maximumDiscount': '50.00',
  'currency': 'PHP',
  'validFrom': '2026-10-01T00:00:00Z',
  'validUntil': '2026-11-01T00:00:00Z',
  'paymentMethod': 'cod',
  'termsSummary': null,
  'distributionMode': distribution,
  'scope': {
    'productIds': <String>[],
    'categoryIds': <String>[],
    'excludedProductIds': <String>[],
    'excludedCategoryIds': <String>[],
  },
  'shop': issuer == 'shop'
      ? {'id': customerId, 'name': 'Demo Shop', 'slug': 'demo-shop'}
      : null,
  'collectionUrl': issuer == 'shop'
      ? '/shops/demo-shop#vouchers'
      : '/vouchers/$id',
  'collected': private ? collected : null,
  'collectedAt': private && collected ? '2026-10-11T00:00:00Z' : null,
  'remainingPersonalUses': private ? 2 : null,
  'availabilityReason': reason,
  'canCollect':
      distribution == 'claim_required' && reason == null && !collected,
  'walletStatus': private ? status : null,
};
Map<String, dynamic> voucherPage(
  List<Map<String, dynamic>> rows, {
  int page = 1,
  int lastPage = 1,
}) => {
  'items': rows,
  'pagination': {
    'currentPage': page,
    'lastPage': lastPage,
    'perPage': 20,
    'total': rows.length,
  },
};

Map<String, dynamic> checkoutVoucherJson({bool claimed = false}) => {
  ...voucherJson(),
  'eligible': claimed,
  'reason': claimed ? null : 'VOUCHER_NOT_CLAIMED',
  'saving': claimed ? '10.00' : '0.00',
  'stackableWith': ['app:shipping', 'shop:shipping'],
};
