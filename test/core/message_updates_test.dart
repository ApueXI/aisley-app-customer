import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aisley_mobile_buyer/app/message_updates.dart';
import 'package:aisley_mobile_buyer/features/messaging/data/conversation_preview.dart';
import 'package:aisley_mobile_buyer/core/ui/marketplace_chrome.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_screens.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';
import '../support/message_fixtures.dart';

void main() {
  late CommunicationHarness h;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
    h.reply = (o) => jsonReply(inboxPage(channelFor(o)));
  });
  tearDown(() => h.dispose());

  Future<GoRouter> show(
    WidgetTester tester, {
    bool channelInbox = false,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => channelInbox
              ? ShopInboxScreen(dependencies: h.dependencies())
              : const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/cart',
          builder: (_, _) => const Scaffold(body: Text('Cart')),
        ),
        GoRoute(
          path: '/policies/terms_of_service',
          builder: (_, _) => const Scaffold(body: Text('Terms')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => MarketplaceScope(
          active: true,
          cartCount: null,
          chatUpdatesManaged: true,
          child: MessageUpdates(
            messages: h.state.messages,
            router: router,
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'one scheduler polls every 15 seconds, pauses background and policy routes',
    (tester) async {
      var unread = 1;
      h.reply = (o) => jsonReply(inboxPage(channelFor(o), unread: unread));
      final router = await show(tester);
      expect(h.adapter.requests, hasLength(3));
      expect(h.state.messages.unread, 3);
      unread = 2;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(h.adapter.requests, hasLength(6));
      expect(h.state.messages.unread, 6);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(h.state.messages.unread, isNull);
      await tester.pump(const Duration(seconds: 45));
      expect(h.adapter.requests, hasLength(6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.adapter.requests, hasLength(9));
      router.push('/policies/terms_of_service');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(h.adapter.requests, hasLength(9));
      router.pop();
      await tester.pumpAndSettle();
      expect(h.adapter.requests, hasLength(12));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(h.adapter.requests, hasLength(12));
    },
  );

  testWidgets(
    'a confirmed channel change refreshes only that channel immediately',
    (tester) async {
      await show(tester);
      h.state.messages.invalidate(MessageChannel.shop);
      await tester.pumpAndSettle();
      expect(h.adapter.requests, hasLength(4));
      expect(channelFor(h.adapter.requests.last), 'shop');
      expect(h.state.messages.unread, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('mounted channel inbox does not add another polling stream', (
    tester,
  ) async {
    await show(tester, channelInbox: true);
    final initial = h.adapter.requests.length;
    expect(initial, 3);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(h.adapter.requests, hasLength(initial + 3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'offline channels use bounded automatic reads and reconnect without refresh',
    (tester) async {
      h.reply = (o) => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      );
      await show(tester);
      final initial = h.adapter.requests.length;
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();
      expect(h.adapter.requests, hasLength(initial));
      h.reply = (o) => jsonReply(inboxPage(channelFor(o), unread: 0));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(h.state.messages.unread, 0);
      expect(h.adapter.requests, hasLength(initial + 3));
      expect(
        h.adapter.requests.where((request) => request.method != 'GET'),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'consent and sign-out stop polling and discard private snapshots',
    (tester) async {
      await show(tester);
      h.policies.consent = ConsentStatus.parse(consentJson(required: true));
      final consent = h.session.refreshConsent();
      await tester.pumpAndSettle();
      await consent;
      final initial = h.adapter.requests.length;
      expect(h.state.messages.conversations(), isEmpty);
      await tester.pump(const Duration(seconds: 30));
      expect(h.adapter.requests, hasLength(initial));
      final logout = h.session.signOut();
      await tester.pumpAndSettle();
      await logout;
      await tester.pump(const Duration(seconds: 30));
      expect(h.adapter.requests, hasLength(initial));
      expect(h.state.messages.hasSnapshot, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
