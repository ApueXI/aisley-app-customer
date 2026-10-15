import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/chat_media/draft_controller.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_thread_controller.dart';

import '../support/chat_media_fake.dart';
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

  for (final existing in [false, true]) {
    test(
      'discovery cannot retarget an uncertain ${existing ? 'reply' : 'start'} with images',
      () async {
        final mediaRepo = MediaFake();
        final media = ChatMediaDraftController(mediaRepo);
        final c = ShopThreadController(
          h.session,
          h.state.shops,
          media: media,
          entry: {
            'shop_id': otherId,
            'context_type': 'product',
            'context_id': customerId,
          },
        );
        addTearDown(c.dispose);
        var committed = false, writes = 0;
        h.reply = (r) {
          if (r.method == 'POST') {
            if (++writes == 1) {
              committed = true;
              throw DioException(
                requestOptions: r,
                type: DioExceptionType.receiveTimeout,
              );
            }
            return jsonReply(shopWrite(), status: 201);
          }
          if (r.uri.path.contains('/shops/')) {
            return jsonReply({
              'data': shopContext(
                conversation: existing || committed ? customerId : null,
              ),
            });
          }
          if (r.uri.path.endsWith('/messages')) {
            return jsonReply(fixture('chat-messaging', 'op-060'));
          }
          return jsonReply({'data': shopSummary()});
        };
        await c.load();
        await media.add(c.mediaContext);
        expect(
          mediaRepo.contexts.single,
          existing
              ? {'conversation_id': customerId}
              : {
                  'channel': 'shop',
                  'shop_id': otherId,
                  'context_type': 'product',
                  'context_id': customerId,
                },
        );
        c.draft = 'Original caption';
        await c.send();
        final record = c.pending!;
        final first = h.adapter.requests.last;
        expect(record.uncertain, isTrue);
        await c.load();
        expect(c.id, existing ? customerId : null);
        expect(c.pending, same(record));
        expect(media.locked, isTrue);
        expect(record.body['attachment_ids'], [assetId]);

        h.policies.consent = ConsentStatus.parse(consentJson(required: true));
        await h.session.refreshConsent();
        expect(c.context, isNull);
        expect(c.shop, isNull);
        expect(c.messages, isEmpty);
        expect(media.items, isEmpty);
        expect(c.pending, same(record));
        h.policies.consent = ConsentStatus.parse(consentJson());
        await h.session.refreshConsent();
        expect(writes, 1);
        await c.load();
        c.draft = 'New text must not alter the original';
        await c.send();
        expect(writes, 1);
        await c.retry();
        expect(writes, 2);
        final replay = h.adapter.requests.last;
        expect(replay.uri, first.uri);
        expect(replay.data, first.data);
        expect(
          replay.headers['Idempotency-Key'],
          first.headers['Idempotency-Key'],
        );
        expect(c.pending, isNull);
        expect(c.id, customerId);
        expect(c.messages.length, 1);
        expect(c.draft, isEmpty);
      },
    );
  }
  for (final stage in ['context', 'detail', 'history']) {
    for (final error in [false, true]) {
      test(
        'late $stage ${error ? 'denial' : 'success'} cannot cross accounts',
        () async {
          final c = h.state.shopThread(shop: otherId);
          final response = Completer<ResponseBody>();
          final started = Completer<void>();
          h.reply = (r) {
            final at = r.uri.path.contains('/shops/')
                ? 'context'
                : r.uri.path.endsWith('/messages')
                ? 'history'
                : 'detail';
            if (at == stage) {
              if (!started.isCompleted) started.complete();
              return response.future;
            }
            return jsonReply({
              'data': at == 'context'
                  ? shopContext(conversation: customerId)
                  : shopSummary(),
            });
          };
          final load = c.load();
          await started.future;
          await h.session.signOut();
          h.auth.identity = CustomerIdentity.parse(identityJson(id: otherId));
          h.auth.onLogin = () async => LoginResult.parse({
            'message': 'OK',
            'customer': identityJson(id: otherId),
            'token': 'synthetic-new-account',
          });
          await h.session.signIn('buyer@example.invalid', 'Synthetic123');
          response.complete(
            error
                ? jsonReply({'code': 'ACCOUNT_SUSPENDED'}, status: 403)
                : jsonReply(
                    stage == 'history'
                        ? fixture('chat-messaging', 'op-060')
                        : {
                            'data': stage == 'context'
                                ? shopContext(conversation: customerId)
                                : shopSummary(),
                          },
                  ),
          );
          await load;
          expect(h.session.active, isTrue);
          expect(h.session.customer!.id, otherId);
          expect(c.disposed, isTrue);
          expect(c.shop, isNull);
          expect(c.messages, isEmpty);
          final current = h.state.shopThread(shop: otherId);
          expect(current, isNot(same(c)));
          expect(current.context, isNull);
          expect(current.conversation, isNull);
          expect(current.error, isNull);
          expect(current.canSend, isFalse);
        },
      );
    }
  }
  test(
    'consent interrupts discovery and requires an explicit fresh load',
    () async {
      final c = h.state.shopThread(shop: otherId);
      final response = Completer<ResponseBody>();
      h.reply = (_) => response.future;
      final load = c.load();
      await Future<void>.delayed(Duration.zero);
      h.policies.consent = ConsentStatus.parse(consentJson(required: true));
      await h.session.refreshConsent();
      response.complete(
        jsonReply({'data': shopContext(conversation: customerId)}),
      );
      await load;
      expect(c.context, isNull);
      expect(c.canSend, isFalse);
      expect(c.id, isNull);
      final count = h.adapter.requests.length;
      h.policies.consent = ConsentStatus.parse(consentJson());
      await h.session.refreshConsent();
      expect(h.adapter.requests.length, count);
      h.reply = (_) => jsonReply({'data': shopContext()});
      await c.load();
      expect(c.canSend, isTrue);
    },
  );
  for (final response in ['401', 'account-denied', 'consent-required']) {
    test('$response discovery respects the central session gate', () async {
      final c = h.state.shopThread(shop: otherId);
      if (response == 'consent-required') {
        h.policies.consent = ConsentStatus.parse(consentJson(required: true));
      }
      h.reply = (_) => jsonReply({
        if (response != '401')
          'code': response == 'account-denied'
              ? 'ACCOUNT_SUSPENDED'
              : 'POLICY_CONSENT_REQUIRED',
      }, status: response == '401' ? 401 : 403);
      await c.load();
      await Future<void>.delayed(Duration.zero);
      expect(h.session.active, isFalse);
      expect(c.context, isNull);
      expect(c.conversation, isNull);
      expect(c.canSend, isFalse);
      expect(h.session.customer != null, response == 'consent-required');
    });
  }
  test('uncertain conflict cannot abandon its key after context discovers a thread', () async {
    final c = h.state.shopThread(shop: otherId);
    var writes = 0;
    h.reply = (r) {
      if (r.method != 'POST') {
        return jsonReply({
          'data': shopContext(conversation: writes > 0 ? customerId : null),
        });
      }
      if (++writes == 1) {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return jsonReply({}, status: 409);
    };
    await c.load();
    c.draft = 'Frozen';
    await c.send();
    final record = c.pending!;
    await c.load();
    await c.retry();
    c.reviewConflict();
    expect(c.conflict, isTrue);
    expect(c.pending, same(record));
    expect(c.id, isNull);
  });
  for (final existing in [false, true]) {
    test(
      'definitive start conflict requires review before ${existing ? 'discovered reply' : 'new attempt'}',
      () async {
        final c = h.state.shopThread(shop: otherId);
        var writes = 0;
        h.reply = (r) {
          if (r.method == 'POST') {
            return ++writes == 1
                ? jsonReply({}, status: 409)
                : jsonReply(shopWrite(), status: 201);
          }
          if (r.uri.path.contains('/shops/')) {
            return jsonReply({
              'data': shopContext(
                conversation: existing && writes > 0 ? customerId : null,
              ),
            });
          }
          if (r.uri.path.endsWith('/messages')) {
            return jsonReply(fixture('chat-messaging', 'op-060'));
          }
          return jsonReply({'data': shopSummary()});
        };
        await c.load();
        c.draft = 'Review before retrying';
        await c.send();
        final key = c.pending!.key;
        expect(c.conflict, isTrue);
        expect(c.pending!.uncertain, isFalse);
        expect(c.id, existing ? customerId : null);
        expect(writes, 1);
        c.reviewConflict();
        expect(c.conflict, isFalse);
        expect(c.pending, isNull);
        expect(writes, 1);
        await c.send();
        expect(writes, 2);
        final post = h.adapter.requests.last;
        expect(post.headers['Idempotency-Key'], isNot(key));
        expect(
          post.uri.path,
          existing
              ? '/api/v1/customer/conversations/$customerId/messages'
              : '/api/v1/customer/conversations',
        );
      },
    );
  }
  test(
    'discovered thread retains cursor and serialized read behavior',
    () async {
      final c = h.state.shopThread(shop: otherId);
      var reads = 0;
      h.reply = (r) {
        if (r.uri.path.contains('/shops/')) {
          return jsonReply({'data': shopContext(conversation: customerId)});
        }
        if (r.uri.path.endsWith('/read')) {
          reads++;
          expect(r.data, {'sequence': 1});
        }
        if (r.uri.path.endsWith('/messages')) {
          final history = fixture('chat-messaging', 'op-060');
          history['next_cursor'] = r.uri.queryParameters['cursor'] == null
              ? 'older'
              : null;
          return jsonReply(history);
        }
        return jsonReply({
          'data': shopSummary()..['last_read_sequence'] = reads,
        });
      };
      await c.load();
      await c.displayed(1);
      await c.displayed(1);
      expect(reads, 1);
      expect(c.trail.next, 'older');
      await c.load(more: true);
      expect(h.adapter.requests.last.uri.queryParameters['cursor'], 'older');
      expect(c.trail.next, isNull);
      expect(c.messages.length, 1);
      expect(
        h.adapter.requests.where((r) => r.uri.path.contains('/shops/')).length,
        1,
      );
    },
  );
  test('wrong-Shop send response stays unconfirmed without adopting its transcript', () async {
    final c = h.state.shopThread(shop: otherId);
    h.reply = (r) => r.method == 'GET'
        ? jsonReply({'data': shopContext()})
        : jsonReply(shopWrite(shop: customerId), status: 201);
    await c.load();
    c.draft = 'Check scope';
    await c.send();
    expect(c.pending!.uncertain, isTrue);
    expect(c.messages, isEmpty);
    expect(c.conversation, isNull);
    expect(c.id, isNull);
  });
}
