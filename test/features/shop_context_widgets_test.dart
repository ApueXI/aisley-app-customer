import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_screens.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_thread_controller.dart';

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

  Future<void> show(
    WidgetTester tester,
    ShopThreadController c, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dependencies = h.dependencies();
    addTearDown(dependencies.discovery!.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ShopThreadScreen(dependencies: dependencies, controller: c),
      ),
    );
  }

  Finder getSend() => find.widgetWithText(FilledButton, 'Send message');

  testWidgets('initial discovery shows loading and disables the composer', (
    tester,
  ) async {
    final response = Completer<ResponseBody>();
    h.reply = (_) => response.future;
    await show(tester, h.state.shopThread(shop: otherId));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    response.complete(jsonReply({'data': shopContext()}));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic Shop'), findsOneWidget);
    expect(find.text('Shop available'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(h.adapter.requests.map((r) => r.method), everyElement('GET'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'discovery failure has refresh recovery without an enabled send',
    (tester) async {
      h.reply = (_) => jsonReply({}, status: 503);
      await show(tester, h.state.shopThread(shop: otherId));
      await tester.pumpAndSettle();
      expect(
        find.text('The service is unavailable. Please retry.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(getSend()).onPressed, isNull);
      h.reply = (_) => jsonReply({'data': shopContext()});
      await tester.tap(find.byTooltip('Refresh conversation'));
      await tester.pumpAndSettle();
      expect(find.text('Shop available'), findsOneWidget);
      expect(tester.widget<FilledButton>(getSend()).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final existing in [false, true]) {
    testWidgets(
      'vacation ${existing ? 'reply stays available' : 'generic start explains restriction'}',
      (tester) async {
        h.reply = (r) {
          if (r.uri.path.contains('/shops/')) {
            return jsonReply({
              'data': shopContext(
                conversation: existing ? customerId : null,
                availability: 'vacation',
                allowed: false,
              ),
            });
          }
          if (r.uri.path.endsWith('/messages')) {
            return jsonReply(fixture('chat-messaging', 'op-060'));
          }
          if (r.uri.path.endsWith('/read')) {
            return jsonReply({'data': shopSummary(availability: 'vacation')});
          }
          return jsonReply({'data': shopSummary(availability: 'vacation')});
        };
        await show(tester, h.state.shopThread(shop: otherId));
        await tester.pumpAndSettle();
        expect(find.text('Shop on vacation'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          existing,
        );
        if (!existing) {
          expect(
            find.textContaining('Try again when it is available.'),
            findsOneWidget,
          );
        }
        expect(
          h.adapter.requests.where(
            (r) => r.method == 'POST' && !r.uri.path.endsWith('/read'),
          ),
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('prospective refresh preserves focused input and its draft', (
    tester,
  ) async {
    h.reply = (_) => jsonReply({'data': shopContext()});
    final c = h.state.shopThread(shop: otherId);
    await show(tester, c);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep my draft');
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.focusNode!.hasFocus, isTrue);
    final load = c.load();
    await tester.pumpAndSettle();
    await load;
    expect(input.focusNode!.hasFocus, isTrue);
    expect(c.draft, 'Keep my draft');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [320.0, 390.0, 600.0, 800.0, 1024.0, 1440.0]) {
    testWidgets('availability and composer fit width $width at doubled text', (
      tester,
    ) async {
      h.reply = (r) => r.uri.path.contains('/shops/')
          ? jsonReply({'data': shopContext()})
          : h.defaultReply(r);
      await show(
        tester,
        h.state.shopThread(shop: otherId),
        size: Size(width, 844),
        scale: 2,
      );
      await tester.pumpAndSettle();
      expect(find.text('Shop available'), findsOneWidget);
      await tester.ensureVisible(getSend());
      expect(tester.widget<FilledButton>(getSend()).onPressed, isNotNull);
      final rect = tester.getRect(getSend());
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
