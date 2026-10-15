import 'dart:async';

import 'package:dio/dio.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_controller.dart';

import 'commerce_harness.dart';
import 'fakes.dart';

const shopA = customerId;
const shopB = '33333333-3333-4333-8333-333333333333';
const appDiscountA = '00000001-1111-4111-8111-111111111111';
const appDiscountB = '00000002-1111-4111-8111-111111111111';
const appShippingA = '00000003-1111-4111-8111-111111111111';
const appShippingB = '00000004-1111-4111-8111-111111111111';
const shopDiscountA = '00000005-1111-4111-8111-111111111111';
const shopDiscountA2 = '00000006-1111-4111-8111-111111111111';
const shopShippingA = '00000007-1111-4111-8111-111111111111';
const shopDiscountB = '00000008-1111-4111-8111-111111111111';
const shopShippingB = '00000009-1111-4111-8111-111111111111';

Map<String, dynamic> checkoutVoucher(
  String id,
  String issuer,
  String benefit,
) => {
  'id': id,
  'name': 'Voucher $id',
  'code': 'CODE-${id.substring(0, 8)}',
  'issuerType': issuer,
  'benefitType': benefit,
  'valueType': 'fixed',
  'value': '10.00',
  'maximumDiscount': null,
  'minimumSpend': '0.00',
  'termsSummary': 'Synthetic voucher terms',
  'validFrom': '2026-10-01T00:00:00Z',
  'validUntil': '2026-11-01T00:00:00Z',
  'paymentMethod': null,
  'stackableWith': <String>[],
  'scope': {
    'productIds': <String>[],
    'categoryIds': <String>[],
    'excludedProductIds': <String>[],
    'excludedCategoryIds': <String>[],
  },
  'eligible': true,
  'reason': null,
  'saving': '10.00',
};

/// Synthetic two-Shop transport. Totals and applied metadata come from replies,
/// not the controller under test. This does not simulate server redemption.
class CheckoutVoucherHarness extends CommerceHarness {
  CheckoutVoucherHarness() {
    final app = [
      checkoutVoucher(appDiscountA, 'app', 'discount'),
      checkoutVoucher(appDiscountB, 'app', 'discount'),
      checkoutVoucher(appShippingA, 'app', 'shipping'),
      checkoutVoucher(appShippingB, 'app', 'shipping'),
    ];
    candidates = {
      shopA: [
        ...app.map(clone),
        checkoutVoucher(shopDiscountA, 'shop', 'discount'),
        checkoutVoucher(shopDiscountA2, 'shop', 'discount'),
        checkoutVoucher(shopShippingA, 'shop', 'shipping'),
      ],
      shopB: [
        ...app.map(clone),
        checkoutVoucher(shopDiscountB, 'shop', 'discount'),
        checkoutVoucher(shopShippingB, 'shop', 'shipping'),
      ],
    };
  }
  late final Map<String, List<Map<String, dynamic>>> candidates;
  bool omitAppliedCandidates = false;
  Map<String, dynamic>? reviewed, committed;

  CheckoutController get checkout => commerce.checkout;

  Future<void> review() async {
    await settleShipping();
    await checkout.getQuote();
  }

  Future<void> begin() async {
    checkout.begin(CheckoutIntent.cart([customerId, otherId]));
    await checkout.loadAddresses();
    await review();
  }

  Future<void> select(String shop, String id, {bool selected = true}) async {
    final group = checkout.quote!.groups.firstWhere((g) => g.shop.id == shop);
    checkout.chooseVoucher(group, CheckoutVoucherCandidate(id), selected);
    await review();
  }

  @override
  Map<String, dynamic> optionsFor(Map<String, dynamic> input) {
    final body = super.optionsFor(input);
    final groups = body['data']['groups'] as List;
    groups.add(clone(groups.first)..['shop'] = {'id': shopB, 'name': 'Shop B'});
    return body;
  }

  @override
  Map<String, dynamic> quoteFor(Map<String, dynamic> input) {
    final body = super.quoteFor(input);
    final data = body['data'] as Map<String, dynamic>;
    final base = data['groups'][0] as Map<String, dynamic>;
    final groups = <Map<String, dynamic>>[];
    for (final (index, shop) in [shopA, shopB].indexed) {
      final selected = (input['vouchers'] as List).cast<Map>().where(
        (v) => v['target_shop_id'] == shop,
      );
      final applied = [
        for (final selection in selected)
          {
            ...candidates[shop]!.firstWhere(
              (v) => v['id'] == selection['voucher_id'],
            ),
            'qualifyingBasis': '100.00',
            'discountAmount': '10.00',
          },
      ];
      final group = clone(base);
      group['shop'] = {'id': shop, 'name': index == 0 ? 'Shop A' : 'Shop B'};
      group['items'] = [base['items'][index]];
      group['availableVouchers'] = candidates[shop]!
          .where(
            (v) =>
                !omitAppliedCandidates ||
                !applied.any((a) => a['id'] == v['id']),
          )
          .toList();
      group['appliedVouchers'] = applied;
      groups.add(group);
    }
    data['groups'] = groups;
    data['summary']['orderCount'] = 2;
    reviewed = clone(body);
    return body;
  }

  Map<String, dynamic> batch() {
    final body = fixture('checkout-order', 'op-030');
    final base = body['data']['orders'][0] as Map<String, dynamic>;
    body['data']['orders'] = [
      for (final (index, group)
          in (reviewed!['data']['groups'] as List).indexed)
        {
          ...clone(base),
          'id': index == 0 ? customerId : otherId,
          'reference': 'ORDER-${index + 1}',
          'shop': group['shop'],
          'vouchers': group['appliedVouchers'],
        },
    ];
    return body;
  }

  @override
  FutureOr<ResponseBody> defaultReply(RequestOptions options) {
    if (options.uri.path.endsWith('/checkout/place')) {
      committed ??= batch();
      return jsonReply(committed!);
    }
    if (options.method == 'GET' && options.uri.path.contains('/checkout/')) {
      return jsonReply(committed ?? batch());
    }
    return super.defaultReply(options);
  }
}
