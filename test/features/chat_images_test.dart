import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:aisley_mobile_buyer/core/chat_media/draft_controller.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_thread_controller.dart';
import 'package:aisley_mobile_buyer/features/logistics_messages/presentation/logistics_thread_controller.dart';
import 'package:aisley_mobile_buyer/features/courier_messages/presentation/courier_thread_controller.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';
import '../support/chat_media_fake.dart';

void main() {
  test(
    'identity loss clears private viewers before channel disposal',
    () async {
      final h = CommunicationHarness();
      await h.initialize();
      final controllers = [
        h.state.shopThread(shop: otherId).media!,
        h.state.logisticsThread(order: customerId).media!,
        h.state.courierThread(order: customerId).media!,
      ];
      final notices = [0, 0, 0];
      for (var i = 0; i < controllers.length; i++) {
        controllers[i].addListener(() => notices[i]++);
      }
      await h.session.signOut();
      expect(notices, everyElement(greaterThan(0)));
      h.dispose();
    },
  );

  for (final channel in ['shop', 'logistics', 'courier']) {
    test(
      '$channel image-only first send freezes IDs/key through lost response',
      () async {
        final h = CommunicationHarness();
        await h.initialize();
        final media = ChatMediaDraftController(MediaFake());
        final entry = {'context_type': 'order', 'context_id': customerId};
        final dynamic c = switch (channel) {
          'shop' => ShopThreadController(
            h.session,
            h.state.shops,
            entry: {'shop_id': customerId},
            media: media,
          ),
          'logistics' => LogisticsThreadController(
            h.session,
            h.state.logistics,
            entry: entry,
            media: media,
          ),
          _ => CourierThreadController(
            h.session,
            h.state.courier,
            entry: entry,
            media: media,
          ),
        };
        var writes = 0;
        final feature = channel == 'shop'
            ? 'chat-messaging'
            : '$channel-messaging';
        final op = channel == 'shop'
            ? 58
            : channel == 'logistics'
            ? 65
            : 71;
        h.reply = (o) {
          if (o.uri.path.contains('order-context')) {
            return jsonReply({
              'data': {
                'order_id': customerId,
                'order_reference': 'Synthetic',
                'send_allowed': true,
                'conversation_id': null,
              },
            });
          }
          if (o.method == 'POST' && !o.uri.path.endsWith('/read')) {
            writes++;
            if (writes == 1) {
              throw DioException(
                requestOptions: o,
                type: DioExceptionType.receiveTimeout,
              );
            }
            return jsonReply(
              fixture(feature, 'op-${op.toString().padLeft(3, '0')}'),
              status: 201,
            );
          }
          return h.defaultReply(o);
        };
        await c.load();
        await media.add(c.mediaContext as Map<String, Object?>);
        expect(media.ready, isTrue);
        await c.send();
        expect(c.pending.body['body'], '');
        expect(c.pending.body['attachment_ids'], [assetId]);
        expect(media.locked, isTrue);
        final key = c.pending.key;
        c.draft = 'Changed text';
        await media.remove(media.items.single);
        await c.send();
        c.reset(preserveUnresolved: true);
        expect(media.items, isEmpty);
        expect(c.pending.key, key);
        expect(c.pending.body['attachment_ids'], [assetId]);
        await c.load();
        await c.retry();
        expect(writes, 2);
        final posts = h.adapter.requests
            .where((o) => o.method == 'POST' && !o.uri.path.endsWith('/read'))
            .toList();
        expect(posts[0].data, posts[1].data);
        expect(posts[1].headers['Idempotency-Key'], key);
        expect(c.pending, isNull);
        expect(media.items, isEmpty);
        c.dispose();
        h.dispose();
      },
    );
  }
}
