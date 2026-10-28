import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_screen.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';

void main() {
  for (final layout in [
    (size: const Size(320, 720), scale: 2.0),
    (size: const Size(1440, 900), scale: 1.0),
  ]) {
    for (final change in ['expired', 'replaced', 'unchanged']) {
      testWidgets('confirmation guards $change quote at $layout', (
        tester,
      ) async {
        final h = CommerceHarness();
        await tester.runAsync(h.initialize);
        final dependencies = h.dependencies();
        addTearDown(dependencies.dispose);
        final c = h.commerce.checkout;
        c.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
        tester.view.physicalSize = layout.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          initialLocation: '/checkout',
          routes: [
            GoRoute(
              path: '/checkout',
              builder: (_, _) => CheckoutScreen(dependencies: dependencies),
            ),
            GoRoute(
              path: '/checkout/result/:id',
              builder: (_, _) => const Scaffold(body: Text('Confirmed batch')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: buyerTheme(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(layout.scale)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Review order'));
        await tester.tap(find.text('Review order'));
        await tester.pumpAndSettle();
        expect(c.canPlace, isTrue);
        await tester.ensureVisible(find.text('Place COD order'));
        await tester.tap(find.text('Place COD order'));
        await tester.pumpAndSettle();
        expect(find.text('Place COD order?'), findsOneWidget);
        if (change == 'expired') {
          h.now = h.now.add(const Duration(minutes: 16));
        } else if (change == 'replaced') {
          // A refreshed quote may even reuse the synthetic ID. Confirmation must
          // be bound to the snapshot displayed, not merely a matching ID.
          await tester.runAsync(c.getQuote);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Place order'));
        await tester.pumpAndSettle();
        final writes = h.adapter.requests.where(
          (r) => r.uri.path.endsWith('/place'),
        );
        if (change == 'unchanged') {
          expect(writes, hasLength(1));
          expect(find.text('Confirmed batch'), findsOneWidget);
        } else {
          expect(writes, isEmpty);
          expect(h.keys, 0);
          expect(c.quote, isNull);
          expect(c.canPlace, isFalse);
          expect(
            find.textContaining('review changed or expired'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Place COD order'),
                )
                .onPressed,
            isNull,
          );
          await tester.ensureVisible(find.text('Review order'));
          await tester.tap(find.text('Review order'));
          await tester.pumpAndSettle();
          expect(c.canPlace, isTrue);
          expect(h.keys, 0);
        }
        expect(tester.takeException(), isNull);
        c.invalidateQuote();
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets(
      'uncertainty and throttle survive Orders navigation at $layout',
      (tester) async {
        final h = CommerceHarness();
        await tester.runAsync(h.initialize);
        final dependencies = h.dependencies();
        addTearDown(dependencies.dispose);
        final c = h.commerce.checkout;
        await tester.runAsync(() async {
          c.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
          await c.loadAddresses();
          await c.getQuote();
          h.reply = (r) => r.uri.path.endsWith('/place')
              ? throw DioException(
                  requestOptions: r,
                  type: DioExceptionType.receiveTimeout,
                )
              : h.defaultReply(r);
          await c.place();
          h.reply = (r) => r.uri.path.endsWith('/place')
              ? jsonReply(
                  {},
                  status: 429,
                  headers: {
                    'retry-after': ['60'],
                  },
                )
              : h.defaultReply(r);
          await c.retryPending();
        });
        final pending = c.pending;
        final count = h.adapter.requests.length;
        tester.view.physicalSize = layout.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          initialLocation: '/checkout',
          routes: [
            GoRoute(
              path: '/checkout',
              builder: (_, _) => CheckoutScreen(dependencies: dependencies),
            ),
            GoRoute(
              path: '/orders',
              builder: (_, _) => const Scaffold(body: Text('Orders list')),
            ),
          ],
        );
        addTearDown(router.dispose);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp.router(
              theme: buyerTheme(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(layout.scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final wait = find.widgetWithText(
            FilledButton,
            'Wait before retrying',
          );
          expect(wait, findsOneWidget);
          expect(tester.widget<FilledButton>(wait).onPressed, isNull);
          expect(
            find.textContaining('earlier order is still unconfirmed'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Check Orders'));
          final check = find.widgetWithText(OutlinedButton, 'Check Orders');
          expect(tester.getSize(check).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(check).width, greaterThanOrEqualTo(48));
          expect(tester.getSemantics(check).label, contains('Check Orders'));
          await tester.tap(check);
          await tester.pumpAndSettle();
          expect(find.text('Orders list'), findsOneWidget);
          expect(c.pending, same(pending));
          router.pop();
          await tester.pumpAndSettle();
          expect(find.text('Wait before retrying'), findsOneWidget);
          expect(c.pending, same(pending));
          expect(h.adapter.requests, hasLength(count));
          expect(c.canPlace, isFalse);
          expect(tester.takeException(), isNull);
          c.invalidateQuote();
          await tester.pumpWidget(const SizedBox());
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
