import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';

void main() {
  late CommerceHarness h;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
    final c = h.commerce.checkout;
    c.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
    await c.loadAddresses();
    c.chooseProvider(customerId, otherId);
    await c.getQuote();
    expect(c.canPlace, isTrue);
  });
  tearDown(() => h.dispose());

  Future<void> loseResponse() async {
    h.reply = (r) {
      if (r.uri.path.endsWith('/place')) {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return h.defaultReply(r);
    };
    expect(await h.commerce.checkout.place(), isNull);
    expect(h.commerce.checkout.pending, isNotNull);
  }

  for (final status in [403, 404, 409, 422, 429, 503]) {
    test(
      'timeout then HTTP $status keeps original placement unresolved',
      () async {
        final c = h.commerce.checkout;
        await loseResponse();
        final frozen = c.pending;
        h.reply = (r) => r.uri.path.endsWith('/place')
            ? jsonReply({}, status: status)
            : h.defaultReply(r);
        expect(await c.retryPending(), isNull);
        expect(c.pending, same(frozen));
        expect(c.result, isNull);
        if (status == 403 || status == 404) {
          expect(c.addresses, isEmpty);
          expect(c.addressId, isNull);
          expect(c.quote, isNull);
          expect(c.shipping.options, isNull);
        }
        expect(c.canPlace, isFalse);
        expect(c.canQuote, isFalse);
        expect(c.begin(CheckoutIntent.cart([customerId])), isFalse);
        final count = h.adapter.requests.length;
        await c.place();
        await c.getQuote();
        expect(h.adapter.requests, hasLength(count));
        h.reply = null;
        expect(await c.retryPending(), isNotNull);
        final writes = h.adapter.requests.where(
          (r) => r.uri.path.endsWith('/place'),
        );
        expect(writes, hasLength(3));
        for (final write in writes) {
          expect(write.headers['Idempotency-Key'], frozen!.key);
          expect(write.data, frozen.payload);
        }
        expect(h.keys, 1);
      },
    );
  }

  test(
    'throttled reconciliation waits and never automatically replays',
    () async {
      final c = h.commerce.checkout;
      await loseResponse();
      final frozen = c.pending;
      h.reply = (r) => r.uri.path.endsWith('/place')
          ? jsonReply(
              {},
              status: 429,
              headers: {
                'retry-after': ['1'],
              },
            )
          : h.defaultReply(r);
      await c.retryPending();
      expect(c.coolingDown, isTrue);
      expect(c.pending, same(frozen));
      final count = h.adapter.requests.length;
      await c.retryPending();
      expect(h.adapter.requests, hasLength(count));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(c.coolingDown, isFalse);
      expect(h.adapter.requests, hasLength(count));
      h.reply = null;
      expect(await c.retryPending(), isNotNull);
      expect(h.keys, 1);
    },
  );

  for (final kind in [
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
    DioExceptionType.cancel,
  ]) {
    test(
      'repeated $kind and malformed success never confirm placement',
      () async {
        final c = h.commerce.checkout;
        await loseResponse();
        final frozen = c.pending;
        h.reply = (r) {
          if (r.uri.path.endsWith('/place')) {
            throw DioException(requestOptions: r, type: kind);
          }
          return h.defaultReply(r);
        };
        await c.retryPending();
        expect(c.pending, same(frozen));
        h.reply = (r) => r.uri.path.endsWith('/place')
            ? jsonReply({
                'data': {'id': customerId, 'orders': []},
              })
            : h.defaultReply(r);
        await c.retryPending();
        expect(c.pending, same(frozen));
        expect(c.result, isNull);
        expect(h.keys, 1);
      },
    );
  }

  for (final code in ['QUOTE_EXPIRED', 'QUOTE_INPUT_CHANGED', 'QUOTE_STALE']) {
    test('$code after uncertainty requires fresh reviewed placement', () async {
      final c = h.commerce.checkout;
      final intent = c.intent;
      final address = c.addressId;
      final provider = c.shipping.selections.single;
      await loseResponse();
      h.reply = (r) => r.uri.path.endsWith('/place')
          ? jsonReply({'code': code}, status: 409)
          : h.defaultReply(r);
      await c.retryPending();
      expect(c.pending, isNull);
      expect(c.quote, isNull);
      expect(c.canPlace, isFalse);
      expect(c.intent, same(intent));
      expect(c.addressId, address);
      expect(c.shipping.selections.single, same(provider));
      h.reply = null;
      await c.getQuote();
      expect(c.canPlace, isTrue);
      expect(h.keys, 1);
      expect(await c.place(), isNotNull);
      expect(h.keys, 2);
    });
  }

  for (final code in ['QUOTE_ALREADY_PLACED', 'IDEMPOTENCY_KEY_REUSED']) {
    test('$code after timeout blocks all placement actions', () async {
      final c = h.commerce.checkout;
      await loseResponse();
      final frozen = c.pending;
      h.reply = (r) => r.uri.path.endsWith('/place')
          ? jsonReply({'code': code}, status: 409)
          : h.defaultReply(r);
      await c.retryPending();
      expect(c.pending, same(frozen));
      expect(c.collision, isTrue);
      final count = h.adapter.requests.length;
      await c.retryPending();
      await c.place();
      await c.getQuote();
      expect(h.adapter.requests, hasLength(count));
      expect(c.result, isNull);
    });
  }

  test(
    'initial validation rejection preserves selections and requires review',
    () async {
      final c = h.commerce.checkout;
      final intent = c.intent;
      final address = c.addressId;
      final selections = c.shipping.selections;
      h.reply = (r) => r.uri.path.endsWith('/place')
          ? jsonReply({
              'errors': {
                'address_id': ['Invalid'],
              },
            }, status: 422)
          : h.defaultReply(r);
      await c.place();
      expect(c.pending, isNull);
      expect(c.quote, isNull);
      expect(c.canPlace, isFalse);
      expect(c.intent, same(intent));
      expect(c.addressId, address);
      expect(c.shipping.selections, same(selections));
      expect(c.fieldErrors, {'address_id': 'Check this field.'});
    },
  );

  test(
    'consent interruption retains uncertainty through a later rejection',
    () async {
      final c = h.commerce.checkout;
      final gate = Completer<ResponseBody>();
      h.reply = (r) =>
          r.uri.path.endsWith('/place') ? gate.future : h.defaultReply(r);
      final flight = c.place();
      final frozen = c.pending;
      h.policies.consent = ConsentStatus.parse(consentJson(required: true));
      await h.session.refreshConsent();
      gate.complete(jsonReply(fixture('checkout-order', 'op-030')));
      expect(await flight, isNull);
      h.policies.consent = ConsentStatus.parse(consentJson());
      await h.session.refreshConsent();
      h.reply = (r) => r.uri.path.endsWith('/place')
          ? jsonReply({}, status: 429)
          : h.defaultReply(r);
      await c.retryPending();
      expect(c.pending, same(frozen));
      expect(c.result, isNull);
      h.reply = null;
      expect(await c.retryPending(), isNotNull);
      expect(h.keys, 1);
    },
  );

  for (final rejected in [false, true]) {
    test(
      'temporary consent check hides placement response (rejected: $rejected)',
      () async {
        final c = h.commerce.checkout;
        final placementGate = Completer<ResponseBody>();
        final consentGate = Completer<ConsentStatus>();
        h.reply = (r) => r.uri.path.endsWith('/place')
            ? placementGate.future
            : h.defaultReply(r);
        final flight = c.place();
        final frozen = c.pending;
        h.policies.onStatus = () => consentGate.future;
        final refresh = h.session.refreshConsent();
        expect(h.session.active, isFalse);
        placementGate.complete(
          rejected
              ? jsonReply({}, status: 422)
              : jsonReply(fixture('checkout-order', 'op-030')),
        );
        expect(await flight, isNull);
        expect(c.result, isNull);
        consentGate.complete(h.policies.consent);
        await refresh;
        expect(h.session.active, isTrue);
        h.reply = (r) => r.uri.path.endsWith('/place')
            ? jsonReply({}, status: 429)
            : h.defaultReply(r);
        await c.retryPending();
        expect(c.pending, same(frozen));
        h.reply = null;
        expect(await c.retryPending(), isNotNull);
        expect(h.keys, 1);
      },
    );
  }

  test(
    'quote failure retains voucher and provider intent without stale placement',
    () async {
      final c = h.commerce.checkout;
      final inputIntent = c.intent;
      final address = c.addressId;
      final selections = c.shipping.selections;
      c.vouchers = [VoucherSelection(customerId, customerId)];
      h.reply = (r) => r.uri.path.endsWith('/quote')
          ? jsonReply({
              'errors': {
                'vouchers.0.voucher_id': ['Expired'],
              },
            }, status: 422)
          : h.defaultReply(r);
      await c.getQuote();
      expect(c.quote, isNull);
      expect(c.canPlace, isFalse);
      expect(c.intent, same(inputIntent));
      expect(c.addressId, address);
      expect(c.shipping.selections, same(selections));
      expect(c.vouchers.single.voucherId, customerId);
      expect(c.fieldErrors, {'vouchers.0.voucher_id': 'Check this field.'});
      c.removeVoucher(customerId);
      h.reply = null;
      await h.settleShipping();
      await c.getQuote();
      expect(c.canPlace, isTrue);
      expect(h.keys, 0);
      expect(c.result, isNull);
    },
  );

  test(
    'double placement and retry taps send only one request at a time',
    () async {
      final c = h.commerce.checkout;
      final gate = Completer<ResponseBody>();
      h.reply = (r) =>
          r.uri.path.endsWith('/place') ? gate.future : h.defaultReply(r);
      final flight = c.place();
      expect(await c.place(), isNull);
      expect(await c.retryPending(), isNull);
      gate.complete(jsonReply(fixture('checkout-order', 'op-030')));
      expect(await flight, isNotNull);
      expect(
        h.adapter.requests.where((r) => r.uri.path.endsWith('/place')),
        hasLength(1),
      );
      expect(h.keys, 1);
    },
  );
}
