import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/data/shop_models.dart';
import 'package:aisley_mobile_buyer/features/logistics_messages/data/logistics_models.dart';
import 'package:aisley_mobile_buyer/features/courier_messages/data/courier_models.dart';
import 'package:aisley_mobile_buyer/features/notifications/data/notification_models.dart';
import 'package:aisley_mobile_buyer/features/questions/data/question_models.dart';
import 'package:aisley_mobile_buyer/features/reviews/data/review_models.dart';
import 'package:aisley_mobile_buyer/features/support/data/support_models.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_picker_adapter.dart';
import 'package:aisley_mobile_buyer/app/router_guard.dart';

import '../support/fakes.dart';
import '../support/communication_harness.dart';

void main() {
  late CommunicationHarness h;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());
  test(
    'Channel envelopes, nullable fields and permissions stay independent',
    () async {
      final lease = h.session.verifiedLease!;
      final shop = await h.state.shops.inbox(lease);
      final logistics = await h.state.logistics.inbox(lease);
      final courier = await h.state.courier.inbox(lease);
      expect(shop.items.single.label, 'Synthetic example');
      expect(logistics.items.single.reason, 'ORDER_RELATIONSHIP_ENDED');
      expect(courier.items.single.reason, 'TASK_NOT_ACTIVE');
      expect(courier.items.single.taskId, isNull);
      expect(shop.items.single.sendAllowed, isFalse);
      h.reply = (o) => jsonReply(fixture('logistics-messaging', 'op-064'));
      await expectLater(
        h.state.shops.inbox(lease),
        throwsA(
          isA<ApiFailure>().having((e) => e.kind, 'kind', FailureKind.decode),
        ),
      );
    },
  );
  test('Required types, casing and nulls reject malformed success', () {
    final cases = <Map<String, dynamic>, void Function(Object?)>{
      fixture('chat-messaging', 'op-059')['data']: ShopConversation.parse,
      fixture('logistics-messaging', 'op-066')['data']:
          LogisticsConversation.parse,
      fixture('courier-messaging', 'op-072')['data']: CourierConversation.parse,
      fixture('notifications', 'op-055')['data']: BuyerNotification.parse,
      fixture('product-qa', 'op-050')['data']: ProductQuestion.parse,
      fixture('product-review-ratings', 'op-052')['data']: ProductReview.parse,
      fixture('support-tickets', 'op-078')['data']: SupportTicket.parse,
    };
    for (final entry in cases.entries) {
      entry.value(entry.key);
      expect(
        () => entry.value({...entry.key}..remove('id')),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () => entry.value({...entry.key, 'id': 'foreign'}),
        throwsA(isA<ApiFailure>()),
      );
    }
    final q = fixture('product-qa', 'op-050')['data'] as Map<String, dynamic>;
    expect(
      () => ProductQuestion.parse(
        {...q}
          ..remove('askedAt')
          ..['asked_at'] = null,
      ),
      throwsA(isA<ApiFailure>()),
    );
    final e =
        fixture('support-tickets', 'op-079')['events'][0]
            as Map<String, dynamic>;
    expect(TicketEvent.parse(e).body, isNull);
    expect(
      () => TicketEvent.parse({...e, 'is_mine': 1}),
      throwsA(isA<ApiFailure>()),
    );
  });
  test(
    'Exact starts, sends, read bodies and public credential boundaries',
    () async {
      final lease = h.session.verifiedLease!;
      await h.state.shops.write(lease, null, {
        'shop_id': otherId,
        'body': 'Hello',
        'context_type': 'product',
        'context_id': customerId,
      }, otherId);
      await h.state.logistics.write(lease, null, {
        'context_type': 'order',
        'context_id': customerId,
        'body': 'Hello',
      }, otherId);
      await h.state.courier.orderContext(lease, customerId);
      await h.state.courier.write(lease, null, {
        'context_type': 'order',
        'context_id': customerId,
        'body': 'Hello',
      }, otherId);
      await h.state.shops.read(lease, customerId, 4);
      await h.state.logistics.read(lease, customerId, 5);
      await h.state.courier.read(lease, customerId, 6);
      final requests = h.adapter.requests;
      expect(requests[0].uri.path, '/api/v1/customer/conversations');
      expect(requests[1].uri.path, '/api/v1/customer/logistics-conversations');
      expect(
        requests[2].uri.path,
        '/api/v1/customer/courier-conversations/order-context/$customerId',
      );
      expect(requests.every((o) => !o.uri.path.contains('//')), isTrue);
      expect(requests[0].data, {
        'shop_id': otherId,
        'body': 'Hello',
        'context_type': 'product',
        'context_id': customerId,
      });
      expect(requests[1].data, {
        'context_type': 'order',
        'context_id': customerId,
        'body': 'Hello',
      });
      expect(requests[2].method, 'GET');
      expect(requests[4].data, {'sequence': 4});
      expect(requests[5].data, {'last_read_sequence': 5});
      expect(requests[6].data, {'last_read_sequence': 6});
      expect(requests[4].headers.containsKey('Idempotency-Key'), isFalse);
      await h.state.questions.list(customerId);
      await h.state.reviews.list(customerId);
      expect(requests.last.headers.containsKey('Authorization'), isFalse);
      expect(requests[7].headers.containsKey('Authorization'), isFalse);
      await h.state.questions.ask(
        lease,
        customerId,
        '  Hello\r\nworld  ',
        otherId,
      );
      expect(requests.last.uri.path, '/api/v1/products/$customerId/questions');
      expect(requests.last.data, {'question': 'Hello\nworld'});
      expect(requests.last.headers['Idempotency-Key'], otherId);
      await h.state.reviews.create(lease, customerId, 5, 'Excellent');
      expect(
        requests.last.uri.path,
        '/api/v1/customer/order-items/$customerId/review',
      );
      expect(requests.last.data, {'rating': 5, 'body': 'Excellent'});
      expect(requests.last.headers.containsKey('Idempotency-Key'), isFalse);
      await h.state.support.write(lease, null, {
        'subject': 'Help',
        'category': 'general',
        'body': 'Description',
      }, otherId);
      expect(requests.last.data, {
        'subject': 'Help',
        'category': 'general',
        'body': 'Description',
      });
      await h.state.support.read(lease, customerId, 0);
      expect(requests.last.data, {'last_read_sequence': 0});
    },
  );
  test(
    'Multipart image has exact part, no replay key, and strict size/type',
    () async {
      final lease = h.session.verifiedLease!;
      final photo = PickedBuyerImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'photo.png',
        mimeType: 'image/png',
      );
      await h.state.reviews.upload(lease, customerId, photo);
      final o = h.adapter.requests.last;
      expect(o.data, isA<FormData>());
      final data = o.data as FormData;
      expect(data.files.single.key, 'image');
      expect(data.files.single.value.filename, 'photo.png');
      expect(o.headers.containsKey('Idempotency-Key'), isFalse);
      for (final invalid in [
        PickedBuyerImage(
          bytes: Uint8List(10485760),
          filename: 'photo.png',
          mimeType: 'image/png',
        ),
        PickedBuyerImage(
          bytes: Uint8List(1),
          filename: 'photo.png.jpg',
          mimeType: 'image/jpeg',
        ),
        PickedBuyerImage(
          bytes: Uint8List(1),
          filename: 'photo.jpg',
          mimeType: 'image/png',
        ),
      ]) {
        await expectLater(
          h.state.reviews.upload(lease, customerId, invalid),
          throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 422)),
        );
      }
    },
  );
  test('Notification destinations and safe auth returns validate all IDs', () {
    final raw =
        fixture('notifications', 'op-055')['data'] as Map<String, dynamic>;
    for (final entry in {
      '/products/$customerId#questions': '/products/$customerId/questions',
      '/products/$customerId#reviews': '/products/$customerId/reviews',
      '/shops/safe-shop': '/shops/safe-shop',
      '/account/orders/$customerId': '/orders/$customerId',
      'https://evil.invalid/orders/$customerId': '/notifications/$customerId',
      '//evil.invalid/x': '/notifications/$customerId',
      '/orders/not-a-uuid': '/notifications/$customerId',
      '/products/$customerId?token=no': '/notifications/$customerId',
    }.entries) {
      expect(
        notificationDestination(
          BuyerNotification.parse({...raw, 'destination': entry.key}),
        ),
        entry.value,
      );
    }
    expect(
      safeReturn('/messages/courier/order/$customerId'),
      '/messages/courier/order/$customerId',
    );
    expect(
      safeReturn('/products/$customerId/questions'),
      '/products/$customerId/questions',
    );
    expect(
      safeReturn(
        '/messages/shops/new/$customerId?context_type=order&context_id=$otherId',
      ),
      '/messages/shops/new/$customerId?context_type=order&context_id=$otherId',
    );
    for (final path in [
      '/notifications/no',
      '/messages/logistics/no',
      '/support-tickets/no',
      '/messages/shops/new/$customerId?context_type=order&context_id=no',
      '/messages/shops/new/$customerId?context_type=order&context_type=product&context_id=$otherId',
    ]) {
      expect(safeReturn(path), '/account');
    }
  });
}
