import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

import '../support/fakes.dart';
import '../support/communication_harness.dart';

void main() {
  late CommunicationHarness h;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());
  dynamic controller(String channel, {bool start = false}) => switch (channel) {
    'shop' =>
      start
          ? h.state.shopThread(
              shop: otherId,
              contextType: 'product',
              contextId: customerId,
            )
          : h.state.shopThread(id: customerId),
    'logistics' =>
      start
          ? h.state.logisticsThread(order: customerId)
          : h.state.logisticsThread(id: customerId),
    _ =>
      start
          ? h.state.courierThread(order: customerId)
          : h.state.courierThread(id: customerId),
  };
  String feature(String channel) =>
      channel == 'shop' ? 'chat-messaging' : '$channel-messaging';
  int first(String channel) => channel == 'shop'
      ? 57
      : channel == 'logistics'
      ? 64
      : 70;
  for (final channel in ['shop', 'logistics', 'courier']) {
    test(
      '$channel lost first send freezes context/body/key and exact replay',
      () async {
        final c = controller(channel, start: true);
        final op = first(channel);
        var sends = 0;
        h.reply = (o) {
          if (o.uri.path.contains('order-context')) {
            return jsonReply({
              ...fixture('courier-messaging', 'op-076'),
              'data': {
                'order_id': customerId,
                'order_reference': 'ORDER-SYNTHETIC',
                'send_allowed': true,
                'conversation_id': null,
              },
            });
          }
          if (o.method == 'POST' && !o.uri.path.endsWith('/read')) {
            sends++;
            if (sends == 1) {
              throw DioException(
                requestOptions: o,
                type: DioExceptionType.receiveTimeout,
              );
            }
            return jsonReply(
              fixture(
                feature(channel),
                'op-${(op + 1).toString().padLeft(3, '0')}',
              ),
              status: channel == 'shop' ? 201 : 200,
            );
          }
          return h.defaultReply(o);
        };
        await c.load();
        expect(h.adapter.requests.where((o) => o.method == 'POST'), isEmpty);
        c.draft = 'First private synthetic text';
        await c.send();
        expect(c.pending, isNotNull);
        expect(c.messages, isEmpty);
        final post = h.adapter.requests.firstWhere((o) => o.method == 'POST');
        c.draft = 'Changed draft cannot change the pending send';
        await c.send();
        await c.load();
        expect(c.pending.body['body'], 'First private synthetic text');
        expect(identical(c, controller(channel, start: true)), isTrue);
        await c.retry();
        final replay = h.adapter.requests.lastWhere((o) => o.method == 'POST');
        expect(replay.data, post.data);
        expect(
          replay.headers['Idempotency-Key'],
          post.headers['Idempotency-Key'],
        );
        expect(c.pending, isNull);
        expect(c.messages.length, 1);
        expect(sends, 2);
      },
    );
    test(
      '$channel consent during flight preserves unresolved result and blocks new-key conflict',
      () async {
        final c = controller(channel);
        await c.load();
        // Make the synthetic history writable in each independent channel.
        final summary = fixture(
          feature(channel),
          'op-${(first(channel) + 2).toString().padLeft(3, '0')}',
        );
        summary['data']['send_allowed'] = true;
        h.reply = (o) => o.method == 'GET' && !o.uri.path.endsWith('/messages')
            ? jsonReply(summary)
            : h.defaultReply(o);
        await c.load();
        final deferred = Completer<ResponseBody>();
        h.reply = (o) =>
            o.method == 'POST' ? deferred.future : h.defaultReply(o);
        c.draft = 'Interrupted synthetic send';
        final flight = c.send() as Future<void>;
        await Future<void>.delayed(Duration.zero);
        final key = c.pending.key;
        h.policies.consent = ConsentStatus.parse(consentJson(required: true));
        await h.session.refreshConsent();
        expect(c.pending.uncertain, isTrue);
        deferred.complete(
          jsonReply(
            fixture(
              feature(channel),
              'op-${(first(channel) + 4).toString().padLeft(3, '0')}',
            ),
            status: 201,
          ),
        );
        await flight;
        expect(c.messages, isEmpty);
        expect(c.pending.key, key);
        h.policies.consent = ConsentStatus.parse(consentJson());
        await h.session.refreshConsent();
        h.reply = (o) => o.method == 'POST'
            ? jsonReply({}, status: 409)
            : (o.uri.path.endsWith('/messages')
                  ? h.defaultReply(o)
                  : jsonReply(summary));
        await c.retry();
        c.reviewConflict();
        expect(c.pending.key, key);
        expect(c.conflict, isTrue);
      },
    );
    test(
      '$channel monotonic reads serialize, deduplicate and never cross channels',
      () async {
        final c = controller(channel);
        final op = first(channel);
        final history = fixture(
          feature(channel),
          'op-${(op + 3).toString().padLeft(3, '0')}',
        );
        final listKey = channel == 'shop' ? 'items' : 'data';
        final row = history[listKey][0] as Map<String, dynamic>;
        history[listKey] = [
          for (var i = 1; i <= 3; i++)
            {
              ...row,
              'id':
                  '${i.toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
              'sequence': i,
            },
        ];
        final read = Completer<ResponseBody>();
        var count = 0;
        h.reply = (o) {
          if (o.uri.path.endsWith('/messages')) return jsonReply(history);
          if (o.uri.path.endsWith('/read')) {
            count++;
            return count == 1 ? read.future : h.defaultReply(o);
          }
          return h.defaultReply(o);
        };
        await c.load();
        expect(c.error, isNull);
        expect(c.messages.length, 3);
        final a = c.displayed(2) as Future<void>;
        for (var i = 0; i < 100 && count == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        await c.displayed(3);
        await c.displayed(1);
        expect(count, 1);
        read.complete(
          jsonReply(
            fixture(
              feature(channel),
              'op-${(op + 5).toString().padLeft(3, '0')}',
            ),
          ),
        );
        await a;
        expect(count, 2);
        await c.displayed(3);
        expect(count, 2);
        final key = channel == 'shop' ? 'sequence' : 'last_read_sequence';
        final requests = h.adapter.requests
            .where((o) => o.uri.path.endsWith('/read'))
            .toList();
        expect(requests.map((o) => o.data[key]).toList(), [2, 3]);
        expect(
          requests.every(
            (o) => o.uri.path.contains(
              channel == 'shop'
                  ? '/conversations/'
                  : '/$channel-conversations/',
            ),
          ),
          isTrue,
        );
      },
    );
    test(
      '$channel late errors and successes cannot cross sign-out/account switch',
      () async {
        final c = controller(channel, start: true);
        final deferred = Completer<ResponseBody>();
        h.reply = (o) {
          if (o.uri.path.contains('order-context')) {
            return jsonReply({
              'data': {
                'order_id': customerId,
                'order_reference': 'Order',
                'send_allowed': true,
                'conversation_id': null,
              },
            });
          }
          return o.method == 'POST' ? deferred.future : h.defaultReply(o);
        };
        await c.load();
        c.draft = 'Synthetic';
        final sending = c.send() as Future<void>;
        await Future<void>.delayed(Duration.zero);
        await h.session.signOut();
        deferred.complete(
          jsonReply({'code': 'ACCOUNT_SUSPENDED'}, status: 403),
        );
        await sending;
        expect(c.pending, isNull);
        expect(c.messages, isEmpty);
        expect(c.draft, isEmpty);
        await h.session.signIn('buyer@example.invalid', 'Synthetic1');
        expect(controller(channel, start: true).pending, isNull);
      },
    );
    test(
      '$channel consent hides transcript while preserving unresolved exact intent',
      () async {
        final c = controller(channel, start: true);
        h.reply = (o) {
          if (o.uri.path.contains('order-context')) {
            return jsonReply({
              'data': {
                'order_id': customerId,
                'order_reference': 'Order',
                'send_allowed': true,
                'conversation_id': null,
              },
            });
          }
          if (o.method == 'POST') {
            throw DioException(
              requestOptions: o,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return h.defaultReply(o);
        };
        await c.load();
        c.draft = 'Synthetic pending';
        await c.send();
        final key = c.pending.key;
        h.policies.consent = ConsentStatus.parse(consentJson(required: true));
        await h.session.refreshConsent();
        expect(h.session.active, isFalse);
        expect(c.draft, isEmpty);
        expect(c.messages, isEmpty);
        expect(c.pending.key, key);
        final before = h.adapter.requests.length;
        h.policies.consent = ConsentStatus.parse(consentJson());
        await h.session.refreshConsent();
        await Future<void>.delayed(Duration.zero);
        expect(h.adapter.requests.length, before);
      },
    );
  }
  test(
    'Courier context creates no thread and denies unaccepted contact',
    () async {
      final c = h.state.courierThread(order: customerId);
      await c.load();
      expect(c.canSend, isFalse);
      c.draft = 'Hello';
      await c.send();
      expect(h.adapter.requests.map((o) => o.method), everyElement('GET'));
      expect(c.id, isNull);
    },
  );
  test('Courier relationship change keeps old history until deliberate new contact', () async {
    final c = h.state.courierThread(order: customerId);
    var changed = false;
    h.reply = (o) {
      if (o.uri.path.contains('order-context')) {
        return jsonReply({
          'data': {
            'order_id': customerId,
            'order_reference': 'Order',
            'send_allowed': true,
            'conversation_id': changed ? otherId : customerId,
          },
        });
      }
      if (!o.uri.path.endsWith('/messages')) {
        final summary = fixture('courier-messaging', 'op-072');
        summary['data']['send_allowed'] = !changed;
        return jsonReply(summary);
      }
      return h.defaultReply(o);
    };
    await c.load();
    c.draft = 'Old unsent draft';
    changed = true;
    await c.load();
    expect(c.id, customerId);
    expect(c.messages, isNotEmpty);
    expect(c.canSend, isFalse);
    expect(c.replacementAvailable, isTrue);
    c.contactCurrentCourier();
    expect(c.id, otherId);
    expect(c.messages, isEmpty);
    expect(c.draft, isEmpty);
    expect(h.adapter.requests.where((o) => o.method == 'POST'), isEmpty);
  });
  test(
    'Shop older-history frontier survives a foreground refresh gap',
    () async {
      final c = h.state.shopThread(id: customerId);
      final row =
          fixture('chat-messaging', 'op-060')['items'][0]
              as Map<String, dynamic>;
      var refresh = 0;
      Map<String, dynamic> history(int from, int to, String? next) => {
        'items': [
          for (var i = from; i <= to; i++)
            {
              ...row,
              'id':
                  '${i.toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
              'sequence': i,
            },
        ],
        'next_cursor': next,
      };
      h.reply = (o) {
        if (o.uri.path.endsWith('/messages')) {
          final cursor = o.uri.queryParameters['cursor'];
          if (cursor == 'old') return jsonReply(history(1, 10, null));
          if (cursor == 'bridge') return jsonReply(history(31, 79, 'old'));
          return jsonReply(
            ++refresh == 1
                ? history(11, 30, 'old')
                : history(80, 110, 'bridge'),
          );
        }
        return h.defaultReply(o);
      };
      await c.load();
      await c.load();
      expect(c.trail.next, 'bridge');
      await c.load(more: true);
      expect(c.trail.next, 'old');
      await c.load(more: true);
      expect(
        c.messages.map((e) => e.sequence).toList(),
        List.generate(110, (i) => i + 1),
      );
      expect(c.trail.next, isNull);
    },
  );
  test(
    'Scoped denial clears affected channel; 429 retains frozen pending key',
    () async {
      final shop = h.state.shopThread(shop: otherId),
          logistics = h.state.logisticsThread(id: customerId);
      await logistics.load();
      h.reply = (o) => jsonReply(
        {},
        status: 429,
        headers: {
          'retry-after': ['60'],
        },
      );
      shop.draft = 'Hello';
      await shop.send();
      expect(shop.coolingDown, isTrue);
      expect(shop.pending, isNotNull);
      expect(logistics.messages, isNotEmpty);
      h.reply = (o) => jsonReply({}, status: 404);
      await logistics.load();
      expect(logistics.messages, isEmpty);
      expect(h.session.active, isTrue);
    },
  );
  test(
    'Repeated inbox cursor and duplicate page terminates traversal',
    () async {
      final page = fixture('logistics-messaging', 'op-064');
      page['meta']['next_cursor'] = 'repeated';
      h.reply = (o) => jsonReply(page);
      final c = h.state.logisticsInbox;
      await c.load();
      await c.load(more: true);
      expect(c.items.length, 1);
      expect(c.trail.next, isNull);
    },
  );
}
