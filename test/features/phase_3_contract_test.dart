import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/commerce/commerce_value.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/cart/data/cart_models.dart';
import 'package:aisley_mobile_buyer/features/cart/data/cart_repository.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/batch_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/quote_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_models.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_repository.dart';
import 'package:aisley_mobile_buyer/features/orders/data/tracking_models.dart';

import '../support/fakes.dart';
import '../support/commerce_harness.dart';

void main() {
  test('authoritative money parses exact cents on native and web safe integer bounds', () {
    expect(Money.parse('0.01').minorUnits, 1);
    expect(Money.parse('90071992547409.91').minorUnits, 9007199254740991);
    expect(Money.parse('123456.78').display(), 'PHP 123456.78');
    for (final value in [
      '-1.00',
      '1',
      '1.234',
      '1e2',
      'NaN',
      '90071992547409.92',
      100,
      null,
    ]) {
      expect(() => Money.parse(value), throwsA(isA<ApiFailure>()));
    }
    final ids = List.generate(100, (_) => secureUuid());
    expect(ids.toSet(), hasLength(100));
    expect(
      ids.every(
        (id) => RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
      ),
      true,
    );
  });
  test('all commerce fixtures preserve wire casing nullable snapshots and empty PHP location', () {
    expect(
      BuyerCart.parse(fixture('view-cart', 'op-025')['data']).itemCount,
      1,
    );
    expect(
      CheckoutQuote.parse(fixture('checkout-order', 'op-029')['data'])
          .summary
          .payable
          .minorUnits,
      20000,
    );
    expect(
      CheckoutBatch.parse(fixture('checkout-order', 'op-030')['data'])
          .orders
          .single
          .items
          .single
          .productId,
      isNull,
    );
    final order = BuyerOrder.parse(fixture('order-status', 'op-033')['data']);
    expect(order.canCorrect, true);
    expect(order.address.version, 1);
    expect(order.timeline.single.hub, isNull);
    expect(order.delivery, isNull);
    expect(order.mapAvailable, false);
    expect(
      OrdersPage.parse(fixture('order-status', 'op-032')).selected,
      isNull,
    );
    expect(
      OrderPage.parse(
        fixture('order-status', 'op-034'),
        TrackingEvent.parse,
      ).items.single.city,
      isNull,
    );
  });
  test('required nested fields, counts, timestamps and money fail closed', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (v) => v.remove('items'),
      (v) => v['itemCount'] = 2,
      (v) => v['items'][0]['quantity'] = 1.5,
      (v) => v['items'][0]['availability'].remove('reason'),
    ]) {
      final value =
          fixture('view-cart', 'op-025')['data'] as Map<String, dynamic>;
      mutate(value);
      expect(() => BuyerCart.parse(value), throwsA(isA<ApiFailure>()));
    }
    final quote =
        fixture('checkout-order', 'op-029')['data'] as Map<String, dynamic>;
    quote['groups'][0]['shippingQuote']['serviceable'] = false;
    expect(() => CheckoutQuote.parse(quote), throwsA(isA<ApiFailure>()));
    final batch =
        fixture('checkout-order', 'op-030')['data'] as Map<String, dynamic>;
    batch['orders'] = [];
    expect(() => CheckoutBatch.parse(batch), throwsA(isA<ApiFailure>()));
    final event =
        fixture('order-status', 'op-034')['data'][0] as Map<String, dynamic>;
    event['location'] = ['unsupported'];
    expect(() => TrackingEvent.parse(event), throwsA(isA<ApiFailure>()));
    event['location'] = {'hub': 'Hub', 'city': 'City'};
    expect(TrackingEvent.parse(event).hub, 'Hub');
    event['occurredAt'] = '2026-10-03T12:00:00';
    expect(() => TrackingEvent.parse(event), throwsA(isA<ApiFailure>()));
  });
  test('Cart sends exact additive absolute variant and removal requests without replay headers', () async {
    final h = CommerceHarness();
    await h.initialize();
    addTearDown(h.dispose);
    final repo = CartRepository(h.api), lease = h.session.verifiedLease!;
    await repo.add(lease, customerId, null, 2);
    await repo.update(
      lease,
      customerId,
      quantity: 3,
      variantId: otherId,
      changeVariant: true,
    );
    await repo.update(lease, customerId, variantId: null, changeVariant: true);
    await repo.remove(lease, customerId);
    final mutations = h.adapter.requests
        .where((r) => r.method != 'GET')
        .toList();
    expect(mutations.map((r) => r.method), [
      'POST',
      'PATCH',
      'PATCH',
      'DELETE',
    ]);
    expect(mutations.first.data, {
      'product_id': customerId,
      'variant_id': null,
      'quantity': 2,
    });
    expect(mutations[1].data, {'quantity': 3, 'variant_id': otherId});
    expect(mutations[2].data, {'variant_id': null});
    expect(mutations.last.data, isNull);
    expect(
      mutations.every((r) => !r.headers.containsKey('Idempotency-Key')),
      true,
    );
    expect(
      () => repo.add(lease, customerId, null, 0),
      throwsA(isA<ApiFailure>()),
    );
  });
  test(
    'intent excludes competing modes prices provider owner and mutation state',
    () {
      final input = CheckoutInput(
        CheckoutIntent.buyNow(BuyNowItem(customerId, null, 2)),
        otherId,
        [VoucherSelection(customerId, otherId)],
      );
      expect(input.toJson(quoteId: customerId), {
        'mode': 'buy_now',
        'buy_now': {
          'product_id': customerId,
          'variant_id': null,
          'quantity': 2,
        },
        'address_id': otherId,
        'payment_method': 'cod',
        'vouchers': [
          {'voucher_id': customerId, 'target_shop_id': otherId},
        ],
        'quote_id': customerId,
      });
      expect(
        CheckoutInput(
          CheckoutIntent.cart([customerId]),
          otherId,
          [],
        ).toJson().containsKey('buy_now'),
        false,
      );
      expect(
        () => CheckoutIntent.cart([customerId, customerId]),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () => CheckoutInput(CheckoutIntent.cart([customerId]), otherId, [
          VoucherSelection(customerId, otherId),
          VoucherSelection(customerId, customerId),
        ]),
        throwsA(isA<ApiFailure>()),
      );
      expect(() => input.toJson()['vouchers'].add({}), throwsUnsupportedError);
    },
  );
  test(
    'idempotency header validates UUID scope and method before transport',
    () async {
      final h = CommerceHarness();
      await h.initialize();
      addTearDown(h.dispose);
      final count = h.adapter.requests.length;
      for (final key in ['invalid', '$customerId\r\nX-Injected: yes']) {
        await expectLater(
          h.api.request(
            'POST',
            'customer/checkout/place',
            lease: h.session.verifiedLease,
            idempotencyKey: key,
          ),
          throwsA(isA<ApiFailure>()),
        );
      }
      await expectLater(
        h.api.request(
          'GET',
          'customer/orders',
          lease: h.session.verifiedLease,
          idempotencyKey: customerId,
        ),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        h.api.request(
          'POST',
          'customer/checkout/place',
          idempotencyKey: customerId,
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(h.adapter.requests.length, count);
    },
  );
  test('Orders filter and pagination send exact scalar parameters and reconstruct trusted paths', () async {
    final h = CommerceHarness();
    await h.initialize();
    addTearDown(h.dispose);
    await h.commerce.orders.list(
      h.session.verifiedLease!,
      group: 'to_prepare',
      page: 2,
    );
    await h.commerce.orders.tracking(h.session.verifiedLease!, customerId, 3);
    final requests = h.adapter.requests.skip(1).toList();
    expect(requests[0].uri.queryParameters, {
      'group': 'to_prepare',
      'page': '2',
      'per_page': '15',
    });
    expect(requests[1].uri.queryParameters, {'page': '3', 'per_page': '25'});
    await expectLater(
      h.commerce.orders.list(h.session.verifiedLease!, group: 'all'),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      h.commerce.orders.tracking(h.session.verifiedLease!, customerId, 10001),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('pending placement deeply freezes caller payload', () {
    final original = <String, dynamic>{
      'buy_now': <String, dynamic>{'quantity': 1},
      'vouchers': <Object?>[],
    };
    final pending = PendingPlacement(
      key: customerId,
      payload: original,
      customerId: customerId,
      sessionGeneration: 1,
      cartMode: false,
    );
    original['buy_now']['quantity'] = 9;
    expect(pending.payload['buy_now']['quantity'], 1);
    expect(
      () => pending.payload['buy_now']['quantity'] = 2,
      throwsUnsupportedError,
    );
    expect(() => pending.payload['vouchers'].add({}), throwsUnsupportedError);
  });
}
