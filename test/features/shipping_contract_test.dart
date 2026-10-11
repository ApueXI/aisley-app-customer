import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/batch_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/quote_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/shipping_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_models.dart';

import '../support/fakes.dart';
import '../support/shipping_scenarios.dart';

void main() {
  test(
    'documented successful shipping projections parse without old fields',
    () {
      for (final name in [
        'single-option-fallback',
        'explicit-provider-quote',
        'route-participant-tariff-fallback',
      ]) {
        final quote = CheckoutQuote.parse(
          shippingScenario(name)['expected']['body']['data'],
        );
        expect(
          quote.groups.single.shipping.fee.minorUnits,
          name == 'route-participant-tariff-fallback' ? 500 : 10000,
        );
        expect(quote.groups.single.shipping.organizationId, otherId);
        expect(quote.groups.single.shipping.supported, true);
      }
      final batch = CheckoutBatch.parse(
        shippingScenario('exact-placement-replay')['expected']['body']['data'],
      );
      expect(batch.orders.single.shipping!.fee.minorUnits, 10000);
      expect(batch.orders.single.shipping!.businessName, 'Synthetic Logistics');
      final order = BuyerOrder.parse(
        shippingScenario(
          'legacy-nullable-order-provider',
        )['expected']['body']['data'],
      );
      expect(order.shippingProvider, isNull);
      expect(order.canCorrect, true);
    },
  );

  test('Batch nullable shipping and legacy provider nulls are distinct from absence', () {
    final data =
        fixture('checkout-order', 'op-030')['data'] as Map<String, dynamic>;
    final order = data['orders'][0] as Map<String, dynamic>;
    final shipping = order['shippingQuote'] as Map<String, dynamic>;
    shipping['logisticsOrganizationId'] = null;
    shipping['logisticsBusinessName'] = null;
    final batch = CheckoutBatch.parse(data);
    expect(batch.orders.single.shipping!.organizationId, isNull);
    expect(batch.orders.single.shipping!.fee.minorUnits, 10000);
    shipping.remove('logisticsOrganizationId');
    expect(() => CheckoutBatch.parse(data), throwsA(isA<ApiFailure>()));
    order['shippingQuote'] = null;
    expect(CheckoutBatch.parse(data).orders.single.shipping, isNull);
    order.remove('shippingQuote');
    expect(() => CheckoutBatch.parse(data), throwsA(isA<ApiFailure>()));
  });

  test('Order list detail and mutations require nullable typed provider', () {
    final detail =
        fixture('order-status', 'op-033')['data'] as Map<String, dynamic>;
    detail['shippingProvider'] = {
      'id': otherId,
      'businessName': 'Chosen provider',
    };
    expect(
      BuyerOrder.parse(detail).shippingProvider!.businessName,
      'Chosen provider',
    );
    detail['shippingProvider'] = null;
    expect(BuyerOrder.parse(detail).shippingProvider, isNull);
    detail.remove('shippingProvider');
    expect(() => BuyerOrder.parse(detail), throwsA(isA<ApiFailure>()));
    final summary =
        fixture('order-status', 'op-032')['data'][0] as Map<String, dynamic>;
    summary['shippingProvider'] = {
      'id': otherId,
      'businessName': 'Chosen provider',
    };
    expect(OrderSummary.parse(summary).shippingProvider!.id, otherId);
    summary['shippingProvider'] = null;
    expect(OrderSummary.parse(summary).shippingProvider, isNull);
    summary.remove('shippingProvider');
    expect(() => OrderSummary.parse(summary), throwsA(isA<ApiFailure>()));
    for (final op in ['op-035', 'op-036']) {
      expect(
        () => BuyerOrder.parse(
          fixture('order-modification-cancellation', op)['data'],
        ),
        returnsNormally,
      );
    }
  });

  test('options allow zero and multiple choices but reject malformed required values', () {
    expect(
      LogisticsOptions.parse(
        shippingScenario('empty-provider-options')['expected']['body']['data'],
      ).groups.single.options,
      isEmpty,
    );
    expect(
      LogisticsOptions.parse(
        shippingScenario(
          'multiple-provider-options',
        )['expected']['body']['data'],
      ).groups.single.options,
      hasLength(2),
    );
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (v) => v.remove('options'),
      (v) => v['options'][0].remove('organizationId'),
      (v) => v['options'][0]['shippingFee'] = 100,
      (v) => v['options'][0]['routeStatus'] = null,
      (v) => v['options'].add(v['options'][0]),
    ]) {
      final group =
          fixture('checkout-order', 'op-096')['data']['groups'][0]
              as Map<String, dynamic>;
      mutate(group);
      expect(
        () => LogisticsOptionGroup.parse(group),
        throwsA(isA<ApiFailure>()),
      );
    }
    final options =
        fixture('checkout-order', 'op-096')['data'] as Map<String, dynamic>;
    options['groups'].add(options['groups'][0]);
    expect(() => LogisticsOptions.parse(options), throwsA(isA<ApiFailure>()));
    final quote =
        fixture('checkout-order', 'op-029')['data'] as Map<String, dynamic>;
    quote['groups'][0]['shippingQuote']['routeStatus'] = 'future';
    expect(CheckoutQuote.parse(quote).groups.single.shipping.supported, false);
    quote['groups'][0]['shippingQuote'].remove('shippingFee');
    expect(() => CheckoutQuote.parse(quote), throwsA(isA<ApiFailure>()));
  });

  test('selection intent is immutable canonical and discovery omits it', () {
    const alpha = 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA';
    final draft = [
      LogisticsSelection(alpha, otherId),
      LogisticsSelection(customerId, otherId),
    ];
    final input = CheckoutInput(
      CheckoutIntent.cart([customerId]),
      customerId,
      [],
      logisticsSelections: draft,
    );
    draft.clear();
    expect(input.logisticsSelections, hasLength(2));
    expect(input.toJson()['logistics_selections'], [
      {'shop_id': customerId, 'logistics_organization_id': otherId},
      {'shop_id': alpha.toLowerCase(), 'logistics_organization_id': otherId},
    ]);
    expect(
      input.toJson(discovery: true).containsKey('logistics_selections'),
      false,
    );
    final pending = PendingPlacement(
      key: customerId,
      payload: input.toJson(quoteId: otherId),
      customerId: customerId,
      sessionGeneration: 1,
      cartMode: true,
    );
    expect(
      () => (pending.payload['logistics_selections'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(
      () => (pending.payload['logistics_selections'][0] as Map)['shop_id'] =
          otherId,
      throwsUnsupportedError,
    );
    expect(
      () => CheckoutInput(
        CheckoutIntent.cart([customerId]),
        customerId,
        [],
        logisticsSelections: [
          LogisticsSelection(alpha, otherId),
          LogisticsSelection(alpha.toLowerCase(), otherId),
        ],
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => CheckoutInput(
        CheckoutIntent.cart([customerId]),
        customerId,
        [],
        logisticsSelections: List.generate(
          51,
          (i) => LogisticsSelection(
            '${i.toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
            otherId,
          ),
        ),
      ),
      throwsA(isA<ApiFailure>()),
    );
  });
}
