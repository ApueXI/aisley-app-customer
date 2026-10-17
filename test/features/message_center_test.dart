import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/router_guard.dart';
import 'package:aisley_mobile_buyer/features/messaging/data/conversation_preview.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';
import '../support/message_fixtures.dart';

import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';

void main() {
  late CommunicationHarness h;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
    h.reply = (o) => jsonReply(inboxPage(channelFor(o)));
  });
  tearDown(() => h.dispose());

  test('combined inbox sorts channels, keeps colliding UUIDs and totals all unread', () async {
    h.reply = (o) => jsonReply(
      inboxPage(
        channelFor(o),
        unread: channelFor(o) == 'shop' ? 120 : 2,
        at: channelFor(o) == 'shop' ? null : '2026-10-17T08:00:00Z',
      ),
    );
    final messages = h.state.messages;
    expect(messages.unread, isNull);
    await messages.refresh();
    final rows = messages.conversations();
    expect(rows.map((e) => e.channel), [
      MessageChannel.logistics,
      MessageChannel.courier,
      MessageChannel.shop,
    ]);
    expect(rows.map((e) => e.key).toSet(), hasLength(3));
    expect(messages.unread, 124);
    expect(messages.conversations(MessageChannel.shop), hasLength(1));
    expect(rows.last.route, '/messages/shops/$customerId');
    expect(h.adapter.requests, hasLength(3));
    expect(h.adapter.requests.every((o) => o.method == 'GET'), isTrue);
  });

  test(
    'load more keeps separate cursors and repeated pages stop traversing',
    () async {
      h.reply = (o) {
        final channel = channelFor(o);
        return jsonReply(
          inboxPage(
            channel,
            id: o.uri.queryParameters['cursor'] == null ? customerId : otherId,
            next: '$channel-next',
          ),
        );
      };
      await h.state.messages.refresh();
      await h.state.messages.loadMore(MessageChannel.shop);
      expect(h.state.shopInbox.items, hasLength(2));
      expect(h.state.logisticsInbox.items, hasLength(1));
      expect(
        h.adapter.requests.last.uri.queryParameters['cursor'],
        'shop-next',
      );
      expect(h.state.shopInbox.trail.next, isNull);
      await h.state.messages.loadMore();
      expect(h.state.messages.conversations(), hasLength(6));
      expect(h.state.logisticsInbox.trail.next, isNull);
      expect(h.state.courierInbox.trail.next, isNull);
    },
  );

  test(
    'foreground refresh preserves loaded pages and older cursor frontier',
    () async {
      var refreshed = false;
      h.reply = (o) {
        final cursor = o.uri.queryParameters['cursor'];
        if (cursor == 'older') {
          return jsonReply(inboxPage('shop', id: otherId, next: 'oldest'));
        }
        if (cursor == 'bridge') {
          return jsonReply(inboxPage('shop', id: otherId, next: 'oldest'));
        }
        return jsonReply(
          inboxPage('shop', next: refreshed ? 'bridge' : 'older'),
        );
      };
      final inbox = h.state.shopInbox;
      await inbox.load();
      await inbox.load(more: true);
      refreshed = true;
      await inbox.load(retain: true);
      expect(inbox.items, hasLength(2));
      expect(inbox.trail.next, 'bridge');
      await inbox.load(more: true);
      expect(inbox.trail.next, 'oldest');
      expect(inbox.items, hasLength(2));
    },
  );

  test('partial failure retains successful channels without a false total or empty success', () async {
    await h.state.messages.refresh();
    h.reply = (o) => channelFor(o) == 'logistics'
        ? jsonReply({}, status: 503)
        : jsonReply(inboxPage(channelFor(o), unread: 0));
    await h.state.messages.refresh();
    expect(h.state.messages.unread, isNull);
    expect(h.state.messages.hasSnapshot, isTrue);
    expect(h.state.messages.conversations(), hasLength(3));
    expect(h.state.logisticsInbox.stale, isTrue);
    expect(h.state.logisticsInbox.error, isNotNull);
    expect(h.state.shopInbox.unreadFresh, isTrue);
  });

  for (final status in [403, 404]) {
    test('scoped $status clears only the affected channel', () async {
      await h.state.messages.refresh();
      h.reply = (o) => channelFor(o) == 'courier'
          ? jsonReply({}, status: status)
          : jsonReply(inboxPage(channelFor(o)));
      await h.state.messages.refresh();
      expect(h.state.courierInbox.items, isEmpty);
      expect(h.state.courierInbox.loaded, isFalse);
      expect(h.state.messages.conversations(), hasLength(2));
      expect(h.session.active, isTrue);
      expect(h.state.messages.unread, isNull);
    });
  }

  test('429 honors cooldown while other channels remain available', () async {
    h.reply = (o) => channelFor(o) == 'shop'
        ? jsonReply(
            {},
            status: 429,
            headers: {
              'retry-after': ['60'],
            },
          )
        : jsonReply(inboxPage(channelFor(o)));
    await h.state.messages.refresh();
    expect(h.state.shopInbox.coolingDown, isTrue);
    final before = h.adapter.requests
        .where((o) => channelFor(o) == 'shop')
        .length;
    await h.state.messages.refresh();
    expect(
      h.adapter.requests.where((o) => channelFor(o) == 'shop'),
      hasLength(before),
    );
    expect(h.state.messages.conversations(), hasLength(2));
  });

  test(
    'automatic refresh pauses offline but explicit retry recovers',
    () async {
      h.reply = (o) => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      );
      await h.state.messages.refresh();
      final before = h.adapter.requests.length;
      await h.state.messages.refresh(automatic: true);
      expect(h.adapter.requests, hasLength(before));
      h.reply = (o) => jsonReply(inboxPage(channelFor(o), unread: 0));
      await h.state.messages.refresh();
      expect(h.state.messages.unread, 0);
    },
  );

  test(
    'overlapping refresh and paging do not supersede a deliberate request',
    () async {
      final response = Completer<ResponseBody>();
      h.reply = (_) => response.future;
      final first = h.state.shopInbox.load();
      await Future<void>.delayed(Duration.zero);
      await h.state.shopInbox.load(retain: true);
      await h.state.shopInbox.load(more: true);
      for (var i = 0; i < 100 && h.adapter.requests.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(h.adapter.requests, hasLength(1));
      response.complete(jsonReply(inboxPage('shop')));
      await first;
      expect(h.state.shopInbox.loaded, isTrue);
    },
  );

  test(
    'commit during an older inbox request leaves unread dirty until refreshed',
    () async {
      final response = Completer<ResponseBody>();
      h.reply = (_) => response.future;
      final first = h.state.shopInbox.load();
      await Future<void>.delayed(Duration.zero);
      h.state.messages.invalidate(MessageChannel.shop);
      response.complete(jsonReply(inboxPage('shop', unread: 5)));
      await first;
      expect(h.state.shopInbox.needsRefresh, isTrue);
      expect(h.state.shopInbox.unreadFresh, isFalse);
      h.reply = (_) => jsonReply(inboxPage('shop', unread: 0));
      await h.state.messages.refresh(onlyNeeded: true);
      expect(h.state.shopInbox.unreadFresh, isTrue);
    },
  );

  for (final channel in MessageChannel.values) {
    test('${channel.name} denied thread removes its cached preview', () async {
      await h.state.messages.refresh();
      h.reply = (_) => jsonReply({}, status: 404);
      final dynamic thread = switch (channel) {
        MessageChannel.shop => h.state.shopThread(id: customerId),
        MessageChannel.logistics => h.state.logisticsThread(id: customerId),
        MessageChannel.courier => h.state.courierThread(id: customerId),
      };
      await thread.load();
      expect(h.state.messages.conversations(channel), isEmpty);
      expect(h.state.messages.conversations(), hasLength(2));
      expect(h.session.active, isTrue);
    });
    test(
      '${channel.name} confirmed read and send invalidate the aggregate',
      () async {
        await h.state.messages.refresh();
        h.reply = (o) {
          if (o.method == 'GET' && o.uri.pathSegments.last == customerId) {
            final op = channel == MessageChannel.shop
                ? 'op-059'
                : channel == MessageChannel.logistics
                ? 'op-066'
                : 'op-072';
            final data = fixture(
              channel == MessageChannel.shop
                  ? 'chat-messaging'
                  : '${channel.name}-messaging',
              op,
            );
            data['data']['last_read_sequence'] = 0;
            return jsonReply(data);
          }
          return h.defaultReply(o);
        };
        final dynamic thread = switch (channel) {
          MessageChannel.shop => h.state.shopThread(id: customerId),
          MessageChannel.logistics => h.state.logisticsThread(id: customerId),
          MessageChannel.courier => h.state.courierThread(id: customerId),
        };
        await thread.load();
        await thread.displayed(thread.messages.last.sequence);
        expect(h.state.messages.channels[channel]!.needsRefresh, isTrue);
        expect(h.state.messages.unread, isNull);
        await h.state.messages.refresh();
        // The fixture is read-only, so supply the existing writable summary.
        h.reply = (o) {
          final result = h.defaultReply(o);
          if (o.method == 'GET' && o.uri.pathSegments.last == customerId) {
            final op = channel == MessageChannel.shop
                ? 'op-059'
                : channel == MessageChannel.logistics
                ? 'op-066'
                : 'op-072';
            final data = fixture(
              channel == MessageChannel.shop
                  ? 'chat-messaging'
                  : '${channel.name}-messaging',
              op,
            );
            data['data']['send_allowed'] = true;
            return jsonReply(data);
          }
          return result;
        };
        await thread.load();
        thread.draft = 'Synthetic test message';
        await thread.send();
        expect(thread.pending, isNull);
        expect(h.state.messages.channels[channel]!.needsRefresh, isTrue);
      },
    );
  }

  test(
    'background invalidation cannot be overwritten by an older response',
    () async {
      final response = Completer<ResponseBody>();
      h.reply = (_) => response.future;
      final loading = h.state.shopInbox.load();
      h.state.messages.markStale();
      response.complete(jsonReply(inboxPage('shop')));
      await loading;
      expect(h.state.shopInbox.loaded, isTrue);
      expect(h.state.shopInbox.unreadFresh, isFalse);
    },
  );

  test(
    'a discarded preview cannot return through an obsolete inbox response',
    () async {
      await h.state.messages.refresh();
      final response = Completer<ResponseBody>();
      h.reply = (_) => response.future;
      final loading = h.state.shopInbox.load(retain: true);
      h.state.messages.invalidate(MessageChannel.shop, deniedId: customerId);
      response.complete(jsonReply(inboxPage('shop')));
      await loading;
      expect(h.state.messages.conversations(MessageChannel.shop), isEmpty);
      expect(h.state.shopInbox.busy, isFalse);
      expect(h.state.shopInbox.unreadFresh, isFalse);
    },
  );

  test(
    'consent clears inbox snapshots and prevents protected refresh',
    () async {
      await h.state.messages.refresh();
      h.policies.consent = ConsentStatus.parse(consentJson(required: true));
      await h.session.refreshConsent();
      final before = h.adapter.requests.length;
      await h.state.messages.refresh();
      expect(h.state.messages.conversations(), isEmpty);
      expect(h.state.messages.unread, isNull);
      expect(h.adapter.requests, hasLength(before));
      expect(safeReturn('/messages'), '/messages');
      expect(
        guardRoute(h.session, Uri.parse('/messages')),
        '/consent?returnTo=%2Fmessages',
      );
    },
  );

  for (final deny in [false, true]) {
    test(
      'late ${deny ? 'denial' : 'success'} cannot populate a newer account',
      () async {
        final response = Completer<ResponseBody>();
        h.reply = (_) => response.future;
        final first = h.state.messages.refresh();
        await Future<void>.delayed(Duration.zero);
        await h.session.signOut();
        h.auth.identity = CustomerIdentity.parse(identityJson(id: otherId));
        h.auth.onLogin = () async => LoginResult.parse({
          'message': 'OK',
          'customer': identityJson(id: otherId),
          'token': 'synthetic-other-token',
        });
        await h.session.signIn('buyer@example.invalid', 'Synthetic1');
        response.complete(
          deny
              ? jsonReply({'code': 'ACCOUNT_SUSPENDED'}, status: 403)
              : jsonReply(inboxPage('shop')),
        );
        await first;
        expect(h.state.messages.conversations(), isEmpty);
        expect(h.state.messages.unread, isNull);
        expect(h.session.active, isTrue);
      },
    );
  }
}
