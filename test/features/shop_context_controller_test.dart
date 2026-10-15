import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/data/shop_models.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';
import '../support/shop_context_fixtures.dart';

void main() {
  late CommunicationHarness h;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());

  for (final type in [null, 'product', 'order']) {
    for (final existing in [false, true]) {
      test(
        '$type entry discovers ${existing ? 'existing' : 'prospective'} thread',
        () async {
          final c = h.state.shopThread(
            shop: otherId,
            contextType: type,
            contextId: type == null ? null : customerId,
          );
          h.reply = (r) {
            if (r.method == 'POST') return jsonReply(shopWrite(), status: 201);
            if (r.uri.path.contains('/shops/')) {
              return jsonReply({
                'data': shopContext(conversation: existing ? customerId : null),
              });
            }
            if (r.uri.path.endsWith('/messages')) {
              return jsonReply(fixture('chat-messaging', 'op-060'));
            }
            return jsonReply({'data': shopSummary()});
          };
          expect(c.canSend, isFalse);
          c.draft = 'About this Shop';
          await c.send();
          expect(h.adapter.requests, isEmpty);
          await c.load();
          expect(c.error, isNull);
          expect(c.canSend, isTrue);
          expect(c.id, existing ? customerId : null);
          expect(c.messages.length, existing ? 1 : 0);
          expect(h.adapter.requests.map((r) => r.method), everyElement('GET'));
          expect(
            c.mediaContext,
            existing
                ? {'conversation_id': customerId}
                : {
                    'channel': 'shop',
                    'shop_id': otherId,
                    if (type != null) ...{
                      'context_type': type,
                      'context_id': customerId,
                    },
                  },
          );
          await c.send();
          final write = h.adapter.requests.last;
          expect(
            write.uri.path,
            existing
                ? '/api/v1/customer/conversations/$customerId/messages'
                : '/api/v1/customer/conversations',
          );
          expect(write.data, {
            if (!existing) 'shop_id': otherId,
            'body': 'About this Shop',
            if (type != null) ...{
              'context_type': type,
              'context_id': customerId,
            },
          });
          expect(c.id, customerId);
          expect(c.pending, isNull);
          expect(c.messages.length, 1);
        },
      );
    }
  }
  for (final type in [null, 'product', 'order']) {
    test(
      'vacation prospective $type uses the owned-Order exception only',
      () async {
        final c = h.state.shopThread(
          shop: otherId,
          contextType: type,
          contextId: type == null ? null : customerId,
        );
        h.reply = (_) => jsonReply({
          'data': shopContext(availability: 'vacation', allowed: false),
        });
        await c.load();
        expect(c.canSend, type == 'order');
        expect(c.shop!.availability, ShopAvailability.vacation);
        if (type != 'order') {
          c.draft = 'Unsent';
          await c.send();
          expect(h.adapter.requests.every((r) => r.method == 'GET'), isTrue);
        }
      },
    );
  }
  test('vacation owned-Order start remains server-validated', () async {
    final c = h.state.shopThread(
      shop: otherId,
      contextType: 'order',
      contextId: customerId,
    );
    h.reply = (r) => r.method == 'GET'
        ? jsonReply({
            'data': shopContext(availability: 'vacation', allowed: false),
          })
        : jsonReply({
            'errors': {
              'context_id': ['Unavailable'],
            },
          }, status: 422);
    await c.load();
    c.draft = 'About my Order';
    await c.send();
    expect(c.pending, isNull);
    expect(c.draft, 'About my Order');
    expect(c.fieldErrors, contains('context_id'));
    expect(c.messages, isEmpty);
  });
  test(
    'existing vacation thread permission overrides generic context preview',
    () async {
      final c = h.state.shopThread(shop: otherId);
      h.reply = (r) {
        if (r.uri.path.contains('/shops/')) {
          return jsonReply({
            'data': shopContext(
              conversation: customerId,
              availability: 'vacation',
              allowed: false,
            ),
          });
        }
        if (r.uri.path.endsWith('/messages')) {
          return jsonReply(fixture('chat-messaging', 'op-060'));
        }
        return jsonReply({'data': shopSummary(availability: 'vacation')});
      };
      await c.load();
      expect(c.id, customerId);
      expect(c.canSend, isTrue);
      expect(c.shop!.availability, ShopAvailability.vacation);
      h.reply = (r) => r.uri.path.endsWith('/messages')
          ? jsonReply(fixture('chat-messaging', 'op-060'))
          : jsonReply({
              'data': shopSummary(availability: 'offline', allowed: false),
            });
      await c.load();
      expect(c.canSend, isFalse);
      expect(c.messages, isNotEmpty);
      expect(c.shop!.availability, ShopAvailability.offline);
    },
  );
  for (final availability in ['offline', 'unknown-future-status']) {
    test('$availability context blocks even an Order start', () async {
      final c = h.state.shopThread(
        shop: otherId,
        contextType: 'order',
        contextId: customerId,
      );
      h.reply = (_) => jsonReply({
        'data': shopContext(availability: availability, allowed: false),
      });
      await c.load();
      expect(c.canSend, isFalse);
    });
  }
  for (final mismatch in ['conversation', 'shop']) {
    test(
      'discovered summary rejects mismatched $mismatch before history adoption',
      () async {
        final c = h.state.shopThread(shop: otherId);
        h.reply = (r) => jsonReply({
          'data': r.uri.path.contains('/shops/')
              ? shopContext(conversation: customerId)
              : shopSummary(
                  id: mismatch == 'conversation' ? otherId : customerId,
                  shop: mismatch == 'shop' ? customerId : otherId,
                ),
        });
        await c.load();
        expect(c.id, isNull);
        expect(c.canSend, isFalse);
        expect(c.conversation, isNull);
        expect(c.messages, isEmpty);
        expect(c.error, contains('could not be read'));
        expect(h.adapter.requests.length, 2);
      },
    );
  }
  test(
    'failed history never enables a discovered thread or falls back to start',
    () async {
      final c = h.state.shopThread(shop: otherId);
      h.reply = (r) {
        if (r.uri.path.contains('/shops/')) {
          return jsonReply({'data': shopContext(conversation: customerId)});
        }
        if (r.uri.path.endsWith('/messages')) return jsonReply({}, status: 500);
        return jsonReply({'data': shopSummary()});
      };
      await c.load();
      expect(c.id, isNull);
      expect(c.canSend, isFalse);
      c.draft = 'Keep this input';
      await c.send();
      expect(h.adapter.requests.map((r) => r.method), everyElement('GET'));
      expect(c.draft, 'Keep this input');
    },
  );
  for (final status in [403, 404, 409, 422, 429]) {
    test(
      'context $status fails closed and a deliberate reload recovers',
      () async {
        final c = h.state.shopThread(shop: otherId);
        c.draft = 'Safe input';
        h.reply = (_) => jsonReply(
          {},
          status: status,
          headers: status == 429
              ? {
                  'retry-after': ['60'],
                }
              : {},
        );
        await c.load();
        expect(c.canSend, isFalse);
        expect(c.context, isNull);
        expect(c.error, isNotNull);
        expect(c.unavailable, status == 403 || status == 404);
        expect(c.draft, status == 403 || status == 404 ? '' : 'Safe input');
        expect(h.session.active, isTrue);
        if (status == 429) {
          expect(c.coolingDown, isTrue);
          await c.load();
          expect(h.adapter.requests.length, 1);
          c.clearCooldown();
        }
        h.reply = (_) => jsonReply({'data': shopContext()});
        await c.load();
        expect(c.canSend, isTrue);
        expect(c.error, isNull);
        expect(c.unavailable, isFalse);
      },
    );
  }
  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.receiveTimeout,
  ]) {
    test(
      'failed prospective refresh clears permission and retains draft ($type)',
      () async {
        final c = h.state.shopThread(shop: otherId);
        h.reply = (_) => jsonReply({'data': shopContext()});
        await c.load();
        c.draft = 'Keep draft';
        h.reply = (r) => throw DioException(requestOptions: r, type: type);
        await c.load();
        expect(c.context, isNull);
        expect(c.canSend, isFalse);
        expect(c.draft, 'Keep draft');
        expect(c.offline, isTrue);
      },
    );
  }
  test('overlapping discovery and sends cannot dispatch writes', () async {
    final c = h.state.shopThread(shop: otherId);
    final response = Completer<ResponseBody>();
    h.reply = (_) => response.future;
    final load = c.load();
    await c.load();
    c.draft = 'Wait for context';
    await c.send();
    response.complete(jsonReply({'data': shopContext()}));
    await load;
    expect(h.adapter.requests.length, 1);
    expect(c.canSend, isTrue);
  });
}
