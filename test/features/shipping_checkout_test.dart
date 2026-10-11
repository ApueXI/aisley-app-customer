import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_controller.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';
import '../support/shipping_scenarios.dart';

const alternate = '33333333-3333-4333-8333-333333333333';
const secondShop = '44444444-4444-4444-8444-444444444444';

void main() {
  late CommerceHarness h;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());

  Future<void> begin() async {
    final c = h.commerce.checkout;
    c.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
    await c.loadAddresses();
  }

  Map<String, dynamic> multipleOptions(Map<String, dynamic> input) {
    final body =
        shippingScenario('multiple-provider-options')['expected']['body']
            as Map<String, dynamic>;
    body['data']['address']['id'] = input['address_id'];
    return body;
  }

  test(
    'automatic single option preserves implicit selection in quote and place',
    () async {
      await begin();
      final c = h.commerce.checkout;
      expect(c.shipping.ready, true);
      expect(c.shipping.selections, isEmpty);
      final discovery = h.adapter.requests.last;
      expect(discovery.uri.path, '/api/v1/customer/checkout/logistics-options');
      expect(discovery.data.containsKey('logistics_selections'), false);
      expect(discovery.headers.containsKey('Idempotency-Key'), false);
      await c.getQuote();
      expect(c.quote!.groups.single.shipping.organizationId, otherId);
      expect(h.adapter.requests.last.data['logistics_selections'], isEmpty);
      expect(await c.place(), isNotNull);
      expect(h.adapter.requests.last.data['logistics_selections'], isEmpty);
    },
  );

  test('multiple options require deliberate choice and provider change invalidates review', () async {
    h.reply = (r) => r.uri.path.endsWith('/logistics-options')
        ? jsonReply(multipleOptions(r.data as Map<String, dynamic>))
        : h.defaultReply(r);
    await begin();
    final c = h.commerce.checkout;
    expect(c.canQuote, false);
    await c.getQuote();
    expect(
      h.adapter.requests.where((r) => r.uri.path.endsWith('/quote')),
      isEmpty,
    );
    c.chooseProvider(customerId, otherId);
    await c.getQuote();
    expect(c.canPlace, true);
    c.chooseProvider(customerId, alternate);
    expect(c.quote, isNull);
    expect(c.canPlace, false);
    h.reply = (r) {
      if (!r.uri.path.endsWith('/quote')) return h.defaultReply(r);
      final response = h.quoteFor(r.data as Map<String, dynamic>);
      response['data']['groups'][0]['shippingQuote']['logisticsOrganizationId'] =
          alternate;
      response['data']['groups'][0]['shippingQuote']['logisticsBusinessName'] =
          'Alternate';
      return jsonReply(response);
    };
    await c.getQuote();
    expect(c.canPlace, true);
    expect(h.adapter.requests.last.data['logistics_selections'], [
      {'shop_id': customerId, 'logistics_organization_id': alternate},
    ]);
  });

  test(
    'implicit to explicit same provider still requires another quote',
    () async {
      await begin();
      final c = h.commerce.checkout;
      await c.getQuote();
      c.chooseProvider(customerId, otherId);
      expect(c.canPlace, false);
      expect(c.quote, isNull);
      await c.getQuote();
      expect(c.canPlace, true);
      expect(
        h.adapter.requests.last.data['logistics_selections'],
        hasLength(1),
      );
    },
  );

  test(
    'empty discovery is success but blocked; failed discovery is an error',
    () async {
      h.reply = (r) => r.uri.path.endsWith('/logistics-options')
          ? jsonReply(
              shippingScenario('empty-provider-options')['expected']['body']
                  as Map<String, dynamic>,
            )
          : h.defaultReply(r);
      await begin();
      final c = h.commerce.checkout;
      expect(c.shipping.fresh, true);
      expect(c.shipping.error, isNull);
      expect(c.canQuote, false);
      h.reply = (r) => r.uri.path.endsWith('/logistics-options')
          ? jsonReply({'code': 'SHIPPING_RATE_UNAVAILABLE'}, status: 409)
          : h.defaultReply(r);
      await c.loadShippingOptions();
      expect(c.shipping.fresh, false);
      expect(c.shipping.error, contains('Shipping rates'));
      expect(c.canQuote, false);
    },
  );

  test('removed choice needs explicit confirmation even when one replacement remains', () async {
    h.reply = (r) => r.uri.path.endsWith('/logistics-options')
        ? jsonReply(multipleOptions(r.data as Map<String, dynamic>))
        : h.defaultReply(r);
    await begin();
    final c = h.commerce.checkout;
    c.chooseProvider(customerId, alternate);
    h.reply = null;
    await c.loadShippingOptions();
    expect(c.shipping.selections, isEmpty);
    expect(c.shipping.needsConfirmation, {customerId});
    expect(c.canQuote, false);
    c.chooseProvider(customerId, otherId);
    expect(c.shipping.needsConfirmation, isEmpty);
    expect(c.canQuote, true);
  });

  test(
    'multi-Shop choices remain independent and one provider may serve both',
    () async {
      final c = h.commerce.checkout;
      h.reply = (r) {
        final input = r.data;
        if (r.uri.path.endsWith('/logistics-options')) {
          final body = multipleOptions(input as Map<String, dynamic>);
          final group = clone(body['data']['groups'][0]);
          group['shop']['id'] = secondShop;
          body['data']['groups'].add(group);
          return jsonReply(body);
        }
        if (r.uri.path.endsWith('/quote')) {
          final q = h.quoteFor(input as Map<String, dynamic>);
          final first = q['data']['groups'][0];
          first['items'] = [first['items'][0]];
          final second = clone(first);
          second['shop']['id'] = secondShop;
          second['items'][0]['cartItemId'] = otherId;
          q['data']['groups'].add(second);
          q['data']['summary']['orderCount'] = 2;
          return jsonReply(q);
        }
        return h.defaultReply(r);
      };
      c.begin(CheckoutIntent.cart([customerId, otherId]));
      await c.loadAddresses();
      c.chooseProvider(customerId, otherId);
      expect(c.canQuote, false);
      c.chooseProvider(secondShop, otherId);
      expect(c.canQuote, true);
      await c.getQuote();
      expect(c.canPlace, true);
      expect(c.quote!.groups, hasLength(2));
      expect(h.adapter.requests.last.data['logistics_selections'], [
        {'shop_id': customerId, 'logistics_organization_id': otherId},
        {'shop_id': secondShop, 'logistics_organization_id': otherId},
      ]);
      c.chooseProvider(secondShop, alternate);
      expect(c.shipping.selections.first.organizationId, otherId);
      expect(c.shipping.selections.last.organizationId, alternate);
      expect(c.canPlace, false);
    },
  );

  test('unplanned quote is commercially serviceable; unknown route blocks placement', () async {
    await begin();
    final c = h.commerce.checkout;
    var route = 'unplanned';
    h.reply = (r) {
      if (!r.uri.path.endsWith('/quote')) return h.defaultReply(r);
      final body = h.quoteFor(r.data as Map<String, dynamic>);
      body['data']['groups'][0]['shippingQuote']['routeStatus'] = route;
      return jsonReply(body);
    };
    await c.getQuote();
    expect(c.canPlace, true);
    route = 'future';
    await c.getQuote();
    expect(c.quote, isNotNull);
    expect(c.canPlace, false);
  });

  test('lost response replays original key and frozen provider despite expiry and changed availability', () async {
    await begin();
    final c = h.commerce.checkout;
    c.chooseProvider(customerId, otherId);
    await c.getQuote();
    var calls = 0;
    h.reply = (r) {
      if (r.uri.path.endsWith('/place') && ++calls == 1) {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionTimeout,
        );
      }
      return h.defaultReply(r);
    };
    expect(await c.place(), isNull);
    final pending = c.pending!;
    final payload = jsonEncode(pending.payload);
    final discoveryCount = h.adapter.requests
        .where((r) => r.uri.path.endsWith('/logistics-options'))
        .length;
    h.now = h.now.add(const Duration(hours: 1));
    c.chooseProvider(customerId, alternate);
    c.chooseAddress(otherId);
    await c.loadShippingOptions();
    expect(c.pending, same(pending));
    expect(await c.retryPending(), isNotNull);
    final requests = h.adapter.requests
        .where((r) => r.uri.path.endsWith('/place'))
        .toList();
    expect(requests, hasLength(2));
    expect(requests.map((r) => r.headers['Idempotency-Key']).toSet(), {
      pending.key,
    });
    expect(requests.map((r) => jsonEncode(r.data)).toSet(), {payload});
    expect(
      h.adapter.requests
          .where((r) => r.uri.path.endsWith('/logistics-options'))
          .length,
      discoveryCount,
    );
  });

  test('address change discards obsolete discovery and quote while preserving valid choices', () async {
    await begin();
    final c = h.commerce.checkout;
    c.chooseProvider(customerId, otherId);
    await c.getQuote();
    final addresses = fixture('address-book', 'op-015');
    final second = clone(addresses['data'][0]);
    second['id'] = otherId;
    addresses['data'].add(second);
    final delayed = Completer<ResponseBody>();
    h.reply = (r) {
      if (r.uri.path.endsWith('/addresses')) return jsonReply(addresses);
      if (r.uri.path.endsWith('/logistics-options') &&
          r.data['address_id'] == customerId) {
        return delayed.future;
      }
      return h.defaultReply(r);
    };
    final flight = c.loadAddresses();
    while (c.loadingAddresses) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(c.quote, isNull);
    c.chooseAddress(otherId);
    await h.settleShipping();
    expect(c.shipping.options!.address.id, otherId);
    delayed.complete(jsonReply(h.optionsFor({'address_id': customerId})));
    await flight;
    expect(c.shipping.options!.address.id, otherId);
    expect(c.shipping.selections.single.organizationId, otherId);
  });

  test(
    'logout rejects delayed discovery and clears options and selections',
    () async {
      await begin();
      final c = h.commerce.checkout;
      c.chooseProvider(customerId, otherId);
      final delayed = Completer<ResponseBody>();
      h.reply = (r) => r.uri.path.endsWith('/logistics-options')
          ? delayed.future
          : h.defaultReply(r);
      final flight = c.loadShippingOptions();
      await h.session.signOut();
      delayed.complete(jsonReply(h.optionsFor({'address_id': customerId})));
      await flight;
      expect(c.shipping.options, isNull);
      expect(c.shipping.selections, isEmpty);
      expect(c.canQuote, false);
    },
  );

  test(
    'a quote cannot substitute a different explicitly selected provider',
    () async {
      await begin();
      final c = h.commerce.checkout;
      c.chooseProvider(customerId, otherId);
      h.reply = (r) {
        if (!r.uri.path.endsWith('/quote')) return h.defaultReply(r);
        final body = h.quoteFor(r.data as Map<String, dynamic>);
        body['data']['groups'][0]['shippingQuote']['logisticsOrganizationId'] =
            alternate;
        return jsonReply(body);
      };
      await c.getQuote();
      expect(c.quote, isNull);
      expect(c.canPlace, false);
      expect(c.error, contains('could not be read'));
    },
  );

  for (final name in [
    'changed-selection-after-implicit-quote',
    'provider-rate-route-change',
    'changed-intent-under-used-key',
  ]) {
    test(
      'placement conflict preserves safe selection without fresh-key retry: $name',
      () async {
        await begin();
        final c = h.commerce.checkout;
        c.chooseProvider(customerId, otherId);
        await c.getQuote();
        final scenario = shippingScenario(name)['expected'];
        h.reply = (r) => r.uri.path.endsWith('/place')
            ? jsonReply(
                scenario['body'] as Map<String, dynamic>,
                status: scenario['status'] as int,
              )
            : h.defaultReply(r);
        expect(await c.place(), isNull);
        expect(c.canPlace, false);
        final requests = h.adapter.requests.length;
        expect(await c.place(), isNull);
        expect(h.adapter.requests, hasLength(requests));
        if (name == 'changed-intent-under-used-key') {
          expect(c.pending!.payload['logistics_selections'], hasLength(1));
          expect(c.collision, true);
          expect(await c.retryPending(), isNull);
        } else {
          expect(c.pending, isNull);
          expect(c.quote, isNull);
          expect(c.shipping.selections.single.organizationId, otherId);
        }
      },
    );
  }

  test('shipping voucher and provider changes preserve selections but require updated savings review', () async {
    final voucher = {
      'id': alternate,
      'code': 'SHIPPING',
      'issuerType': 'shop',
      'benefitType': 'shipping',
      'valueType': 'fixed',
      'value': '50.00',
      'maximumDiscount': null,
      'minimumSpend': '0.00',
      'termsSummary': 'Synthetic shipping saving',
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
      'saving': '50.00',
    };
    h.reply = (r) {
      if (r.uri.path.endsWith('/logistics-options')) {
        return jsonReply(multipleOptions(r.data as Map<String, dynamic>));
      }
      if (!r.uri.path.endsWith('/quote')) return h.defaultReply(r);
      final input = r.data as Map<String, dynamic>;
      final body = h.quoteFor(input);
      final group = body['data']['groups'][0];
      final changed =
          input['logistics_selections'][0]['logistics_organization_id'] ==
          alternate;
      group['shippingQuote']['logisticsOrganizationId'] = changed
          ? alternate
          : otherId;
      group['shippingQuote']['shippingFee'] = changed ? '120.00' : '100.00';
      group['availableVouchers'] = [voucher];
      if ((input['vouchers'] as List).isNotEmpty) {
        group['appliedVouchers'] = [
          {
            'id': alternate,
            'code': 'SHIPPING',
            'issuerType': 'shop',
            'benefitType': 'shipping',
            'qualifyingBasis': '100.00',
            'discountAmount': '50.00',
          },
        ];
      }
      for (final totals in [group['totals'], body['data']['summary']]) {
        totals['shippingFee'] = changed ? '120.00' : '100.00';
        totals['shippingDiscount'] = (input['vouchers'] as List).isEmpty
            ? '0.00'
            : '50.00';
        totals['payable'] = (input['vouchers'] as List).isEmpty
            ? '200.00'
            : changed
            ? '170.00'
            : '150.00';
      }
      return jsonReply(body);
    };
    await begin();
    final c = h.commerce.checkout;
    c.chooseProvider(customerId, otherId);
    await c.getQuote();
    c.chooseVoucher(
      c.quote!.groups.single,
      const CheckoutVoucherCandidate(alternate),
      true,
    );
    expect(c.quote, isNull);
    expect(c.canPlace, false);
    await h.settleShipping();
    await c.getQuote();
    expect(c.quote!.summary.payable.minorUnits, 15000);
    c.chooseProvider(customerId, alternate);
    expect(c.canPlace, false);
    expect(c.vouchers.single.voucherId, alternate);
    await c.getQuote();
    expect(c.quote!.summary.payable.minorUnits, 17000);
    expect(c.quote!.groups.single.shipping.fee.minorUnits, 12000);
    expect(c.canPlace, true);
  });

  for (final name in [
    'multiple-requires-selection',
    'foreign-shop-selection',
    'disabled-provider',
    'unavailable-provider',
    'no-active-platform-tariff',
    'provider-tariff-not-accepted',
    'route-participant-limit-failure',
  ]) {
    test('safe quote failure and refreshed options required: $name', () async {
      await begin();
      final scenario = shippingScenario(name)['expected'];
      h.reply = (r) => r.uri.path.endsWith('/quote')
          ? jsonReply(
              scenario['body'] as Map<String, dynamic>,
              status: scenario['status'] as int,
            )
          : h.defaultReply(r);
      final c = h.commerce.checkout;
      await c.getQuote();
      expect(c.error, isNotNull);
      expect(c.error, isNot(contains('Synthetic')));
      expect(c.canPlace, false);
      expect(c.canQuote, false);
    });
  }

  test('options read retries bounded transport failures and honors throttle without writes', () async {
    var attempts = 0;
    h.reply = (r) {
      if (r.uri.path.endsWith('/logistics-options') && ++attempts == 1) {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionTimeout,
        );
      }
      return h.defaultReply(r);
    };
    await begin();
    expect(attempts, 2);
    final c = h.commerce.checkout;
    expect(c.shipping.ready, true);
    h.reply = (r) => r.uri.path.endsWith('/logistics-options')
        ? jsonReply(
            {},
            status: 429,
            headers: {
              'retry-after': ['30'],
            },
          )
        : h.defaultReply(r);
    await c.loadShippingOptions();
    expect(c.shipping.coolingDown, true);
    final count = h.adapter.requests.length;
    await c.loadShippingOptions();
    expect(h.adapter.requests, hasLength(count));
  });
}
