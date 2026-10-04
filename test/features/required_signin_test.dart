import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aisley_mobile_buyer/app/router.dart';
import 'package:aisley_mobile_buyer/app/router_guard.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/saved/data/legacy_recent_cleanup.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';

void main() {
  testWidgets('invalid shell filters keep one scrollable viewport owner', (
    tester,
  ) async {
    final h = CommerceHarness();
    await tester.runAsync(h.initialize);
    final requestCount = h.adapter.requests.length;
    final d = h.dependencies();
    addTearDown(d.dispose);
    final router = buyerRouter(d);
    addTearDown(router.dispose);
    router.go('/shops?unsupported=true');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 360);
    tester.view.viewInsets = const FakeViewPadding(bottom: 120);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: buyerTheme(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('This destination is unavailable.'), findsOneWidget);
    final action = find.widgetWithText(TextButton, 'Continue');
    await tester.ensureVisible(action);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    expect(h.adapter.requests, hasLength(requestCount));
  });

  testWidgets(
    'shopping deep links mount/fetch only after me and consent; no guest merge/write',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        legacyRecentKey: ['retired'],
        'keep': true,
      });
      final h = CommerceHarness();
      await tester.runAsync(() => h.initialize(active: false));
      final d = h.dependencies();
      addTearDown(d.dispose);
      final router = buyerRouter(d);
      addTearDown(router.dispose);
      router.go('/products/$customerId');
      await tester.pumpWidget(
        MaterialApp.router(theme: buyerTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(h.adapter.requests, isEmpty);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byTooltip('Cancel'), findsNothing);
      final me = Completer<void>();
      h.auth.onMe = (_) async {
        await me.future;
        return h.auth.identity;
      };
      h.policies.consent = ConsentStatus.parse(consentJson(required: true));
      await tester.enterText(
        find.byType(TextFormField).first,
        'buyer@example.invalid',
      );
      await tester.enterText(find.byType(TextFormField).last, 'Synthetic123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.adapter.requests, isEmpty);
      expect(find.byType(NavigationBar), findsNothing);
      me.complete();
      await tester.pumpAndSettle();
      expect(find.text('Review required policies'), findsOneWidget);
      expect(find.text('Public Home'), findsNothing);
      expect(find.byTooltip('Cancel'), findsNothing);
      expect(h.adapter.requests, isEmpty);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Accept this version'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/products/$customerId',
      );
      expect(
        h.adapter.requests.where(
          (r) => r.uri.path == '/api/v1/products/$customerId',
        ),
        hasLength(1),
      );
      expect(
        h.adapter.requests.where(
          (r) =>
              r.uri.path.endsWith('/merge') || r.uri.path.endsWith('/resolve'),
        ),
        isEmpty,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList(legacyRecentKey), [
        'retired',
      ]); // No guest writing by detail.
      await h.session.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(NavigationBar), findsNothing);
      final before = h.adapter.requests.length;
      for (final route in [
        '/',
        '/shops',
        '/search?q=sample',
        '/products/$customerId/questions',
        '/products/$customerId/reviews',
        '/orders',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(h.adapter.requests.length, before);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'restoration consent failure remains retryable then opens required policy gate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final h = CommerceHarness();
      await tester.runAsync(() => h.initialize(active: false));
      final d = h.dependencies();
      addTearDown(d.dispose);
      final router = buyerRouter(d);
      addTearDown(router.dispose);
      h.policies.onStatus = () async =>
          throw const ApiFailure(FailureKind.offline);
      await tester.runAsync(
        () => h.session.signIn('buyer@example.invalid', 'Synthetic123'),
      );
      router.go('/search?q=sample&mode=products');
      await tester.pumpWidget(
        MaterialApp.router(theme: buyerTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Checking your session'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(h.adapter.requests, isEmpty);
      h.policies.onStatus = null;
      h.policies.consent = ConsentStatus.parse(consentJson(required: true));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Review required policies'), findsOneWidget);
      expect(h.session.customer, isNotNull);
      expect(h.adapter.requests, isEmpty);
      expect(
        guardRoute(h.session, Uri.parse('/login?returnTo=%2Fshops')),
        '/consent?returnTo=%2Fshops',
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('every shopping route fails closed across checking, recoverable and consent phases', () async {
    final session = SessionController(
      FakeAuth(),
      FakePolicies(),
      MemoryTokenStore(),
    );
    addTearDown(session.dispose);
    for (final phase in SessionPhase.values.where(
      (p) => p != SessionPhase.active,
    )) {
      session.phase = phase;
      for (final path in [
        '/',
        '/shops',
        '/search',
        '/products/$customerId',
        '/products/$customerId/questions',
        '/products/$customerId/reviews',
        '/cart',
        '/account',
      ]) {
        expect(
          guardRoute(session, Uri.parse(path)),
          isNotNull,
          reason: '$phase $path',
        );
      }
      expect(guardRoute(session, Uri.parse('/register')), isNull);
      expect(
        guardRoute(session, Uri.parse('/policies/privacy_policy')),
        isNull,
      );
    }
    for (final path in [
      '/support-tickets/new',
      '/messages/shops/new/$customerId',
      '/order-items/$customerId/review/$otherId',
      '/checkout?place=true',
    ]) {
      expect(safeReturn(path), '/');
    }
  });
}
