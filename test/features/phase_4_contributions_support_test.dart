import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/communication/text_rules.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_picker_adapter.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/questions/presentation/question_controllers.dart';
import 'package:aisley_mobile_buyer/features/reviews/presentation/review_list_controller.dart';
import 'package:aisley_mobile_buyer/features/notifications/presentation/notification_controllers.dart';

import '../support/fakes.dart';
import '../support/communication_harness.dart';

class SyntheticPicker extends PhotoPickerAdapter {
  SyntheticPicker(this.result);
  final Future<PickedBuyerImage?> result;
  @override
  Future<PickedBuyerImage?> pick() => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CommunicationHarness h;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());
  test('Plain text normalizes newlines and Unicode scalar limits', () {
    expect(plainTextError(List.filled(1000, '😀').join(), 1000), isNull);
    expect(plainTextError(List.filled(1001, '😀').join(), 1000), isNotNull);
    expect(checkedText('  Hi\r\nthere  ', 1000), 'Hi\nthere');
    for (final value in [
      '<script>unsafe</script>',
      '[link](https://evil.invalid)',
      '\u0000',
      '# Heading',
    ]) {
      expect(plainTextError(value, 2000), isNotNull);
    }
  });
  test('Question first-response loss preserves exact question and blocks duplicates', () async {
    final c = h.state.ask(customerId);
    var count = 0;
    h.reply = (o) {
      if (o.method == 'POST') {
        if (++count == 1) {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionTimeout,
          );
        }
        return jsonReply(fixture('product-qa', 'op-050'), status: 201);
      }
      return h.defaultReply(o);
    };
    c.draft = '  Question\r\nnext line  ';
    await c.submit();
    final key = c.pending!.key;
    c.draft = 'Changed';
    await c.submit();
    expect(count, 1);
    await c.submit(retry: true);
    expect(count, 2);
    expect(c.committed, isNotNull);
    expect(c.pending, isNull);
    final posts = h.adapter.requests.where((o) => o.method == 'POST').toList();
    expect(posts[0].data, posts[1].data);
    expect(posts[1].headers['Idempotency-Key'], key);
  });
  test(
    'Question validation is editable; public denial clears old rows',
    () async {
      final c = h.state.ask(customerId);
      c.draft = 'Question';
      h.reply = (o) => jsonReply({
        'errors': {
          'question': ['Synthetic'],
        },
      }, status: 422);
      await c.submit();
      expect(c.pending, isNull);
      expect(c.draft, 'Question');
      expect(c.fieldErrors['question'], isNotNull);
      h.reply = null;
      final list = QuestionListController(h.state.questions, customerId);
      addTearDown(list.dispose);
      await list.load();
      expect(list.items, isNotEmpty);
      h.reply = (o) => jsonReply({}, status: 404);
      await list.load();
      expect(list.items, isEmpty);
      expect(list.loaded, isFalse);
      expect(list.error, isNotNull);
    },
  );
  test('Review text identical replay has no header, preserves changed-content conflict', () async {
    final c = h.state.review(customerId, otherId);
    var calls = 0;
    h.reply = (o) {
      if (o.uri.path.endsWith('/review')) {
        if (++calls == 1) {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return jsonReply(
          fixture('product-review-ratings', 'op-052'),
          status: 200,
        );
      }
      return h.defaultReply(o);
    };
    c.rating = 4;
    c.draft = 'Good';
    await c.submit();
    expect(c.pending, (rating: 4, body: 'Good'));
    c.rating = 1;
    c.draft = 'Changed';
    await c.submit();
    expect(calls, 1);
    await c.submit(retry: true);
    expect(c.reviewId, customerId);
    expect(c.pending, isNull);
    final requests = h.adapter.requests
        .where((o) => o.uri.path.endsWith('/review'))
        .toList();
    expect(requests[1].data, {'rating': 4, 'body': 'Good'});
    expect(requests[1].headers.containsKey('Idempotency-Key'), isFalse);
    final another = h.state.review(otherId, customerId);
    another.draft = 'Conflicting';
    h.reply = (o) =>
        jsonReply({'code': 'PRODUCT_REVIEW_ALREADY_SUBMITTED'}, status: 409);
    await another.submit();
    expect(another.conflict, isTrue);
    expect(another.reviewId, isNull);
  });
  test(
    'Review picker validates encoded dimensions and clears obsolete selection',
    () async {
      final c = h.state.review(customerId, otherId, reviewId: customerId);
      PickedBuyerImage image(String encoded) => PickedBuyerImage(
        bytes: base64Decode(encoded),
        filename: 'synthetic.png',
        mimeType: 'image/png',
      );
      await c.select(
        SyntheticPicker(
          Future.value(
            image(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
            ),
          ),
        ),
      );
      expect(c.selected, isNotNull);
      await c.select(
        SyntheticPicker(
          Future.value(
            image(
              'iVBORw0KGgoAAAANSUhEUgAAH0EAAAABCAYAAAC8ofMkAAAANklEQVR4nO3BMQEAAADCoPVP7WsIoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADOAH0FAAE/0qTtAAAAAElFTkSuQmCC',
            ),
          ),
        ),
      );
      expect(c.selected, isNull);
      expect(c.photoError, contains('8,000'));
      await c.select(
        SyntheticPicker(
          Future.value(
            PickedBuyerImage(
              bytes: Uint8List.fromList([1, 2, 3]),
              filename: 'synthetic.png',
              mimeType: 'image/png',
            ),
          ),
        ),
      );
      expect(c.selected, isNull);
      expect(c.photoError, contains('could not be read'));
      final picked = Completer<PickedBuyerImage?>();
      final selection = c.select(SyntheticPicker(picked.future));
      await h.session.signOut();
      picked.complete(
        image(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
        ),
      );
      await selection;
      expect(c.selected, isNull);
      expect(c.photos, isEmpty);
    },
  );
  test('Consent during photo upload requires canonical read and never repeats bytes', () async {
    final c = h.state.review(customerId, otherId, reviewId: customerId);
    c.selected = PickedBuyerImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'synthetic.png',
      mimeType: 'image/png',
    );
    final deferred = Completer<ResponseBody>();
    h.reply = (o) => deferred.future;
    final upload = c.upload();
    await Future<void>.delayed(Duration.zero);
    h.policies.consent = ConsentStatus.parse(consentJson(required: true));
    await h.session.refreshConsent();
    expect(c.uncertainPhoto, isTrue);
    expect(c.selected, isNull);
    deferred.complete(
      jsonReply(fixture('product-review-ratings', 'op-053'), status: 201),
    );
    await upload;
    expect(c.photos, isEmpty);
    h.policies.consent = ConsentStatus.parse(consentJson());
    await h.session.refreshConsent();
    expect(h.adapter.requests.length, 1);
  });
  test('Partial photo success remains; uncertain upload requires canonical traversal', () async {
    final c = h.state.review(customerId, otherId);
    c.draft = 'Excellent';
    await c.submit();
    final selected = PickedBuyerImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'photo.png',
      mimeType: 'image/png',
    );
    c.selected = selected;
    await c.upload();
    expect(c.photos.length, 1);
    expect(c.reviewId, customerId);
    h.reply = (o) {
      if (o.uri.path.endsWith('/images')) {
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return h.defaultReply(o);
    };
    c.selected = selected;
    await c.upload();
    expect(c.photos.length, 1);
    expect(c.uncertainPhoto, isTrue);
    expect(c.selected, isNull);
    final sent = h.adapter.requests
        .where((o) => o.uri.path.endsWith('/images'))
        .length;
    c.selected = selected;
    await c.upload();
    expect(
      h.adapter.requests.where((o) => o.uri.path.endsWith('/images')).length,
      sent,
    );
    final page = fixture('product-review-ratings', 'op-051');
    final review = Map<String, dynamic>.from(page['data'][0]);
    review['photos'] = [fixture('product-review-ratings', 'op-053')['data']];
    var pages = 0;
    h.reply = (o) {
      final p = int.parse(o.uri.queryParameters['page']!);
      pages++;
      return jsonReply({
        ...page,
        'data': [
          {...review, 'id': p == 1 ? otherId : customerId},
        ],
        'meta': {
          ...page['meta'],
          'current_page': p,
          'last_page': 2,
          'total': 2,
        },
      });
    };
    await c.reconcilePhotos();
    expect(pages, 2);
    expect(c.uncertainPhoto, isFalse);
    expect(c.photos.length, 1);
    expect(c.selected, isNull);
    expect(
      h.adapter.requests.where((o) => o.uri.path.endsWith('/images')).length,
      sent,
    );
  });
  test(
    'Canonical no-progress pages stop; removed Product keeps uploads blocked',
    () async {
      final c = h.state.review(customerId, otherId, reviewId: customerId);
      c.uncertainPhoto = true;
      final page = fixture('product-review-ratings', 'op-051');
      page['data'][0]['id'] = otherId;
      page['meta']['last_page'] = 10;
      var reads = 0;
      h.reply = (o) {
        reads++;
        return jsonReply({
          ...page,
          'meta': {
            ...page['meta'],
            'current_page': int.parse(o.uri.queryParameters['page']!),
          },
        });
      };
      await c.reconcilePhotos();
      expect(reads, 2);
      expect(c.uncertainPhoto, isTrue);
      expect(c.photoError, isNotNull);
    },
  );
  test('Public list pagination failure remains separate from successful rows and summary', () async {
    final c = ReviewListController(h.state.reviews, customerId);
    addTearDown(c.dispose);
    final page = fixture('product-review-ratings', 'op-051');
    page['meta']['last_page'] = 2;
    h.reply = (o) => o.uri.queryParameters['page'] == '2'
        ? jsonReply({}, status: 500)
        : jsonReply(page);
    await c.load();
    expect(c.items.length, 1);
    expect(c.summary!.count, 1);
    await c.load(more: true);
    expect(c.items.length, 1);
    expect(c.pageError, isNotNull);
    expect(c.error, isNull);
    expect(c.page, 1);
  });
  test(
    'Ticket create lost response and exact retry maps Description only to body',
    () async {
      final c = h.state.ticket();
      c.subject = 'Help';
      c.category = 'delivery';
      c.draft = 'Synthetic description';
      var count = 0;
      h.reply = (o) {
        if (o.method == 'POST' && !o.uri.path.endsWith('/read')) {
          if (++count == 1) {
            throw DioException(
              requestOptions: o,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return h.defaultReply(o);
        }
        return h.defaultReply(o);
      };
      await c.submit();
      final key = c.pending!.key;
      expect(identical(c, h.state.ticket()), isTrue);
      await c.submit();
      expect(count, 1);
      await c.retry();
      expect(c.id, customerId);
      final writes = h.adapter.requests
          .where((o) => o.method == 'POST')
          .toList();
      expect(writes[1].data, {
        'subject': 'Help',
        'category': 'delivery',
        'body': 'Synthetic description',
      });
      expect(writes[1].headers['Idempotency-Key'], key);
    },
  );
  test(
    'Stale revision refresh precedes reviewed new reply and new UUID',
    () async {
      final c = h.state.ticket(customerId);
      await c.load();
      c.draft = 'Reply';
      var posts = 0;
      h.reply = (o) {
        if (o.uri.path.endsWith('/replies')) {
          if (++posts == 1) return jsonReply({}, status: 409);
          return h.defaultReply(o);
        }
        final value = fixture('support-tickets', 'op-079');
        value['data']['revision'] = 2;
        value['data']['status'] = 'resolved';
        return jsonReply(value);
      };
      await c.submit();
      expect(c.conflict, isTrue);
      expect(c.ticket!.revision, 2);
      expect(c.pending!.body['expected_revision'], 1);
      await c.retry();
      expect(posts, 1);
      c.reviewConflict();
      await c.submit();
      expect(posts, 2);
      final writes = h.adapter.requests
          .where((o) => o.uri.path.endsWith('/replies'))
          .toList();
      expect(writes[1].data, {'body': 'Reply', 'expected_revision': 2});
      expect(
        writes[0].headers['Idempotency-Key'],
        isNot(writes[1].headers['Idempotency-Key']),
      );
    },
  );
  test('Ticket events paging advances chronologically and repeated cursor stops', () async {
    final c = h.state.ticket(customerId),
        data = fixture('support-tickets', 'op-079');
    final row = data['events'][0] as Map<String, dynamic>;
    h.reply = (o) {
      final older = o.uri.queryParameters.containsKey('cursor');
      return jsonReply({
        ...data,
        'events': [
          for (var i = older ? 1 : 31; i <= (older ? 30 : 60); i++)
            {
              ...row,
              'id':
                  '${i.toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
              'sequence': i,
            },
        ],
        'next_cursor': 'older',
      });
    };
    await c.load();
    await c.load(more: true);
    expect(c.events.length, 60);
    expect(c.events.first.sequence, 1);
    expect(c.events.last.sequence, 60);
    expect(c.trail.next, isNull);
  });
  test(
    'Late review success after account loss cannot repopulate state',
    () async {
      final review = h.state.review(customerId, otherId);
      review.draft = 'Review';
      final deferred = Completer<ResponseBody>();
      h.reply = (o) => deferred.future;
      final flight = review.submit();
      await Future<void>.delayed(Duration.zero);
      await h.session.signOut();
      deferred.complete(
        jsonReply(fixture('product-review-ratings', 'op-052'), status: 201),
      );
      await flight;
      expect(review.review, isNull);
      expect(review.pending, isNull);
      expect(review.photos, isEmpty);
      expect(review.selected, isNull);
    },
  );
  for (final kind in ['question', 'ticket']) {
    test(
      'Late $kind success after account switch cannot repopulate state',
      () async {
        final dynamic c = kind == 'question'
            ? h.state.ask(customerId)
            : h.state.ticket();
        if (kind == 'ticket') c.subject = 'Help';
        c.draft = 'Synthetic request';
        final deferred = Completer<ResponseBody>();
        h.reply = (o) => deferred.future;
        final flight = c.submit() as Future<void>;
        await Future<void>.delayed(Duration.zero);
        await h.session.signOut();
        await h.session.signIn('buyer@example.invalid', 'Synthetic1');
        deferred.complete(
          jsonReply(
            fixture(
              kind == 'question' ? 'product-qa' : 'support-tickets',
              kind == 'question' ? 'op-050' : 'op-078',
            ),
            status: 201,
          ),
        );
        await flight;
        expect(c.pending, isNull);
        expect(c.draft, isEmpty);
        if (kind == 'question') expect(c.committed, isNull);
        if (kind == 'ticket') expect(c.id, isNull);
      },
    );
  }
  test('Consent never replays a frozen question or ticket reply', () async {
    final ask = h.state.ask(customerId), ticket = h.state.ticket(customerId);
    await ticket.load();
    h.reply = (o) => throw DioException(
      requestOptions: o,
      type: DioExceptionType.receiveTimeout,
    );
    ask.draft = 'Question';
    await ask.submit();
    ticket.draft = 'Reply';
    await ticket.submit();
    h.policies.consent = ConsentStatus.parse(consentJson(required: true));
    await h.session.refreshConsent();
    expect(ask.draft, isEmpty);
    expect(ticket.events, isEmpty);
    expect(ask.pending, isNotNull);
    expect(ticket.pending, isNotNull);
    final requests = h.adapter.requests.length;
    h.policies.consent = ConsentStatus.parse(consentJson());
    await h.session.refreshConsent();
    expect(h.adapter.requests.length, requests);
  });
  test(
    'Notification filters reject obsolete pages and reads are independent',
    () async {
      final inbox = NotificationInboxController(
        h.session,
        h.state.notifications,
      );
      addTearDown(inbox.dispose);
      final old = Completer<ResponseBody>();
      h.reply = (o) => o.uri.queryParameters['status'] == 'all'
          ? old.future
          : h.defaultReply(o);
      final load = inbox.load();
      await Future<void>.delayed(Duration.zero);
      await inbox.filter('unread');
      old.complete(jsonReply({}, status: 500));
      await load;
      expect(inbox.status, 'unread');
      expect(inbox.items.length, 1);
      expect(inbox.error, isNull);
      final detail = NotificationDetailController(
        h.session,
        h.state.notifications,
        customerId,
      );
      addTearDown(detail.dispose);
      h.reply = null;
      await detail.load();
      expect(
        h.adapter.requests.where((o) => o.uri.path.endsWith('/read')),
        isEmpty,
      );
      h.reply = (o) => jsonReply({
        ...fixture('notifications', 'op-056'),
        'data': {
          ...fixture('notifications', 'op-056')['data'],
          'read_at': '2026-10-04T00:00:00Z',
        },
      });
      await detail.displayed();
      await detail.displayed();
      expect(
        h.adapter.requests.where((o) => o.uri.path.endsWith('/read')).length,
        1,
      );
      expect(h.state.shopInbox.unread, 0);
      expect(h.state.ticketInbox.items, isEmpty);
    },
  );
  for (final status in [401, 403, 404, 409, 422, 429, 500]) {
    test('Ticket handles HTTP $status without invented success', () async {
      final c = h.state.ticket();
      c.subject = 'Help';
      c.draft = 'Body';
      h.reply = (o) => jsonReply({}, status: status);
      await c.submit();
      expect(c.id, isNull);
      expect(c.events, isEmpty);
      if (status != 401) expect(c.error, isNotNull);
      if (status == 401) expect(h.session.active, isFalse);
    });
  }
}
