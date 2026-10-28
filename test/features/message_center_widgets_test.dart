import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/buyer_app.dart';
import 'package:aisley_mobile_buyer/app/router.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/ui/message_action.dart';
import 'package:aisley_mobile_buyer/core/ui/marketplace_chrome.dart';
import 'package:aisley_mobile_buyer/features/messaging/presentation/conversation_tile.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';
import '../support/message_fixtures.dart';

void main() {
  late CommunicationHarness h;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
    h.reply = (o) => o.uri.pathSegments.last.endsWith('conversations')
        ? jsonReply(
            inboxPage(channelFor(o), label: '${channelFor(o)} counterpart'),
          )
        : h.defaultReply(o);
  });
  tearDown(() => h.dispose());

  void resize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  for (final width in [320.0, 390.0, 600.0, 800.0, 1024.0, 1440.0]) {
    testWidgets('Home alone shows header search across navigation at $width', (
      tester,
    ) async {
      resize(tester, Size(width, 900));
      await tester.pumpWidget(BuyerApp(dependencies: h.dependencies()));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'linen shirt');
      final searchHeight = tester
          .getSize(find.byType(MarketplaceHeader))
          .height;
      for (final label in ['Home', 'Notifications', 'Account']) {
        final desktop = find.byType(NavigationBar).evaluate().isEmpty;
        final button = desktop
            ? find.widgetWithText(TextButton, label).first
            : find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(label),
              );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.byType(TextField),
          label == 'Home' ? findsOneWidget : findsNothing,
        );
        expect(find.byType(MessageAction), findsOneWidget);
        if (label == 'Home') {
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'linen shirt',
          );
        }
        expect(find.byTooltip('Terms and privacy'), findsOneWidget);
        if (!desktop && label != 'Home') {
          expect(
            tester.getSize(find.byType(MarketplaceHeader)).height,
            lessThan(searchHeight),
          );
        }
        expect(tester.takeException(), isNull);
      }
      final desktop = find.byType(NavigationBar).evaluate().isEmpty;
      await tester.tap(
        desktop
            ? find.widgetWithText(TextButton, 'Home').first
            : find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text('Home'),
              ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('messages-action')));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsNWidgets(3));
      expect(find.byType(TextField), findsNothing);
      expect(
        h.adapter.requests.where((o) => o.uri.path.endsWith('/read')),
        isEmpty,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(
        desktop
            ? find.widgetWithText(TextButton, 'Notifications').first
            : find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text('Notifications'),
              ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('Terms and privacy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Terms of Service'), findsWidgets);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final width in [320.0, 390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'combined inbox filters and opens channel threads at $width / $scale',
        (tester) async {
          resize(tester, Size(width, 900));
          final router = buyerRouter(h.dependencies());
          addTearDown(router.dispose);
          router.go('/messages');
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              theme: buyerTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final inboxScrollable = find
              .descendant(
                of: find.byKey(const PageStorageKey('combined-messages')),
                matching: find.byType(Scrollable),
              )
              .first;
          for (final entry in {
            'Shops': 'shops',
            'Logistics': 'logistics',
            'Courier': 'courier',
          }.entries) {
            final filter = find.widgetWithText(TextButton, entry.key);
            await tester.scrollUntilVisible(
              filter,
              -180,
              scrollable: inboxScrollable,
            );
            await tester.ensureVisible(filter);
            await tester.pumpAndSettle();
            await tester.tap(filter);
            await tester.pumpAndSettle();
            expect(find.byType(ConversationTile), findsOneWidget);
            expect(tester.getSize(filter).height, greaterThanOrEqualTo(48));
            final tile = find.byType(ConversationTile);
            await tester.ensureVisible(tile);
            await tester.pumpAndSettle();
            expect(find.text('Read only'), findsOneWidget);
            await tester.tap(tile);
            await tester.pumpAndSettle();
            expect(
              router.routerDelegate.currentConfiguration.last.matchedLocation,
              '/messages/${entry.value}/$customerId',
            );
            router.pop();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          final allFilter = find.widgetWithText(TextButton, 'All');
          await tester.scrollUntilVisible(
            allFilter,
            -180,
            scrollable: inboxScrollable,
          );
          await tester.ensureVisible(allFilter);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'All'));
          await tester.pumpAndSettle();
          expect(h.state.messages.conversations(), hasLength(3));
          for (final channel in ['shops', 'logistics', 'courier']) {
            final tile = find.byKey(ValueKey('$channel/$customerId'));
            await tester.scrollUntilVisible(tile, 180);
            expect(tile, findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'partial errors retain other conversations and retry the affected channel',
    (tester) async {
      var broken = true;
      h.reply = (o) => channelFor(o) == 'logistics' && broken
          ? jsonReply({}, status: 503)
          : jsonReply(inboxPage(channelFor(o)));
      final router = buyerRouter(h.dependencies());
      addTearDown(router.dispose);
      router.go('/messages');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsNWidgets(2));
      expect(find.text('No conversations yet.'), findsNothing);
      final before = h.adapter.requests
          .where((o) => channelFor(o) == 'shop')
          .length;
      broken = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsNWidgets(3));
      expect(
        h.adapter.requests.where((o) => channelFor(o) == 'shop'),
        hasLength(before),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'badge exposes totals, overflow, zero and unknown status accessibly',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final count in [0, 3, 120, null]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                appBar: AppBar(
                  actions: [
                    MessageAction(
                      unread: count,
                      stale: count == null,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.byKey(const ValueKey('messages-action'));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          expect(
            tester.widget<Badge>(find.byType(Badge)).isLabelVisible,
            count != 0,
          );
          if (count == 120) expect(find.text('99+'), findsOneWidget);
          final label = tester.getSemantics(button).getSemanticsData().tooltip;
          expect(
            label,
            contains(count == null ? 'may be outdated' : '$count unread'),
          );
        }
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );
}
