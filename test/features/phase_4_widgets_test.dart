import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/router.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/ui/foreground_poll.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_screens.dart';
import 'package:aisley_mobile_buyer/features/questions/presentation/questions_screen.dart';
import 'package:aisley_mobile_buyer/features/reviews/presentation/reviews_screen.dart';
import 'package:aisley_mobile_buyer/features/reviews/presentation/review_composer_screen.dart';
import 'package:aisley_mobile_buyer/features/notifications/presentation/notification_screens.dart';
import 'package:aisley_mobile_buyer/features/support/presentation/support_screens.dart';

import '../support/fakes.dart';
import '../support/communication_harness.dart';

void main() {
  late CommunicationHarness h;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());
  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(320, 640),
    double scale = 2,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Q&A and reviews remain public at doubled text with loading and official content',
    (tester) async {
      await show(
        tester,
        QuestionsScreen(dependencies: h.dependencies(), product: customerId),
      );
      expect(find.text('Synthetic product question'), findsOneWidget);
      expect(find.text('Awaiting an official Seller answer.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await show(
        tester,
        ReviewsScreen(dependencies: h.dependencies(), product: customerId),
      );
      expect(find.text('5.0 · 1 reviews'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Verified purchase'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Verified purchase'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Public question composer follows sign-in and clears on account loss',
    (tester) async {
      await h.session.signOut();
      await show(
        tester,
        QuestionsScreen(dependencies: h.dependencies(), product: customerId),
        scale: 1,
      );
      expect(find.text('Sign in to ask a question'), findsOneWidget);
      final login = h.session.signIn('buyer@example.invalid', 'Synthetic1');
      await tester.pumpAndSettle();
      await login;
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(
        find.byType(TextFormField),
        'Private unsent draft',
      );
      final logout = h.session.signOut();
      await tester.pumpAndSettle();
      await logout;
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Private unsent draft'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Narrow keyboard ticket create uses Description, focuses required subject',
    (tester) async {
      await show(
        tester,
        TicketComposerScreen(
          dependencies: h.dependencies(),
          controller: h.state.ticket(),
        ),
        size: const Size(320, 560),
        keyboard: 180,
      );
      final button = find.widgetWithText(FilledButton, 'Create ticket');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Enter a value.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Description'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Read-only message thread exposes reason and has no enabled send',
    (tester) async {
      await show(
        tester,
        ShopThreadScreen(
          dependencies: h.dependencies(),
          controller: h.state.shopThread(id: customerId),
        ),
      );
      expect(find.textContaining('Read only.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Send message'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send message'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'First composer Back confirms discard, and opening sends no request',
    (tester) async {
      final c = h.state.shopThread(shop: otherId);
      await show(
        tester,
        ShopThreadScreen(dependencies: h.dependencies(), controller: c),
        scale: 1,
      );
      expect(h.adapter.requests.where((o) => o.method == 'POST'), isEmpty);
      await tester.enterText(
        find.byType(TextFormField),
        'Unsent synthetic draft',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Leave this screen?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('Unsent synthetic draft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Incoming message cue preserves input focus and older scroll offset',
    (tester) async {
      final c = h.state.shopThread(id: customerId),
          data = fixture('chat-messaging', 'op-060'),
          row =
              fixture('chat-messaging', 'op-060')['items'][0]
                  as Map<String, dynamic>;
      var loads = 0;
      h.reply = (o) {
        if (o.uri.path.endsWith('/messages')) {
          loads++;
          return jsonReply({
            ...data,
            'items': [
              for (var i = 1; i <= (30 + loads - 1); i++)
                {
                  ...row,
                  'id':
                      '${i.toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
                  'sequence': i,
                  'mine': false,
                  'body': 'Synthetic message $i',
                },
            ],
          });
        }
        final summary = fixture(
          'chat-messaging',
          o.uri.path.endsWith('/read') ? 'op-062' : 'op-059',
        );
        summary['data']['send_allowed'] = true;
        summary['data']['last_read_sequence'] = 30;
        return jsonReply(summary);
      };
      await show(
        tester,
        ShopThreadScreen(dependencies: h.dependencies(), controller: c),
        scale: 1,
      );
      final list = tester.widget<ListView>(find.byType(ListView));
      final scroll = list.controller!;
      await tester.scrollUntilVisible(
        find.byType(TextFormField),
        300,
        maxScrolls: 50,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'Keep focus');
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
      final focusedRefresh = c.load();
      await tester.pumpAndSettle();
      await focusedRefresh;
      expect(field.focusNode!.hasFocus, isTrue);
      scroll.jumpTo(400);
      await tester.pump();
      final refresh = c.load();
      await tester.pumpAndSettle();
      await refresh;
      expect(scroll.offset, 400);
      expect(c.arrivals, greaterThan(0));
      scroll.jumpTo(0);
      await tester.pump();
      expect(find.textContaining('new messages · View'), findsOneWidget);
      expect(c.draft, 'Keep focus');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Visible-only foreground polling pauses offline/background and resumes',
    (tester) async {
      var count = 0;
      var offline = false;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await show(
        tester,
        ForegroundPoll(
          refresh: () async {
            count++;
          },
          paused: () => offline,
          child: Scaffold(body: TextField(focusNode: focus)),
        ),
        scale: 1,
      );
      final initial = count;
      await tester.pump(const Duration(seconds: 15));
      expect(count, initial + 1);
      offline = true;
      await tester.pump(const Duration(seconds: 30));
      expect(count, initial + 1);
      focus.requestFocus();
      await tester.pump();
      expect(count, initial + 2);
      focus.unfocus();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      offline = false;
      await tester.pump(const Duration(seconds: 30));
      expect(count, initial + 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(count, initial + 3);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Notification read is sent after successful display only', (
    tester,
  ) async {
    await show(
      tester,
      NotificationDetailScreen(dependencies: h.dependencies(), id: customerId),
      scale: 1,
    );
    expect(
      h.adapter.requests
          .where((o) => o.method == 'POST' && o.uri.path.endsWith('/read'))
          .length,
      1,
    );
    expect(find.text('Synthetic example'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Review composer keeps separate text and photo work in a short layout',
    (tester) async {
      await show(
        tester,
        ReviewComposerScreen(
          dependencies: h.dependencies(),
          controller: h.state.review(customerId, otherId),
        ),
        size: const Size(320, 560),
        keyboard: 180,
      );
      expect(find.text('Rating'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'New private routes fail closed for guests before constructing feature screens',
    (tester) async {
      await h.session.signOut();
      final router = buyerRouter(h.dependencies());
      addTearDown(router.dispose);
      router.go('/messages/courier/order/$customerId');
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: buyerTheme()),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Sign in with your approved Buyer account.'),
        findsOneWidget,
      );
      for (final path in [
        '/notifications/$customerId',
        '/support-tickets/new',
        '/messages/logistics/$customerId',
        '/order-items/$customerId/review/$otherId',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(
          find.text('Sign in with your approved Buyer account.'),
          findsOneWidget,
        );
      }
      expect(
        h.adapter.requests.where((o) => o.uri.path.contains('/customer/')),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
