import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_controller.dart';

import '../support/checkout_voucher_harness.dart';
import '../support/fakes.dart';

void main() {
  late CheckoutVoucherHarness h;
  setUp(() async {
    h = CheckoutVoucherHarness();
    await h.initialize();
    await h.begin();
    expect(h.checkout.canPlace, isTrue);
  });
  tearDown(() => h.dispose());

  List<Map<String, dynamic>> choices() =>
      h.checkout.vouchers.map((v) => v.toJson()).toList();
  Map<String, dynamic> choice(String id, String shop) => {
    'voucher_id': id,
    'target_shop_id': shop,
  };

  for (final benefit in [
    (first: appDiscountA, second: appDiscountB, opposite: appShippingA),
    (first: appShippingA, second: appShippingB, opposite: appDiscountA),
  ]) {
    test(
      'App same benefit replaces across Shops and preserves opposite $benefit',
      () async {
        await h.select(shopA, benefit.first);
        await h.select(shopA, benefit.opposite);
        await h.select(shopB, benefit.second);
        expect(choices(), [
          choice(benefit.opposite, shopA),
          choice(benefit.second, shopB),
        ]);
        expect(h.checkout.canPlace, isTrue);
        expect(h.keys, 0);
      },
    );
  }

  for (final pair in [
    (first: appDiscountA, second: shopDiscountA),
    (first: shopDiscountA, second: appDiscountA),
    (first: shopDiscountA, second: shopDiscountA2),
    (first: appShippingA, second: shopShippingA),
    (first: shopShippingA, second: appShippingA),
  ]) {
    test('same-Shop same-benefit replacement $pair', () async {
      await h.select(shopB, shopShippingB);
      await h.select(shopA, pair.first);
      await h.select(shopA, pair.second);
      expect(choices(), [
        choice(shopShippingB, shopB),
        choice(pair.second, shopA),
      ]);
    });
  }

  test(
    'App replacement removes global and target-Shop conflicts together',
    () async {
      await h.select(shopA, appDiscountA);
      await h.select(shopA, shopShippingA);
      await h.select(shopB, shopDiscountB);
      await h.select(shopB, appDiscountB);
      expect(choices(), [
        choice(shopShippingA, shopA),
        choice(appDiscountB, shopB),
      ]);
    },
  );

  test('same-benefit Shop vouchers in different Shops coexist with an App elsewhere', () async {
    await h.select(shopA, shopDiscountA);
    await h.select(shopB, shopDiscountB);
    expect(choices(), [
      choice(shopDiscountA, shopA),
      choice(shopDiscountB, shopB),
    ]);
    await h.select(shopB, appDiscountA);
    expect(choices(), [
      choice(shopDiscountA, shopA),
      choice(appDiscountA, shopB),
    ]);
    await h.select(shopA, shopDiscountA2);
    expect(choices(), [
      choice(appDiscountA, shopB),
      choice(shopDiscountA2, shopA),
    ]);
  });

  test('same App ID retargets explicitly; deselection only removes its exact target', () async {
    await h.select(shopA, appDiscountA);
    await h.select(shopA, appShippingA);
    await h.select(shopB, appDiscountA);
    final expected = [choice(appShippingA, shopA), choice(appDiscountA, shopB)];
    expect(choices(), expected);
    await h.select(shopA, appDiscountA, selected: false);
    expect(choices(), expected);
    await h.select(shopB, appDiscountA, selected: false);
    expect(choices(), [choice(appShippingA, shopA)]);
  });

  test(
    'applied metadata supports replacement when selected candidate is omitted',
    () async {
      await h.select(shopA, appDiscountA);
      h.omitAppliedCandidates = true;
      await h.review();
      expect(
        h.checkout.quote!.groups.first.candidates.any(
          (v) => v.id == appDiscountA,
        ),
        isFalse,
      );
      await h.select(shopB, appDiscountB);
      expect(choices(), [choice(appDiscountB, shopB)]);
    },
  );

  test('change invalidates review, retains replacements through failure and sends only explicit IDs', () async {
    await h.select(shopA, appDiscountA);
    final group = h.checkout.quote!.groups.last;
    h.checkout.chooseVoucher(
      group,
      const CheckoutVoucherCandidate(appDiscountB),
      true,
    );
    expect(h.checkout.quote, isNull);
    expect(h.checkout.canPlace, isFalse);
    expect(h.checkout.error, contains('Get a new quote'));
    await h.settleShipping();
    h.reply = (r) => r.uri.path.endsWith('/quote')
        ? jsonReply({'message': 'Try later'}, status: 503)
        : h.defaultReply(r);
    await h.review();
    expect(h.checkout.quote, isNull);
    expect(choices(), [choice(appDiscountB, shopB)]);
    h.reply = null;
    await h.review();
    await h.review();
    final request = h.adapter.requests.last;
    expect(request.data['vouchers'], [choice(appDiscountB, shopB)]);
    expect(request.headers.containsKey('Idempotency-Key'), isFalse);
    expect(h.checkout.canPlace, isTrue);
    expect(h.keys, 0);
  });

  test(
    'old quote group, ineligible and unknown candidate cannot change choices',
    () async {
      final old = h.checkout.quote!.groups.first;
      h.candidates[shopA]!.firstWhere(
        (v) => v['id'] == appDiscountA,
      )['eligible'] = false;
      await h.review();
      final current = h.checkout.quote!.groups.first;
      final count = h.adapter.requests.length;
      h.checkout.chooseVoucher(
        old,
        const CheckoutVoucherCandidate(appShippingA),
        true,
      );
      h.checkout.chooseVoucher(
        current,
        const CheckoutVoucherCandidate(appDiscountA),
        true,
      );
      h.checkout.chooseVoucher(
        current,
        const CheckoutVoucherCandidate(otherId),
        true,
      );
      expect(choices(), isEmpty);
      expect(h.adapter.requests, hasLength(count));
      expect(h.checkout.canPlace, isTrue);
    },
  );

  test('voucher-bearing uncertain placement freezes replacement targets and exact retry', () async {
    await h.select(shopA, appDiscountA);
    await h.select(shopB, appDiscountB);
    await h.select(shopB, shopShippingB);
    final group = h.checkout.quote!.groups.first;
    final gate = Completer<ResponseBody>();
    h.reply = (r) =>
        r.uri.path.endsWith('/place') ? gate.future : h.defaultReply(r);
    final flight = h.checkout.place();
    final pending = h.checkout.pending!;
    final payload = jsonEncode(pending.payload);
    while (!h.adapter.requests.any((r) => r.uri.path.endsWith('/place'))) {
      await Future<void>.delayed(Duration.zero);
    }
    h.checkout.chooseVoucher(
      group,
      const CheckoutVoucherCandidate(appDiscountA),
      true,
    );
    expect(h.checkout.pending, same(pending));
    gate.completeError(
      DioException(
        requestOptions: h.adapter.requests.last,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    expect(await flight, isNull);
    h.checkout.chooseVoucher(
      group,
      const CheckoutVoucherCandidate(appDiscountA),
      true,
    );
    h.checkout.removeVoucher(appDiscountB);
    await h.checkout.getQuote();
    expect(jsonEncode(h.checkout.pending!.payload), payload);
    expect(h.checkout.pending!.payload['vouchers'], [
      choice(appDiscountB, shopB),
      choice(shopShippingB, shopB),
    ]);
    h.reply = null;
    expect(await h.checkout.retryPending(), isNotNull);
    final writes = h.adapter.requests
        .where((r) => r.uri.path.endsWith('/place'))
        .toList();
    expect(writes, hasLength(2));
    expect(writes[0].headers['Idempotency-Key'], pending.key);
    expect(writes[1].headers['Idempotency-Key'], pending.key);
    expect(jsonEncode(writes[0].data), payload);
    expect(jsonEncode(writes[1].data), payload);
    expect(h.keys, 1);
  });

  test(
    'logout clears selections and obsolete groups cannot restore them',
    () async {
      await h.select(shopA, appDiscountA);
      final group = h.checkout.quote!.groups.first;
      await h.session.signOut();
      h.checkout.chooseVoucher(
        group,
        const CheckoutVoucherCandidate(appDiscountB),
        true,
      );
      expect(h.checkout.vouchers, isEmpty);
      expect(h.checkout.quote, isNull);
      expect(h.checkout.pending, isNull);
    },
  );
}
