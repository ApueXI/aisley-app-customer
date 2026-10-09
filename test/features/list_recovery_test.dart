import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/notifications/presentation/notification_controllers.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_repository.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/orders_controller.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/saved_products_controller.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/saved_status_controller.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';

// Run the same behavioral contract against each independently typed endpoint.
const collections = [
  'shop',
  'logistics',
  'courier',
  'support',
  'notifications',
  'orders',
  'wishlist',
  'recent',
];
Map<String, dynamic> pageFor(String name, {int page = 1, bool empty = false}) {
  final (feature, op) = switch (name) {
    'shop' => ('chat-messaging', 'op-057'),
    'logistics' => ('logistics-messaging', 'op-064'),
    'courier' => ('courier-messaging', 'op-070'),
    'support' => ('support-tickets', 'op-077'),
    'notifications' => ('notifications', 'op-054'),
    'orders' => ('order-status', 'op-032'),
    'wishlist' => ('wishlist', 'op-037'),
    _ => ('recently-viewed-items', 'op-041'),
  };
  final value = fixture(feature, op);
  if (name == 'orders' || name == 'notifications') {
    value['meta']['current_page'] = page;
    value['meta']['last_page'] = 3;
    if (empty) value['data'] = [];
  } else if (name == 'wishlist' || name == 'recent') {
    value['meta']['next_cursor'] = 'next-$page';
    if (empty) value['data'] = [];
  } else if (name == 'logistics' || name == 'courier') {
    value['meta']['next_cursor'] = 'next-$page';
    if (empty) value['data'] = [];
  } else {
    value['next_cursor'] = 'next-$page';
    if (empty) value['items'] = [];
  }
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final name in collections) {
    group(name, () {
      late CommunicationHarness h;
      late dynamic c;
      setUp(() async {
        h = CommunicationHarness();
        await h.initialize();
        switch (name) {
          case 'shop':
            c = h.state.shopInbox;
          case 'logistics':
            c = h.state.logisticsInbox;
          case 'courier':
            c = h.state.courierInbox;
          case 'support':
            c = h.state.ticketInbox;
          case 'notifications':
            c = NotificationInboxController(h.session, h.state.notifications);
            addTearDown(c.dispose as void Function());
          case 'orders':
            c = OrdersController(h.session, OrderRepository(h.api));
            addTearDown(c.dispose as void Function());
          default:
            final wishlist = WishlistRepository(h.api);
            final status = SavedStatusController(h.session, wishlist);
            c = SavedProductsController(
              h.session,
              collection: name == 'wishlist'
                  ? SavedCollection.wishlist
                  : SavedCollection.recentlyViewed,
              wishlist: wishlist,
              recent: RecentlyViewedRepository(h.api),
              savedStatus: status,
            );
            addTearDown(status.dispose);
            addTearDown(c.dispose as void Function());
        }
        h.reply = (_) => jsonReply(pageFor(name));
      });
      tearDown(() => h.dispose());

      test(
        'refresh failure preserves stale rows and blocks append until success',
        () async {
          await c.load();
          expect(c.items, isNotEmpty);
          final before = List.of(c.items as List);
          h.reply = (_) => jsonReply({}, status: 503);
          await c.load();
          expect(c.items, before);
          expect(c.stale, true);
          expect(c.error, isNotNull);
          final requests = h.adapter.requests.length;
          await c.load(more: true);
          expect(h.adapter.requests.length, requests);
          h.reply = (_) => jsonReply(pageFor(name, empty: true));
          await c.load();
          expect(c.items, isEmpty);
          expect(c.stale, false);
          expect(c.error, isNull);
          expect(c.pageError, isNull);
        },
      );

      test('failed append retries the same page without losing rows', () async {
        await c.load();
        final before = List.of(c.items as List);
        h.reply = (_) => jsonReply({}, status: 503);
        await c.load(more: true);
        final failed = h.adapter.requests.last.uri;
        expect(c.items, before);
        expect(c.pageError, isNotNull);
        expect(c.error, isNull);
        h.reply = (_) => jsonReply(pageFor(name, page: 2));
        await c.load(more: true);
        expect(h.adapter.requests.last.uri, failed);
        expect(c.items.length, before.length); // overlapping IDs deduplicate
        expect(c.pageError, isNull);
      });

      for (final failure in [false, true]) {
        test(
          'refresh supersedes delayed append ${failure ? 'failure' : 'success'}',
          () async {
            await c.load();
            final pending = Completer<ResponseBody>();
            h.reply = (_) => pending.future;
            final old = c.load(more: true) as Future<void>;
            await Future<void>.delayed(Duration.zero);
            h.reply = (_) => jsonReply(pageFor(name, empty: true));
            await c.load();
            pending.complete(
              jsonReply(
                failure ? {} : pageFor(name, page: 2),
                status: failure ? 422 : 200,
              ),
            );
            await old;
            expect(c.items, isEmpty);
            expect(c.error, isNull);
            expect(c.pageError, isNull);
            expect(c.loading, false);
          },
        );
      }

      test(
        'resource denial clears rows and does not report empty success',
        () async {
          await c.load();
          h.reply = (_) => jsonReply({}, status: 404);
          await c.load();
          expect(c.items, isEmpty);
          expect(c.error, isNotNull);
          expect(h.session.active, true);
        },
      );

      test(
        'initial and formerly empty refresh failures remain failures',
        () async {
          h.reply = (_) => jsonReply({}, status: 503);
          await c.load();
          expect(c.items, isEmpty);
          expect(c.stale, true);
          expect(c.error, isNotNull);
          h.reply = (_) => jsonReply(pageFor(name, empty: true));
          await c.load();
          expect(c.stale, false);
          h.reply = (_) => jsonReply({}, status: 503);
          await c.load();
          expect(c.stale, true);
          expect(c.error, isNotNull);
        },
      );

      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.receiveTimeout,
      ]) {
        test('$type retains rows for manual refresh', () async {
          await c.load();
          h.reply = (o) => throw DioException(requestOptions: o, type: type);
          await c.load();
          expect(c.items, isNotEmpty);
          expect(c.stale, true);
          expect(c.error, isNotNull);
        });
      }

      if (['shop', 'logistics', 'courier', 'support'].contains(name)) {
        test('successful page Retry resumes foreground reads after offline failure', () async {
          await c.load();
          h.reply = (o) => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
          await c.load(more: true);
          expect(c.offline, true);
          h.reply = (_) => jsonReply(pageFor(name, page: 2));
          await c.load(more: true);
          expect(c.offline, false);
        });
      }

      test(
        'throttled page preserves retry target and blocks repeat requests',
        () async {
          await c.load();
          h.reply = (_) => jsonReply(
            {},
            status: 429,
            headers: {
              'retry-after': ['30'],
            },
          );
          await c.load(more: true);
          final count = h.adapter.requests.length;
          expect(c.coolingDown, true);
          expect(c.pageError, isNotNull);
          await c.load(more: true);
          await c.load();
          expect(h.adapter.requests.length, count);
          expect(c.items, isNotEmpty);
        },
      );

      test(
        'consent clears rows and rejects late failures without losing identity',
        () async {
          await c.load();
          final delayed = Completer<ResponseBody>();
          h.reply = (_) => delayed.future;
          final pending = c.load(more: true) as Future<void>;
          await Future<void>.delayed(Duration.zero);
          h.policies.consent = ConsentStatus.parse(consentJson(required: true));
          await h.session.refreshConsent();
          delayed.complete(jsonReply({}, status: 422));
          await pending;
          expect(h.session.customer!.id, customerId);
          expect(h.session.active, false);
          expect(c.items, isEmpty);
          expect(c.error, isNull);
          expect(c.pageError, isNull);
          h.policies.consent = ConsentStatus.parse(consentJson());
          await h.session.refreshConsent();
          expect(c.items, isEmpty);
        },
      );

      test(
        'duplicates on first page collapse and no-progress cursors stop',
        () async {
          Map<String, dynamic> duplicatePage(int page) {
            final value = pageFor(name, page: page);
            final key = name == 'shop' || name == 'support' ? 'items' : 'data';
            value[key] = [value[key][0], value[key][0]];
            return value;
          }

          h.reply = (_) => jsonReply(duplicatePage(1));
          await c.load();
          expect(c.items.length, 1);
          h.reply = (_) => jsonReply(duplicatePage(2));
          await c.load(more: true);
          expect(c.items.length, 1);
          final count = h.adapter.requests.length;
          if (name != 'orders' && name != 'notifications') {
            await c.load(more: true);
            expect(h.adapter.requests.length, count);
          } else {
            expect(c.hasMore, true); // numbered metadata stays authoritative
          }
        },
      );

      test('A to B to A cannot restore pending rows or errors', () async {
        await c.load();
        final pending = Completer<ResponseBody>();
        h.reply = (_) => pending.future;
        final old = c.load(more: true) as Future<void>;
        await Future<void>.delayed(Duration.zero);
        for (final id in [otherId, customerId]) {
          h.auth.identity = CustomerIdentity.parse(identityJson(id: id));
          h.auth.onLogin = () async => LoginResult.parse({
            'message': 'OK',
            'customer': identityJson(id: id),
            'token': 'synthetic-$id',
          });
          await h.session.signIn('buyer@example.invalid', 'Synthetic123');
          expect(c.items, isEmpty);
        }
        pending.complete(jsonReply(pageFor(name, page: 2)));
        await old;
        expect(c.items, isEmpty);
        expect(c.error, isNull);
        expect(c.pageError, isNull);
      });
    });
  }
}
