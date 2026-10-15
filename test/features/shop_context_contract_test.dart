import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/data/shop_models.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';
import '../support/shop_context_fixtures.dart';

void main() {
  final decodeFailure = isA<ApiFailure>().having(
    (e) => e.kind,
    'kind',
    FailureKind.decode,
  );
  for (final availability in ['online', 'offline', 'vacation']) {
    test('context and summary retain $availability business status', () {
      final context = ShopChatContext.parse(
        shopContext(
          conversation: customerId,
          availability: availability,
          allowed: false,
        ),
      );
      final summary = ShopConversation.parse(
        shopSummary(availability: availability, allowed: true),
      );
      expect(context.shop.availability.name, availability);
      expect(context.shop.id, otherId);
      expect(context.shop.name, 'Synthetic Shop');
      expect(context.shop.slug, isNull);
      expect(context.conversationId, customerId);
      expect(context.sendAllowed, isFalse);
      expect(summary.shop.availability, context.shop.availability);
      expect(summary.sendAllowed, isTrue);
    });
  }
  test('prospective context has an explicit nullable conversation ID', () {
    expect(ShopChatContext.parse(shopContext()).conversationId, isNull);
    expect(
      () => ShopChatContext.parse(shopContext()..remove('conversation_id')),
      throwsA(decodeFailure),
    );
  });
  test('unknown availability remains distinct from online', () {
    final value = ShopChatContext.parse(
      shopContext(availability: 'new-status'),
    );
    expect(value.shop.availability, ShopAvailability.unknown);
    expect(value.shop.availability.label, 'Shop availability unavailable');
  });
  for (final entry in <String, Object?>{
    'shop': null,
    'conversation_id': 'not-a-uuid',
    'send_allowed': null,
  }.entries) {
    test('context rejects malformed ${entry.key}', () {
      expect(
        () => ShopChatContext.parse({...shopContext(), entry.key: entry.value}),
        throwsA(decodeFailure),
      );
    });
  }
  for (final field in ['id', 'name', 'slug', 'availability']) {
    test('both projections reject missing required Shop $field', () {
      final raw = shopContext();
      (raw['shop'] as Map).remove(field);
      expect(() => ShopChatContext.parse(raw), throwsA(decodeFailure));
      expect(
        () => ShopConversation.parse({...shopSummary(), 'shop': raw['shop']}),
        throwsA(decodeFailure),
      );
    });
  }
  test('availability must be a string', () {
    final raw = shopContext();
    raw['shop']['availability'] = null;
    expect(() => ShopChatContext.parse(raw), throwsA(decodeFailure));
  });
  test('context GET uses exact authenticated read contract', () async {
    final h = CommunicationHarness();
    await h.initialize();
    addTearDown(h.dispose);
    h.reply = (_) => jsonReply({'data': shopContext()});
    final result = await h.state.shops.context(
      h.session.verifiedLease!,
      otherId,
    );
    expect(result.conversationId, isNull);
    final request = h.adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/customer/conversations/shops/$otherId');
    expect(request.uri.query, isEmpty);
    expect(request.data, isNull);
    expect(request.headers['Authorization'], 'Bearer synthetic-token');
    expect(request.headers.containsKey('Idempotency-Key'), isFalse);
    await expectLater(
      h.state.shops.context(h.session.verifiedLease!, 'invalid'),
      throwsA(decodeFailure),
    );
    expect(h.adapter.requests.length, 1);
  });
  test('context rejects another Shop and wrong envelopes', () async {
    final h = CommunicationHarness();
    await h.initialize();
    addTearDown(h.dispose);
    for (final response in [
      {'data': shopContext(shop: customerId)},
      shopContext(),
      {'data': []},
    ]) {
      h.reply = (_) => jsonReply(response);
      await expectLater(
        h.state.shops.context(h.session.verifiedLease!, otherId),
        throwsA(decodeFailure),
      );
    }
  });
}
