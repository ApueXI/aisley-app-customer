import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/vouchers/data/customer_voucher.dart';
import 'package:aisley_mobile_buyer/features/vouchers/data/voucher_repository.dart';
import 'package:aisley_mobile_buyer/features/vouchers/presentation/voucher_collection_controller.dart';
import 'package:aisley_mobile_buyer/features/vouchers/presentation/voucher_list_controller.dart';
import 'package:aisley_mobile_buyer/features/vouchers/presentation/voucher_detail_controller.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';
import '../support/voucher_fixtures.dart';

void main() {
  late CommerceHarness h;
  late VoucherRepository repo;
  late VoucherCollectionController claims;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
    repo = VoucherRepository(h.api);
    claims = VoucherCollectionController(h.session, repo);
  });
  tearDown(() {
    claims.dispose();
    repo.dispose();
    h.dispose();
  });
  CustomerVoucher row() => CustomerVoucher.parse(voucherJson(), private: true);
  test(
    'pending prevents duplicate taps and original collection survives a retry',
    () async {
      final delayed = Completer<ResponseBody>();
      h.reply = (_) => delayed.future;
      final first = claims.collect(row());
      await Future<void>.delayed(Duration.zero);
      expect(claims.pending(otherId), true);
      await claims.collect(row());

      delayed.complete(jsonReply({'data': voucherJson(collected: true)}));
      await first;
      expect(
        h.adapter.requests.where((r) => r.uri.path.endsWith('/claim')),
        hasLength(1),
      );
      expect(claims.status(otherId)!.collected, true);
      expect(claims.pending(otherId), false);
    },
  );
  test(
    'lost response retries same endpoint with no new key or automatic mutation',
    () async {
      h.reply = (_) => jsonReply({'error': 'lost'}, status: 503);
      await claims.collect(row());
      expect(claims.uncertain(otherId), true);
      final first = h.adapter.requests.last;
      h.reply = (_) => jsonReply({'data': voucherJson(collected: true)});
      await claims.collect(row());
      final retry = h.adapter.requests.last;
      expect(retry.uri, first.uri);
      expect(retry.data, first.data);
      expect(retry.headers.containsKey('Idempotency-Key'), false);
      expect(claims.uncertain(otherId), false);
      expect(claims.status(otherId)!.collectedAt, DateTime.utc(2026, 10, 11));
    },
  );
  for (final code in [
    'VOUCHER_INACTIVE',
    'VOUCHER_EXPIRED',
    'VOUCHER_NOT_STARTED',
    'VOUCHER_EXHAUSTED',
    'VOUCHER_CUSTOMER_LIMIT',
    'VOUCHER_CUSTOMER_INELIGIBLE',
    'VOUCHER_PAYMENT_INELIGIBLE',
    'VOUCHER_TERMS_INVALID',
  ]) {
    test('409 $code has honest feedback and no success', () async {
      h.reply = (_) => jsonReply({'code': code}, status: 409);
      await claims.collect(row());
      expect(claims.status(otherId), isNull);
      expect(claims.errorFor(otherId), voucherReason(code));
      expect(claims.uncertain(otherId), false);
    });
  }
  test('429 cooldown blocks collection and 422 preserves safe retry', () async {
    h.reply = (_) => jsonReply(
      {},
      status: 429,
      headers: {
        'retry-after': ['30'],
      },
    );
    await claims.collect(row());
    expect(claims.coolingDown, true);
    final before = h.adapter.requests.length;
    await claims.collect(row());
    expect(h.adapter.requests.length, before);
    claims.clearCooldown();
    h.reply = (_) => jsonReply({
      'errors': {
        'voucher': ['bad'],
      },
    }, status: 422);
    await claims.collect(row());
    expect(claims.fieldErrors.containsKey('voucher'), true);
  });
  for (final denial in [
    (401, 'UNAUTHENTICATED'),
    (403, 'FORBIDDEN_ROLE'),
    (403, 'POLICY_CONSENT_REQUIRED'),
  ]) {
    test(
      'collection ${denial.$2} clears private state and never automatically retries',
      () async {
        h.policies.consent = ConsentStatus.parse(consentJson(required: true));
        h.reply = (_) => jsonReply({'code': denial.$2}, status: denial.$1);
        await claims.collect(row());
        await Future<void>.delayed(Duration.zero);
        expect(h.session.active, false);
        expect(claims.status(otherId), isNull);
        expect(claims.pending(otherId), false);
        expect(claims.uncertain(otherId), false);
        expect(
          h.adapter.requests.where((r) => r.uri.path.endsWith('/claim')),
          hasLength(1),
        );
      },
    );
  }
  test(
    'late pre-collection status cannot overwrite confirmed ownership',
    () async {
      final delayed = Completer<ResponseBody>();
      h.reply = (r) => r.uri.path.endsWith('voucher-statuses')
          ? delayed.future
          : jsonReply({'data': voucherJson(collected: true)});
      final read = claims.refresh([otherId]);
      await Future<void>.delayed(Duration.zero);
      await claims.collect(row());
      delayed.complete(
        jsonReply({
          'items': [voucherJson()],
        }),
      );
      await read;
      expect(claims.status(otherId)!.collected, true);
    },
  );
  test(
    'logout clears personal status/pending and ignores delayed collection',
    () async {
      final delayed = Completer<ResponseBody>();
      h.reply = (_) => delayed.future;
      final write = claims.collect(row());
      await Future<void>.delayed(Duration.zero);
      await h.session.signOut();
      delayed.complete(jsonReply({'data': voucherJson(collected: true)}));
      await write;
      expect(claims.status(otherId), isNull);
      expect(claims.pending(otherId), false);
      expect(claims.errorFor(otherId), isNull);
    },
  );
  test(
    'resource denial clears uncertain retry; automatic offers send no claim',
    () async {
      h.reply = (_) => jsonReply({}, status: 404);
      await claims.collect(row());
      expect(claims.uncertain(otherId), false);
      final before = h.adapter.requests.length;
      await claims.collect(
        CustomerVoucher.parse(
          voucherJson(issuer: 'app', distribution: 'automatic'),
          private: true,
        ),
      );
      expect(h.adapter.requests.length, before);
    },
  );
  test('wallet tabs use authoritative status and retain failed page with exact Retry', () async {
    final list = VoucherListController(h.session, repo, claims, wallet: true);
    addTearDown(list.dispose);
    h.reply = (r) => jsonReply(
      voucherPage(
        [
          voucherJson(
            collected: true,
            status: r.uri.queryParameters['status']!,
          ),
        ],
        page: int.parse(r.uri.queryParameters['page']!),
        lastPage: 2,
      ),
    );
    await list.load();
    await list.filters(status: 'history');
    expect(list.result!.items.single.walletStatus, 'history');
    h.reply = (_) => jsonReply({}, status: 503);
    await list.setPage(2);
    expect(list.result!.pagination.currentPage, 1);
    expect(list.page, 2);
    expect(list.error, isNotNull);
    expect(list.stale, true);
    h.reply = (_) => jsonReply(voucherPage([], page: 2, lastPage: 2));
    await list.load(refresh: true);
    expect(list.result!.pagination.currentPage, 2);
    expect(list.result!.items, isEmpty);
  });
  test('filter request supersedes late page and status reads', () async {
    final list = VoucherListController(h.session, repo, claims, wallet: true);
    addTearDown(list.dispose);
    final delayed = Completer<ResponseBody>();
    var count = 0;
    h.reply = (r) => ++count == 1
        ? delayed.future
        : jsonReply(voucherPage([voucherJson(issuer: 'app')]));
    final old = list.load();
    await Future<void>.delayed(Duration.zero);
    await list.filters(issuer: 'app');
    delayed.complete(jsonReply(voucherPage([voucherJson()])));
    await old;
    expect(list.result!.items.single.issuer, 'app');
  });
  test(
    'A to B to A account switching discards private detail and late replies',
    () async {
      final detail = VoucherDetailController(h.session, repo, claims, otherId);
      addTearDown(detail.dispose);
      final delayed = Completer<ResponseBody>();
      h.reply = (_) => delayed.future;
      final old = detail.load();
      await Future<void>.delayed(Duration.zero);
      await h.session.signOut();
      h.auth.identity = CustomerIdentity.parse(identityJson(id: otherId));
      await h.session.signIn('b@example.test', 'password');
      await h.session.signOut();
      h.auth.identity = CustomerIdentity.parse(identityJson());
      await h.session.signIn('a@example.test', 'password');
      delayed.complete(
        jsonReply({
          'items': [voucherJson(collected: true)],
        }),
      );
      await old;
      expect(detail.result, isNull);
      expect(claims.status(otherId), isNull);
    },
  );
  test('retained targeted/history detail uses private status without public detail', () async {
    final detail = VoucherDetailController(h.session, repo, claims, otherId);
    addTearDown(detail.dispose);
    h.reply = (_) => jsonReply({
      'items': [
        voucherJson(
          collected: true,
          reason: 'VOUCHER_ENDED',
          status: 'history',
        ),
      ],
    });
    await detail.load();
    expect(detail.result!.walletStatus, 'history');
    expect(
      h.adapter.requests.where(
        (r) => r.uri.path.endsWith('/vouchers/$otherId'),
      ),
      isEmpty,
    );
  });
  for (final mode in ['buy_now', 'cart']) {
    test(
      '$mode collection invalidates review and preserves safe choices; pending stays frozen',
      () async {
        final c = h.commerce.checkout;
        c.begin(
          mode == 'cart'
              ? CheckoutIntent.cart([customerId])
              : CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)),
        );
        await c.loadAddresses();
        c.chooseProvider(customerId, otherId);
        h.reply = (r) {
          if (r.uri.path.endsWith('/quote')) {
            final data = h.quoteFor(r.data as Map<String, dynamic>);
            data['data']['groups'][0]['availableVouchers'] = [
              checkoutVoucherJson(),
            ];
            return jsonReply(data);
          }
          return h.defaultReply(r);
        };
        await c.getQuote();
        expect(c.quote, isNotNull, reason: c.error);
        final id = c.quote!.groups.single.candidates.first.id;
        final address = c.addressId;
        final selections = c.shipping.selections;
        expect(c.openVoucherCollection(id), true);
        expect(c.quote, isNull);
        expect(c.canPlace, false);
        expect(c.addressId, address);
        expect(c.shipping.selections, selections);
        expect(c.vouchers, isEmpty);
        await c.getQuote();
        final frozen = c.quote;
        h.reply = (r) => r.uri.path.endsWith('/place')
            ? jsonReply({}, status: 503)
            : h.defaultReply(r);
        await c.place();
        final payload = c.pending!.payload, key = c.pending!.key;
        expect(c.openVoucherCollection(id), false);
        expect(c.pending!.payload, payload);
        expect(c.pending!.key, key);
        expect(frozen, isNotNull);
      },
    );
  }
}
