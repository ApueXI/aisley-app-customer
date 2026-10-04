import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_models.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_repository.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_models.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/orders_controller.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/order_detail_controller.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

import '../support/fakes.dart';
import '../support/commerce_harness.dart';

void main() {
  late CommerceHarness h;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());
  BuyerOrder order() => BuyerOrder.parse(h.orderJson['data']);
  Map<String, dynamic> candidateJson() => {
    ...h.orderJson['data']['deliveryAddress'] as Map<String, dynamic>,
    'id': otherId,
    'type': 'shipping',
    'label': null,
    'recipientName': 'Updated recipient',
    'latitude': null,
    'longitude': null,
    'isDefault': false,
  }..remove('version');
  OrderDetailController detail() => OrderDetailController(
    h.session,
    h.commerce.orders,
    h.commerce.mutations,
    AddressRepository(h.api),
    customerId,
  );

  test('G21 compares every trimmed field, nullable line two and requires changed contact', () {
    final snapshot = order().address;
    final candidate = candidateJson();
    expect(
      snapshot.permitsContactCorrection(BuyerAddress.parse(candidate)),
      true,
    );
    for (final key in [
      'addressLine1',
      'barangay',
      'cityMunicipality',
      'province',
      'region',
      'postalCode',
      'country',
    ]) {
      final changed = {...candidate, key: 'Different'};
      expect(
        snapshot.permitsContactCorrection(BuyerAddress.parse(changed)),
        false,
        reason: key,
      );
      changed[key] = '';
      expect(
        snapshot.permitsContactCorrection(BuyerAddress.parse(changed)),
        false,
        reason: '$key cannot be verified',
      );
      final padded = {...candidate, key: ' ${candidate[key]} '};
      expect(
        snapshot.permitsContactCorrection(BuyerAddress.parse(padded)),
        true,
        reason: 'trim $key',
      );
    }
    expect(
      snapshot.permitsContactCorrection(
        BuyerAddress.parse({...candidate, 'addressLine2': '  '}),
      ),
      true,
    );
    expect(
      snapshot.permitsContactCorrection(
        BuyerAddress.parse({...candidate, 'addressLine2': 'Other unit'}),
      ),
      false,
    );
    expect(
      snapshot.permitsContactCorrection(
        BuyerAddress.parse({...candidate, 'recipientName': snapshot.recipient}),
      ),
      false,
    );
    expect(
      snapshot.permitsContactCorrection(
        BuyerAddress.parse({...candidate, 'type': 'billing'}),
      ),
      false,
    );
    expect(
      snapshot.permitsContactCorrection(
        BuyerAddress.parse({...candidate, 'type': 'both'}),
      ),
      true,
    );
    expect(
      snapshot.permitsContactCorrection(
        BuyerAddress.parse({...candidate, 'contactNumber': ''}),
      ),
      false,
    );
  });
  test('unknown status and unknown correction fields fail closed despite true capability flags', () {
    final raw = clone(h.orderJson['data']);
    raw['status'] = 'future_status';
    expect(BuyerOrder.parse(raw).canCancel, false);
    raw['status'] = 'placed';
    raw['actions']['modifiableFields'] = ['quantity', 'future_address'];
    expect(BuyerOrder.parse(raw).canCorrect, false);
    raw['status'] = 'seller_processing';
    expect(BuyerOrder.parse(raw).canCancel, false);
  });
  test('cancellation freezes optional reason key; uncertain response prevents competing correction', () async {
    final m = h.commerce.mutations;
    var attempts = 0;
    h.reply = (r) {
      if (r.uri.path.endsWith('/cancel') && ++attempts == 1) {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return h.defaultReply(r);
    };
    expect(await m.cancel(order(), '  Changed mind  ', fresh: true), isNull);
    expect(m.pending(customerId)!.payload, {'reason': 'Changed mind'});
    expect(
      await m.correct(
        order(),
        BuyerAddress.parse(candidateJson()),
        fresh: true,
        owned: true,
      ),
      isNull,
    );
    expect(await m.cancel(order(), 'Different', fresh: true), isNull);
    expect((await m.retry(customerId))!.status, 'cancelled');
    final writes = h.adapter.requests
        .where((r) => r.uri.path.endsWith('/cancel'))
        .toList();
    expect(writes, hasLength(2));
    expect(writes.first.data, writes.last.data);
    expect(
      writes.first.headers['Idempotency-Key'],
      writes.last.headers['Idempotency-Key'],
    );
    expect(h.keys, 1);
  });
  test('correction sends known revision and only owned unchanged locations; full response refreshes capabilities', () async {
    final m = h.commerce.mutations,
        candidate = BuyerAddress.parse(candidateJson());
    expect(
      await m.correct(order(), candidate, fresh: false, owned: true),
      isNull,
    );
    expect(
      await m.correct(order(), candidate, fresh: true, owned: false),
      isNull,
    );
    expect(
      await m.correct(
        order(),
        BuyerAddress.parse({...candidateJson(), 'region': 'Different'}),
        fresh: true,
        owned: true,
      ),
      isNull,
    );
    final value = await m.correct(order(), candidate, fresh: true, owned: true);
    expect(value!.address.version, 2);
    expect(order().address.version, 1);
    final request = h.adapter.requests.last;
    expect(request.method, 'PATCH');
    expect(request.data, {'address_id': otherId, 'expected_revision': 1});
    expect(request.headers['Idempotency-Key'], isNotNull);
  });
  test('processing races and stale revision conflicts require detail refresh before another action', () async {
    final c = detail();
    addTearDown(c.dispose);
    await c.load();
    h.reply = (r) {
      if (r.uri.path.endsWith('/cancel')) {
        h.orderJson['data']['status'] = 'seller_processing';
        h.orderJson['data']['actions']['canCancel'] = false;
        return jsonReply({'code': 'ORDER_NOT_CANCELLABLE'}, status: 409);
      }
      return h.defaultReply(r);
    };
    await c.cancel(null);
    expect(c.order!.status, 'seller_processing');
    expect(c.canCancel, false);
    expect(h.commerce.mutations.pending(customerId), isNull);
    expect(h.commerce.mutations.errorFor(customerId), isNotNull);
  });
  test('stale detail disables mutations; scoped denial clears immutable facts and timeline', () async {
    final c = detail();
    addTearDown(c.dispose);
    await c.load();
    expect(c.canCancel, true);
    h.reply = (r) => r.uri.path.contains('/orders/')
        ? jsonReply({}, status: 503)
        : h.defaultReply(r);
    await c.load();
    expect(c.stale, true);
    expect(c.order, isNotNull);
    expect(c.canCancel, false);
    h.reply = (r) => r.uri.path.contains('/orders/')
        ? jsonReply({}, status: 404)
        : h.defaultReply(r);
    await c.load();
    expect(c.order, isNull);
    expect(c.timeline, isEmpty);
    expect(h.session.active, true);
  });
  test('tracking traverses preview overlap from page one and deduplicates events chronologically', () async {
    final c = detail();
    addTearDown(c.dispose);
    h.orderJson['data']['timelineHasMore'] = true;
    h.orderJson['data']['timelineCount'] = 2;
    h.reply = (r) {
      if (!r.uri.path.endsWith('/tracking')) return h.defaultReply(r);
      final value = fixture('order-status', 'op-034');
      final page = int.parse(r.uri.queryParameters['page']!);
      value['meta']['current_page'] = page;
      value['meta']['last_page'] = 2;
      if (page == 2) {
        value['data'][0]['id'] = otherId;
        value['data'][0]['occurredAt'] = '2026-10-03T01:00:00Z';
      }
      return jsonReply(value);
    };
    await c.load();
    expect(c.timeline, hasLength(1));
    await c.moreTracking();
    expect(c.timeline, hasLength(1));
    expect(c.hasMore, true);
    await c.moreTracking();
    expect(c.timeline.map((e) => e.id), [customerId, otherId]);
    expect(c.hasMore, false);
    expect(
      h.adapter.requests
          .where((r) => r.uri.path.endsWith('/tracking'))
          .map((r) => r.uri.queryParameters['page']),
      ['1', '2'],
    );
  });
  test(
    'Orders discard obsolete filter responses and deduplicate page overlaps',
    () async {
      final c = OrdersController(h.session, h.commerce.orders);
      addTearDown(c.dispose);
      final delayed = Completer<ResponseBody>();
      h.reply = (r) {
        if (!r.uri.path.endsWith('/orders')) return h.defaultReply(r);
        if (!r.uri.queryParameters.containsKey('group')) return delayed.future;
        final value = fixture('order-status', 'op-032');
        value['filters']['selected'] = 'to_prepare';
        value['meta']['current_page'] = int.parse(
          r.uri.queryParameters['page']!,
        );
        value['meta']['last_page'] = 2;
        return jsonReply(value);
      };
      final old = c.load();
      await c.filter('to_prepare');
      delayed.complete(jsonReply(fixture('order-status', 'op-032')));
      await old;
      expect(c.group, 'to_prepare');
      expect(c.items, hasLength(1));
      await c.load(more: true);
      expect(c.items, hasLength(1));
      expect(c.hasMore, false);
    },
  );
  test('consent and navigation preserve unresolved Order key, then logout clears it', () async {
    final first = detail();
    await first.load();
    h.reply = (r) => r.uri.path.endsWith('/cancel')
        ? throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionTimeout,
          )
        : h.defaultReply(r);
    await first.cancel(null);
    final key = h.commerce.mutations.pending(customerId)!.key;
    first.dispose();
    final second = detail();
    addTearDown(second.dispose);
    await second.load();
    expect(second.canCancel, false);
    h.policies.consent = ConsentStatus.parse(consentJson(required: true));
    await h.session.refreshConsent();
    expect(second.order, isNull);
    expect(h.commerce.mutations.pending(customerId)!.key, key);
    h.policies.consent = ConsentStatus.parse(consentJson());
    await h.session.refreshConsent();
    expect(
      h.adapter.requests.where((r) => r.uri.path.endsWith('/cancel')),
      hasLength(1),
    );
    await h.session.signOut();
    expect(h.commerce.mutations.pending(customerId), isNull);
  });
  test(
    'identity 401 clears all commerce; resource 403 preserves identity',
    () async {
      h.reply = (r) => jsonReply({}, status: 403);
      await h.commerce.cart.load();
      expect(h.session.active, true);
      expect(h.commerce.cart.cart, isNull);
      h.reply = (r) => jsonReply({}, status: 401);
      await h.commerce.cart.load();
      await Future<void>.delayed(Duration.zero);
      expect(h.session.active, false);
      expect(h.commerce.cart.cart, isNull);
      expect(h.commerce.checkout.pending, isNull);
    },
  );
}
