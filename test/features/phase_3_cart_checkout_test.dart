import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/voucher_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_controller.dart';

import '../support/fakes.dart';
import '../support/commerce_harness.dart';

void main() {
  late CommerceHarness h;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());
  Future<void> quote({bool cart = false}) async {
    h.commerce.checkout.begin(
      cart
          ? CheckoutIntent.cart([customerId])
          : CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)),
    );
    await h.commerce.checkout.loadAddresses();
    await h.commerce.checkout.getQuote();
    expect(h.commerce.checkout.error, isNull);
    expect(h.commerce.checkout.canQuote, true);
    expect(h.commerce.checkout.quote, isNotNull);
    expect(h.commerce.checkout.canPlace, true);
  }

  test('Cart replaces full projections and drops selected merged or unavailable IDs', () async {
    final c = h.commerce.cart;
    c.select(customerId, true);
    expect(c.selection, {customerId});
    final updated = clone(h.cartJson);
    updated['data']['items'][0]['id'] = otherId;
    updated['data']['items'][0]['variant'] = {'id': otherId, 'sku': null};
    h.reply = (request) => request.method == 'PATCH'
        ? jsonReply(updated)
        : h.defaultReply(request);
    expect(
      await c.update(customerId, variantId: otherId, changeVariant: true),
      true,
    );
    expect(c.cart!.items.single.id, otherId);
    expect(c.selection, isEmpty);
    c.select(otherId, true);
    h.cartJson = updated;
    h.cartJson['data']['items'][0]['availability']['reason'] =
        'insufficient_stock';
    h.cartJson['data']['items'][0]['availability']['isAvailable'] = false;
    await c.load();
    expect(c.selection, isEmpty);
    expect(c.cart!.items.single.availabilityLabel, contains('Reduce'));
    c.select(otherId, true);
    expect(c.selection, isEmpty);
    expect(c.badge, 1);
  });
  test('bulk Cart selection fills a partial eligible set, clears a full set, and reconciles server changes', () async {
    final c = h.commerce.cart;
    const thirdId = '00000003-1111-4111-8111-111111111111';
    final multi = clone(h.cartJson);
    final base = clone(multi['data']['items'][0] as Map<String, dynamic>);
    final second = clone(base)
      ..['id'] = otherId
      ..['product'] = {
        ...(base['product'] as Map<String, dynamic>),
        'id': otherId,
      };
    final unavailable = clone(base)
      ..['id'] = thirdId
      ..['product'] = {
        ...(base['product'] as Map<String, dynamic>),
        'id': thirdId,
      }
      ..['availability'] = {
        'isAvailable': false,
        'reason': 'out_of_stock',
        'availableQuantity': 0,
      };
    multi['data']['items'] = [base, second, unavailable];
    multi['data']['distinctItemCount'] = 3;
    multi['data']['itemCount'] = 3;
    h.cartJson = multi;
    await c.load();
    expect(c.selectAllValue, false);
    expect(
      h.commerce.checkout.begin(CheckoutIntent.cart([customerId])),
      isTrue,
    );
    var changes = 0;
    final notifyCheckout = c.onChanged;
    c.onChanged = () {
      changes++;
      notifyCheckout?.call();
    };

    c.select(customerId, true);
    expect(c.selectAllValue, isNull);
    expect(h.commerce.checkout.cartChanged, isTrue);
    c.toggleSelectAllEligible();
    expect(c.selection, {customerId, otherId});
    expect(c.selectAllValue, true);
    c.toggleSelectAllEligible();
    expect(c.selection, isEmpty);
    expect(c.selectAllValue, false);
    expect(changes, 3);
    c.select(thirdId, true);
    expect(c.selection, isEmpty);

    final changed = clone(multi);
    changed['data']['items'] = [second, unavailable];
    changed['data']['distinctItemCount'] = 2;
    changed['data']['itemCount'] = 2;
    h.cartJson = changed;
    c.select(otherId, true);
    expect(c.selection, {otherId});
    await c.load();
    expect(c.selection, {otherId});
    expect(c.selectAllValue, true);
  });
  test('Cart additive timeout is never repeated and refetch is deliberate reconciliation', () async {
    final c = h.commerce.cart;
    var additions = 0;
    h.reply = (request) {
      if (request.method == 'POST') {
        additions++;
        h.cartJson['data']['itemCount'] = 2;
        h.cartJson['data']['items'][0]['quantity'] = 2;
        h.cartJson['data']['items'][0]['availability']['availableQuantity'] = 3;
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return h.defaultReply(request);
    };
    expect(await c.add(customerId, null, 1), false);
    expect(additions, 1);
    expect(c.cart!.items.single.quantity, 2);
    expect(c.uncertain, false);
    expect(c.error, contains('not repeated'));
    expect(c.canEdit, true);
  });
  test('Cart blocks writes until failed uncertainty reread succeeds; overlapping taps do not queue', () async {
    final c = h.commerce.cart;
    final delayed = Completer<ResponseBody>();
    h.reply = (r) =>
        r.method == 'POST' ? delayed.future : jsonReply({}, status: 503);
    final first = c.add(customerId, null, 1);
    expect(await c.add(customerId, null, 1), false);
    delayed.complete(jsonReply({}, status: 503));
    expect(await first, false);
    expect(c.uncertain, true);
    expect(await c.add(customerId, null, 1), false);
    h.reply = null;
    await c.load();
    expect(c.uncertain, false);
    expect(h.adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
  });
  test('Buy Now placement leaves Cart untouched and freezes exact reviewed payload/header', () async {
    await quote();
    final c = h.commerce.checkout;
    final before = h.adapter.requests
        .where((r) => r.uri.path.contains('/cart'))
        .length;
    final batch = await c.place();
    expect(batch, isNotNull);
    expect(c.pending, isNull);
    expect(
      h.adapter.requests.where((r) => r.uri.path.contains('/cart')).length,
      before,
    );
    final request = h.adapter.requests.last;
    expect(
      request.headers['Idempotency-Key'],
      '00000001-1111-4111-8111-111111111111',
    );
    expect(request.data, {
      'mode': 'buy_now',
      'buy_now': {'product_id': customerId, 'variant_id': null, 'quantity': 1},
      'address_id': customerId,
      'payment_method': 'cod',
      'vouchers': [],
      'quote_id': '00000008-1111-4111-8111-111111111111',
    });
    expect(await c.place(), isNull);
  });
  test('selected Cart placement refreshes authoritative Cart after confirmed Batch', () async {
    await quote(cart: true);
    h.reply = (r) {
      if (r.uri.path.endsWith('/place')) {
        h.cartJson['data']['items'] = [];
        h.cartJson['data']['itemCount'] = 0;
        h.cartJson['data']['distinctItemCount'] = 0;
      }
      return h.defaultReply(r);
    };
    expect(await h.commerce.checkout.place(), isNotNull);
    expect(h.commerce.cart.cart!.items, isEmpty);
    expect(h.commerce.cart.badge, 0);
  });
  test('lost placement response retains key quote and payload and blocks competing navigation intents', () async {
    await quote();
    final c = h.commerce.checkout;
    var attempts = 0;
    h.reply = (r) {
      if (r.uri.path.endsWith('/place') && ++attempts == 1) {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionTimeout,
        );
      }
      return h.defaultReply(r);
    };
    expect(await c.place(), isNull);
    final pending = c.pending!;
    expect(c.begin(CheckoutIntent.cart([customerId])), false);
    expect(await h.commerce.cart.add(customerId, null, 1), false);
    c.chooseAddress(otherId);
    expect(identical(c.pending, pending), true);
    expect(await c.place(), isNull);
    expect(await c.retryPending(), isNotNull);
    final writes = h.adapter.requests
        .where((r) => r.uri.path.endsWith('/place'))
        .toList();
    expect(writes, hasLength(2));
    expect(
      writes[0].headers['Idempotency-Key'],
      writes[1].headers['Idempotency-Key'],
    );
    expect(writes[0].data, writes[1].data);
    expect(h.keys, 1);
  });
  test('malformed or partial placement success remains uncertain; same key is retained', () async {
    await quote();
    h.reply = (r) => r.uri.path.endsWith('/place')
        ? jsonReply({
            'data': {'id': customerId, 'orders': []},
          })
        : h.defaultReply(r);
    expect(await h.commerce.checkout.place(), isNull);
    expect(h.commerce.checkout.pending, isNotNull);
    expect(h.commerce.checkout.result, isNull);
    expect(h.commerce.checkout.canQuote, false);
  });
  test('expired changed stale quotes require reviewed refresh; key conflicts never make a fresh placement', () async {
    await quote();
    final c = h.commerce.checkout;
    h.now = h.now.add(const Duration(minutes: 16));
    expect(c.canPlace, false);
    expect(await c.place(), isNull);
    await c.getQuote();
    expect(c.canPlace, true);
    h.reply = (r) => r.uri.path.endsWith('/place')
        ? jsonReply({'code': 'QUOTE_STALE'}, status: 409)
        : h.defaultReply(r);
    await c.place();
    expect(c.pending, isNull);
    expect(c.quote, isNull);
    await c.getQuote();
    expect(c.canPlace, true);
    h.reply = (r) => r.uri.path.endsWith('/place')
        ? jsonReply({'code': 'QUOTE_ALREADY_PLACED'}, status: 409)
        : h.defaultReply(r);
    await c.place();
    expect(c.pending, isNotNull);
    expect(c.collision, true);
    expect(await c.retryPending(), isNull);
    expect(c.begin(CheckoutIntent.cart([customerId])), false);
  });
  test(
    'changed address or Cart invalidates review and rejects a late quote',
    () async {
      final c = h.commerce.checkout;
      await quote(cart: true);
      c.chooseAddress(customerId);
      expect(c.quote, isNull);
      final gate = Completer<ResponseBody>();
      h.reply = (r) =>
          r.uri.path.endsWith('/quote') ? gate.future : h.defaultReply(r);
      final flight = c.getQuote();
      await h.commerce.cart.load();
      gate.complete(
        jsonReply(
          h.quoteFor({
            'mode': 'cart',
            'cart_item_ids': [customerId],
            'address_id': customerId,
          }),
        ),
      );
      await flight;
      expect(c.quote, isNull);
      expect(c.cartChanged, true);
      expect(c.canPlace, false);
    },
  );
  test(
    'multiple Shop quote and Batch keep independent Order links and totals',
    () async {
      final c = h.commerce.checkout;
      h.reply = (r) {
        if (r.uri.path.endsWith('/quote')) {
          final q = h.quoteFor(r.data as Map<String, dynamic>);
          final group = clone(q['data']['groups'][0]);
          group['shop']['id'] = otherId;
          group['shop']['name'] = 'Second Shop';
          group['items'] = [group['items'][0]];
          group['items'][0]['cartItemId'] = otherId;
          q['data']['groups'][0]['items'] = [
            q['data']['groups'][0]['items'][0],
          ];
          q['data']['groups'].add(group);
          q['data']['summary']['orderCount'] = 2;
          return jsonReply(q);
        }
        if (r.uri.path.endsWith('/place')) {
          final b = fixture('checkout-order', 'op-030');
          final order = clone(b['data']['orders'][0]);
          order['id'] = otherId;
          order['shop']['id'] = otherId;
          b['data']['orders'].add(order);
          return jsonReply(b);
        }
        return h.defaultReply(r);
      };
      c.begin(CheckoutIntent.cart([customerId, otherId]));
      await c.loadAddresses();
      await c.getQuote();
      expect(c.quote!.groups, hasLength(2));
      expect((await c.place())!.orders.map((o) => o.id).toSet(), hasLength(2));
    },
  );
  test('voucher targeting is explicit and zero-saving selection uses the server result', () async {
    await quote();
    final c = h.commerce.checkout;
    final raw = {
      'id': otherId,
      'code': 'ZERO',
      'issuerType': 'app',
      'benefitType': 'discount',
      'valueType': 'fixed',
      'value': '0.00',
      'maximumDiscount': null,
      'minimumSpend': '0.00',
      'termsSummary': 'Synthetic terms',
      'validFrom': '2026-01-01T00:00:00Z',
      'validUntil': '2027-01-01T00:00:00Z',
      'paymentMethod': 'cod',
      'stackableWith': <String>[],
      'scope': {
        'productIds': <String>[],
        'categoryIds': <String>[],
        'excludedProductIds': <String>[],
        'excludedCategoryIds': <String>[],
      },
      'eligible': true,
      'reason': null,
      'saving': '0.00',
    };
    h.reply = (r) {
      if (!r.uri.path.endsWith('/quote')) return h.defaultReply(r);
      final q = h.quoteFor(r.data as Map<String, dynamic>);
      q['data']['groups'][0]['availableVouchers'] = [raw];
      if ((r.data['vouchers'] as List).isNotEmpty) {
        q['data']['groups'][0]['appliedVouchers'] = [
          {
            'id': otherId,
            'code': 'ZERO',
            'issuerType': 'app',
            'benefitType': 'discount',
            'qualifyingBasis': '100.00',
            'discountAmount': '0.00',
          },
        ];
      }
      return jsonReply(q);
    };
    await c.getQuote();
    final group = c.quote!.groups.single;
    c.chooseVoucher(group, const CheckoutVoucherCandidate(otherId), true);
    expect(c.quote, isNull);
    expect(c.vouchers.single.shopId, customerId);
    await c.getQuote();
    expect(c.canPlace, true);
    expect(c.quote!.groups.single.applied.single.discount.minorUnits, 0);
    final request = h.adapter.requests.last.data as Map;
    expect(request['vouchers'], [
      {'voucher_id': otherId, 'target_shop_id': customerId},
    ]);
    raw['eligible'] = false;
    raw['reason'] = 'expired';
    expect(CheckoutVoucher.parse(raw).selectable, false);
    raw['eligible'] = true;
    raw['issuerType'] = 'unknown';
    expect(CheckoutVoucher.parse(raw).selectable, false);
  });
  test('consent interruption preserves only unresolved same-identity record and never replays automatically', () async {
    await quote();
    final c = h.commerce.checkout;
    final gate = Completer<ResponseBody>();
    h.reply = (r) =>
        r.uri.path.endsWith('/place') ? gate.future : h.defaultReply(r);
    final flight = c.place();
    final key = c.pending!.key;
    h.policies.consent = ConsentStatus.parse(consentJson(required: true));
    await h.session.refreshConsent();
    expect(h.session.active, false);
    expect(c.pending!.key, key);
    expect(c.quote, isNull);
    expect(c.addresses, isEmpty);
    expect(c.intent, isNull);
    gate.complete(jsonReply(fixture('checkout-order', 'op-030')));
    expect(await flight, isNull);
    expect(c.result, isNull);
    final writes = h.adapter.requests
        .where((r) => r.uri.path.endsWith('/place'))
        .length;
    h.policies.consent = ConsentStatus.parse(consentJson());
    h.reply = null;
    await h.session.refreshConsent();
    await Future<void>.delayed(Duration.zero);
    expect(
      h.adapter.requests.where((r) => r.uri.path.endsWith('/place')).length,
      writes,
    );
    expect(await c.retryPending(), isNotNull);
    expect(h.keys, 1);
  });
  test(
    'logout and A to B switch clear frozen placement and reject late Batch',
    () async {
      await quote();
      final c = h.commerce.checkout;
      final gate = Completer<ResponseBody>();
      h.reply = (r) =>
          r.uri.path.endsWith('/place') ? gate.future : h.defaultReply(r);
      final flight = c.place();
      await h.session.signOut();
      expect(c.pending, isNull);
      expect(h.commerce.cart.cart, isNull);
      h.auth.onLogin = () async => LoginResult.parse({
        'message': 'OK',
        'customer': identityJson(id: otherId),
        'token': 'synthetic-b-token',
      });
      h.auth.identity = CustomerIdentity.parse(identityJson(id: otherId));
      await h.session.signIn('b@example.invalid', 'Synthetic123');
      gate.complete(jsonReply(fixture('checkout-order', 'op-030')));
      expect(await flight, isNull);
      expect(c.result, isNull);
      expect(c.pending, isNull);
      expect(await c.retryPending(), isNull);
    },
  );
  test('validation and throttling preserve intent and block repeated writes during cooldown', () async {
    final c = h.commerce.checkout;
    c.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
    await c.loadAddresses();
    h.reply = (r) => r.uri.path.endsWith('/quote')
        ? jsonReply({
            'errors': {
              'address_id': ['Invalid address'],
            },
          }, status: 422)
        : h.defaultReply(r);
    await c.getQuote();
    expect(c.fieldErrors, {'address_id': 'Check this field.'});
    expect(c.intent, isNotNull);
    expect(c.canPlace, false);
    h.reply = (r) => r.uri.path.endsWith('/quote')
        ? jsonReply(
            {},
            status: 429,
            headers: {
              'retry-after': ['60'],
            },
          )
        : h.defaultReply(r);
    await c.getQuote();
    expect(c.coolingDown, true);
    final count = h.adapter.requests.length;
    await c.getQuote();
    expect(h.adapter.requests.length, count);
    expect(c.pending, isNull);
  });
}
