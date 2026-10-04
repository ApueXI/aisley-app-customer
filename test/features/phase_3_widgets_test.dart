import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/router.dart';
import 'package:aisley_mobile_buyer/app/router_guard.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/cart/presentation/cart_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_screen.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/order_detail_screen.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/orders_screen.dart';

import '../support/fakes.dart';
import '../support/commerce_harness.dart';

void main() {
  late CommerceHarness h;
  late AppDependencies dependencies;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    h = CommerceHarness();
    await h.initialize();
    dependencies = h.dependencies();
  });
  tearDown(() => dependencies.dispose());
  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(320, 720),
    bool large = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Cart selection estimates unavailable lines and 48px actions fit narrow doubled text',
    (tester) async {
      await show(tester, CartScreen(dependencies: dependencies));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byType(Checkbox), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(h.commerce.cart.selection, {customerId});
      await tester.scrollUntilVisible(find.text('Checkout selected (1)'), 200);
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Checkout selected (1)');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      h.commerce.checkout.invalidateQuote();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('checkout with no intent returns to Cart and cannot place', (
    tester,
  ) async {
    await show(tester, CheckoutScreen(dependencies: dependencies));
    expect(find.text('Return to Cart'), findsOneWidget);
    expect(find.text('Place COD order'), findsNothing);
    expect(
      h.adapter.requests.where((r) => r.uri.path.endsWith('/place')),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'shipping selection quote and COD review fit doubled text with explicit confirmation',
    (tester) async {
      h.commerce.checkout.begin(
        CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)),
      );
      await show(tester, CheckoutScreen(dependencies: dependencies));
      await tester.ensureVisible(find.text('Get current quote'));
      await tester.tap(find.text('Get current quote'));
      await tester.pumpAndSettle();
      expect(h.commerce.checkout.canPlace, true);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Place COD order'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Place COD order');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Place COD order?'), findsOneWidget);
      expect(
        h.adapter.requests.where((r) => r.uri.path.endsWith('/place')),
        isEmpty,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.commerce.checkout.pending, isNull);
      h.commerce.checkout.invalidateQuote();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'leaving uncertain checkout retains exact retry across real navigation',
    (tester) async {
      h.commerce.checkout.begin(
        CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)),
      );
      await tester.runAsync(() async {
        await h.commerce.checkout.loadAddresses();
        await h.commerce.checkout.getQuote();
        h.reply = (r) => r.uri.path.endsWith('/place')
            ? throw DioException(
                requestOptions: r,
                type: DioExceptionType.receiveTimeout,
              )
            : h.defaultReply(r);
        await h.commerce.checkout.place();
      });
      final key = h.commerce.checkout.pending!.key;
      final router = buyerRouter(dependencies);
      addTearDown(router.dispose);
      router.go('/checkout');
      await tester.pumpWidget(
        MaterialApp.router(theme: buyerTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry exact placement'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(h.commerce.checkout.pending!.key, key);
      router.go('/checkout');
      await tester.pumpAndSettle();
      expect(find.text('Retry exact placement'), findsOneWidget);
      expect(
        h.adapter.requests.where((r) => r.uri.path.endsWith('/place')),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      h.commerce.checkout.invalidateQuote();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Orders and snapshots fit narrow doubled text and cancellation preserves safe input until confirmed',
    (tester) async {
      await show(tester, OrdersScreen(dependencies: dependencies));
      expect(find.textContaining('ASL-SYNTHETIC'), findsOneWidget);
      expect(tester.takeException(), isNull);
      h.commerce.checkout.invalidateQuote();
      await tester.pumpWidget(const SizedBox());
      await show(
        tester,
        OrderDetailScreen(dependencies: dependencies, id: customerId),
      );
      await tester.scrollUntilVisible(find.text('Cancel Order'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel Order'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this Order?'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 450);
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField), 'Synthetic reason');
      await tester.pumpAndSettle();
      expect(
        h.adapter.requests.where((r) => r.uri.path.endsWith('/cancel')),
        isEmpty,
      );
      await tester.tap(find.text('Keep Order'));
      await tester.pumpAndSettle();
      expect(h.commerce.mutations.pending(customerId), isNull);
      h.commerce.checkout.invalidateQuote();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'guest commerce guards validate safe reads and never perform saved writes',
    (tester) async {
      await h.session.signOut();
      expect(safeReturn('/checkout'), '/cart');
      expect(safeReturn('/orders/$customerId'), '/orders/$customerId');
      expect(
        safeReturn('/checkout/result/$customerId'),
        '/checkout/result/$customerId',
      );
      expect(safeReturn('/orders/invalid'), '/account');
      expect(safeReturn('/checkout?buy_now=$customerId'), '/account');
      for (final path in [
        '/cart',
        '/checkout',
        '/orders',
        '/orders/$customerId',
        '/checkout/result/$customerId',
      ]) {
        expect(
          guardRoute(h.session, Uri.parse(path)),
          startsWith('/login?returnTo='),
        );
      }
      final router = buyerRouter(dependencies);
      addTearDown(router.dispose);
      router.go('/orders/$customerId');
      await tester.pumpWidget(
        MaterialApp.router(theme: buyerTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
      expect(h.adapter.requests.where((r) => r.method != 'GET'), isEmpty);
      h.commerce.checkout.invalidateQuote();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
