import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/communication_state.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/photo_controller.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

import '../support/account_fake.dart';
import '../support/commerce_harness.dart';
import '../support/communication_harness.dart';
import '../support/fakes.dart';

void main() {
  late CommerceHarness h;
  late CommunicationState communication;
  late PhotoController photo;
  late FakeAccountRepository account;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
    final messages = CommunicationHarness();
    h.reply = (r) => r.uri.path.contains('conversations')
        ? messages.defaultReply(r)
        : h.defaultReply(r);
    communication = CommunicationState(h.session, h.api);
    account = FakeAccountRepository();
    photo = PhotoController(h.session, account);
  });
  tearDown(() {
    photo.dispose();
    communication.dispose();
    h.dispose();
  });

  Future<void> switchTo(String id) async {
    await h.session.signOut();
    h.auth.identity = CustomerIdentity.parse(identityJson(id: id));
    h.auth.onLogin = () async => LoginResult.parse({
      'message': 'OK',
      'customer': identityJson(id: id),
      'token': 'synthetic-token',
    });
    await h.session.signIn('buyer@example.invalid', 'Synthetic123');
  }

  test(
    'consent recovery retains both uncertain intents but never replays writes',
    () async {
      final checkout = h.commerce.checkout;
      checkout.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
      await checkout.loadAddresses();
      await checkout.getQuote();
      await photo.load();
      final chat = communication.shopThread(shop: otherId)
        ..draft = 'Synthetic draft';
      final normal = h.reply!;
      h.reply = (r) => r.method == 'POST'
          ? throw DioException(
              requestOptions: r,
              type: DioExceptionType.receiveTimeout,
            )
          : normal(r);
      await checkout.place();
      await chat.send();
      final placement = checkout.pending!, message = chat.pending!;
      final writes = h.adapter.requests.where((r) => r.method == 'POST').length;
      expect(writes, 3); // One quote, one placement, one first message.

      h.policies.consent = ConsentStatus.parse(consentJson(required: true));
      await h.session.refreshConsent();
      expect(h.session.customer!.id, customerId);
      expect(h.session.active, isFalse);
      expect(photo.bytes, isNull);
      expect(h.commerce.cart.cart, isNull);
      expect(checkout.quote, isNull);
      expect(chat.draft, isEmpty);
      expect(chat.messages, isEmpty);
      expect(identical(checkout.pending, placement), isTrue);
      expect(identical(chat.pending, message), isTrue);
      await checkout.retryPending();
      await chat.retry();
      expect(
        h.adapter.requests.where((r) => r.method == 'POST').length,
        writes,
      );

      h.policies.consent = ConsentStatus.parse(consentJson());
      await h.session.refreshConsent();
      await Future<void>.delayed(Duration.zero);
      expect(h.session.active, isTrue);
      expect(
        h.adapter.requests.where((r) => r.method == 'POST').length,
        writes,
      );
      expect(checkout.pending!.key, placement.key);
      expect(chat.pending!.key, message.key);

      await switchTo(otherId);
      expect(checkout.pending, isNull);
      expect(chat.pending, isNull);
      expect(chat.disposed, isTrue);
      expect(identical(communication.shopThread(shop: otherId), chat), isFalse);
      expect(photo.bytes, isNull);
      await switchTo(customerId);
      expect(checkout.pending, isNull);
      expect(communication.shopThread(shop: otherId).pending, isNull);
      expect(
        h.adapter.requests.where((r) => r.method == 'POST').length,
        writes,
      );
    },
  );

  test('revocation clears all composed features and ignores late photo/chat success', () async {
    await photo.load();
    final bytes = Completer<Uint8List>();
    account.onPhoto = () => bytes.future;
    final photoRead = photo.load();
    final chat = communication.shopThread(shop: otherId)
      ..draft = 'Late synthetic draft';
    final response = Completer<ResponseBody>();
    final normal = h.reply!;
    h.reply = (r) => r.method == 'POST' && r.uri.path.contains('conversations')
        ? response.future
        : normal(r);
    final send = chat.send();
    for (
      var i = 0;
      i < 20 && !h.adapter.requests.any((r) => r.method == 'POST');
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(chat.pending, isNotNull);
    h.commerce.checkout.begin(
      CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)),
    );
    await h.commerce.checkout.loadAddresses();
    await h.commerce.checkout.getQuote();

    h.session.verifiedLease!.onFailure(
      const ApiFailure(FailureKind.http, status: 401),
    );
    await Future<void>.delayed(Duration.zero);
    expect(h.session.customer, isNull);
    expect(photo.bytes, isNull);
    expect(h.commerce.cart.cart, isNull);
    expect(h.commerce.checkout.quote, isNull);
    expect(chat.pending, isNull);
    expect(chat.disposed, isTrue);
    await switchTo(otherId);
    bytes.complete(Uint8List.fromList([9, 8, 7]));
    response.complete(
      jsonReply(fixture('chat-messaging', 'op-058'), status: 201),
    );
    await Future.wait([photoRead, send]);
    expect(h.session.customer!.id, otherId);
    expect(photo.bytes, isNull);
    expect(chat.messages, isEmpty);
    expect(communication.shopThread(shop: otherId).messages, isEmpty);
    expect(h.commerce.checkout.result, isNull);
  });
}
