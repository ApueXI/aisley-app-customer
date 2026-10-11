import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/vouchers/data/customer_voucher.dart';
import 'package:aisley_mobile_buyer/features/vouchers/data/voucher_repository.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';
import '../support/voucher_fixtures.dart';

void main() {
  test('complete DTO separates public nulls from personal fields', () {
    final public = CustomerVoucher.parse(
      voucherJson(private: false),
      private: false,
    );
    expect(public.collected, isNull);
    expect(public.collectable, false);
    final personal = CustomerVoucher.parse(voucherJson(), private: true);
    expect(personal.collectable, true);
    expect(personal.remainingUses, 2);
    expect(personal.terms, isNull);
    expect(manilaVoucherTime(personal.validFrom), '2026-10-01 08:00');
    final unsupported = CustomerVoucher.parse(
      voucherJson()..['benefitType'] = 'future',
      private: true,
    );
    expect(unsupported.collectable, false);
  });
  for (final field in [
    'id',
    'name',
    'value',
    'minimumSpend',
    'maximumDiscount',
    'validFrom',
    'scope',
    'collected',
    'remainingPersonalUses',
    'canCollect',
    'walletStatus',
    'shop',
    'distributionMode',
  ]) {
    test('required $field cannot be silently omitted', () {
      expect(
        () =>
            CustomerVoucher.parse(voucherJson()..remove(field), private: true),
        throwsA(isA<ApiFailure>()),
      );
    });
  }
  test('malformed flags/money/negative uses/private leakage are rejected', () {
    for (final edit in [
      {'collected': 'true'},
      {'value': 10},
      {'remainingPersonalUses': -1},
      {'validUntil': 'yesterday'},
    ]) {
      expect(
        () => CustomerVoucher.parse(voucherJson()..addAll(edit), private: true),
        throwsA(isA<ApiFailure>()),
      );
    }
    expect(
      () => CustomerVoucher.parse(voucherJson(), private: false),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => CustomerVoucher.parse(voucherJson(private: false), private: true),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('hidden Shop history and null cap remain valid; unsupported actions stay unavailable', () {
    final row = CustomerVoucher.parse(
      voucherJson(
          collected: true,
          reason: 'VOUCHER_SHOP_UNAVAILABLE',
          status: 'history',
        )
        ..['shop'] = null
        ..['collectionUrl'] = null
        ..['maximumDiscount'] = null,
      private: true,
    );
    expect(row.shop, isNull);
    expect(row.collectable, false);
    expect(row.walletStatus, 'history');
  });

  group('repository', () {
    late CommerceHarness h;
    late VoucherRepository repo;
    setUp(() async {
      h = CommerceHarness();
      await h.initialize();
      repo = VoucherRepository(h.api);
    });
    tearDown(() {
      repo.dispose();
      h.dispose();
    });
    test('seven operations use exact endpoints, envelopes and credential boundaries', () async {
      h.reply = (r) {
        final p = r.uri.path;
        if (p.endsWith('/voucher-statuses')) {
          return jsonReply({
            'items': [voucherJson()],
          });
        }
        if (p.endsWith('/my-vouchers')) {
          return jsonReply(voucherPage([voucherJson(collected: true)]));
        }
        if (p.endsWith('/claim')) {
          return jsonReply({
            'data': voucherJson(
              issuer: p.contains('/shops/') ? 'shop' : 'app',
              collected: true,
            ),
          });
        }
        if (p.endsWith('/$otherId')) {
          return jsonReply({'data': voucherJson(private: false)});
        }
        return jsonReply(voucherPage([voucherJson(private: false)]));
      };
      await repo.list(issuer: 'shop', benefit: 'discount', page: 2);
      expect(h.adapter.requests.last.uri.queryParameters, {
        'issuer': 'shop',
        'benefit': 'discount',
        'page': '2',
        'limit': '20',
      });
      await repo.detail(otherId);
      await repo.list(shopSlug: 'demo-shop');
      final reads = h.adapter.requests
          .where((r) => r.uri.path.contains('vouchers'))
          .toList();
      expect(reads.every((r) => !r.headers.containsKey('Authorization')), true);
      await repo.mine(h.session.verifiedLease!, status: 'history');
      await repo.statuses(h.session.verifiedLease!, [otherId]);
      expect(h.adapter.requests.last.uri.queryParameters, {'ids[0]': otherId});
      await repo.collect(
        h.session.verifiedLease!,
        CustomerVoucher.parse(voucherJson(), private: true),
      );
      expect(
        h.adapter.requests.last.uri.path,
        '/api/v1/customer/shops/demo-shop/vouchers/$otherId/claim',
      );
      await repo.collect(
        h.session.verifiedLease!,
        CustomerVoucher.parse(voucherJson(issuer: 'app'), private: true),
      );
      final claim = h.adapter.requests.last;
      expect(claim.uri.path, '/api/v1/customer/vouchers/$otherId/claim');
      expect(claim.method, 'POST');
      expect(claim.data, isNull);
      expect(claim.headers.containsKey('Idempotency-Key'), false);
      expect(claim.headers['Authorization'], startsWith('Bearer '));
    });
    test(
      'bounded statuses reject duplicate, excessive and foreign IDs',
      () async {
        for (final ids in [
          <String>[],
          [otherId, otherId],
          List.filled(51, otherId),
        ]) {
          await expectLater(
            repo.statuses(h.session.verifiedLease!, ids),
            throwsA(isA<ApiFailure>()),
          );
        }
        h.reply = (_) => jsonReply({
          'items': [voucherJson(id: customerId)],
        });
        await expectLater(
          repo.statuses(h.session.verifiedLease!, [otherId]),
          throwsA(isA<ApiFailure>()),
        );
      },
    );
    test('public cache refresh ignores an older late success; private reads never cache', () async {
      final delay = Completer<dynamic>();
      var n = 0;
      h.reply = (_) {
        n++;
        return n == 1
            ? delay.future.then(
                (_) => jsonReply(
                  voucherPage([voucherJson(private: false)..['name'] = 'old']),
                ),
              )
            : jsonReply(
                voucherPage([voucherJson(private: false)..['name'] = 'new']),
              );
      };
      final first = repo.list();
      await Future<void>.delayed(Duration.zero);
      await repo.list(refresh: true);
      delay.complete(null);
      await first;
      expect((await repo.list()).items.single.name, 'new');
      expect(n, 2);
      h.reply = (_) => jsonReply(voucherPage([voucherJson()]));
      final before = h.adapter.requests.length;
      await repo.mine(h.session.verifiedLease!);
      await repo.mine(h.session.verifiedLease!);
      expect(h.adapter.requests.length - before, 2);
    });
    test(
      'malformed collection confirmation stays an uncertain failure',
      () async {
        h.reply = (_) => jsonReply({'data': voucherJson(collected: false)});
        await expectLater(
          repo.collect(
            h.session.verifiedLease!,
            CustomerVoucher.parse(voucherJson(), private: true),
          ),
          throwsA(
            isA<ApiFailure>().having((e) => e.uncertain, 'uncertain', true),
          ),
        );
      },
    );
  });
}
