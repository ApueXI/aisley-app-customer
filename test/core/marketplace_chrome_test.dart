import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/ui/responsive_layout.dart';

void main() {
  testWidgets(
    'header preserves focused search draft through desktop/mobile resizing and submits with the search action',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const ShoppingPage(body: Text('Home content')),
          ),
          GoRoute(
            path: '/search',
            builder: (_, state) => ShoppingPage(
              body: Text('Submitted: ${state.uri.queryParameters['q']}'),
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const ShoppingPage(body: Text('Authentication')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: buyerTheme(),
          routerConfig: router,
          builder: (context, child) => ValueListenableBuilder(
            valueListenable: active,
            builder: (_, allowed, _) =>
                MarketplaceScope(active: allowed, cartCount: 3, child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'AISLEY',
        'Shops',
        'Orders',
        'Cart (3)',
        'Account',
        'Notifications',
        'Shop messages',
        'Logistics messages',
        'Courier messages',
      ]) {
        expect(find.text(label), findsOneWidget);
        expect(
          tester.getSize(find.widgetWithText(TextButton, label)).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'linen shirt');
      final field = tester.widget<TextField>(find.byType(TextField));
      for (final width in [320.0, 600.0, 800.0, 1024.0, 1440.0, 390.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller,
          same(field.controller),
        );
        expect(field.controller!.text, 'linen shirt');
        expect(field.focusNode!.hasFocus, true);
        expect(router.routeInformationProvider.value.uri.path, '/');
      }
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Submitted: linen shirt'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'linen shirt',
      );
      active.value = false;
      router.go('/login');
      await tester.pumpAndSettle();
      expect(find.byType(MarketplaceHeader), findsNothing);
      expect(find.text('Authentication'), findsOneWidget);
      expect(find.text('Shop messages'), findsNothing);
    },
  );
  testWidgets('desktop falls back to stacked navigation when text cannot fit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: const Size(1024, 768),
            textScaler: TextScaler.linear(2),
          ),
          child: MarketplaceScope(active: true, cartCount: null, child: child!),
        ),
        home: const ShoppingPage(body: Text('Content')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarketplaceHeader>(find.byType(MarketplaceHeader)).desktop,
      false,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('header fits intermediate text sizes at desktop boundaries', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [1024.0, 1200.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      for (final scale in [1.01, 1.1, 1.25, 1.3]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buyerTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: MarketplaceScope(
                active: true,
                cartCount: 99,
                child: child!,
              ),
            ),
            home: const ShoppingPage(body: Text('Content')),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$width at text scale $scale',
        );
      }
    }
  });
  test('pink and purple buttons meet normal text contrast against white', () {
    final theme = buyerTheme();
    for (final color in [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
    ]) {
      final contrast =
          (Colors.white.computeLuminance() + .05) /
          (color.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    }
  });
}
