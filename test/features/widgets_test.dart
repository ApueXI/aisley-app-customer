import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/buyer_app.dart';
import 'package:aisley_mobile_buyer/app/router_guard.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/auth/presentation/login_screen.dart';
import 'package:aisley_mobile_buyer/features/auth/presentation/recovery_screen.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/policies/presentation/consent_screen.dart';
import 'package:aisley_mobile_buyer/features/policies/presentation/policy_reader_screen.dart';

import '../support/fakes.dart';

void main() {
  late FakeAuth auth;
  late FakePolicies policies;
  late MemoryTokenStore storage;
  late SessionController session;
  setUp(() {
    auth = FakeAuth();
    policies = FakePolicies();
    storage = MemoryTokenStore();
    session = SessionController(auth, policies, storage);
  });
  tearDown(() => session.dispose());
  testWidgets(
    'dirty sign-in cancellation confirms discard and returns to Home',
    (tester) async {
      final dependencies = AppDependencies(
        config: testConfig,
        auth: auth,
        policies: policies,
        session: session,
        launcher: TrustedLauncher(testConfig),
      );
      await tester.pumpWidget(BuyerApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'buyer@example.invalid',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.text('Discard the information entered in this form?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to AISLEY'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'login labels, tap targets, contrast and keyboard focus remain accessible',
    (tester) async {
      await tester.runAsync(session.bootstrap);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: LoginScreen(session: session),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      final inputs = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(inputs.first.focusNode!.hasFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(inputs.last.focusNode!.hasFocus, true);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
  );

  test(
    'allow-listed return rejects other roles, external URLs and mutations',
    () {
      for (final path in [
        'https://evil.invalid',
        '//evil.invalid',
        '/admin',
        '/cart?add=1',
        '/account#token',
      ]) {
        expect(safeReturn(path), '/account');
      }
      expect(safeReturn('/cart'), '/cart');
    },
  );
  test(
    'navigation remains closed until identity and consent resolve',
    () async {
      expect(
        guardRoute(session, Uri.parse('/cart')),
        '/session?returnTo=%2Fcart',
      );
      await session.bootstrap();
      expect(
        guardRoute(session, Uri.parse('/cart')),
        '/login?returnTo=%2Fcart',
      );
      expect(guardRoute(session, Uri.parse('/shops')), null);
      session.phase = SessionPhase.consentRequired;
      expect(
        guardRoute(session, Uri.parse('/cart')),
        '/consent?returnTo=%2Fcart',
      );
    },
  );
  testWidgets(
    'shell offers public policy/auth entry and private Cart sign-in gate',
    (tester) async {
      final dependencies = AppDependencies(
        config: testConfig,
        auth: auth,
        policies: policies,
        session: session,
        launcher: TrustedLauncher(testConfig),
      );
      await tester.pumpWidget(BuyerApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to AISLEY'), findsOneWidget);
      await tester.tap(find.text('Cart'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(
        find.text('Your shopping cart is not available in this version.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'login validates without network then preserves email on credential failure',
    (tester) async {
      await tester.runAsync(session.bootstrap);
      auth.onLogin = () async => throw const ApiFailure(
        FailureKind.http,
        status: 422,
        code: 'INVALID_CREDENTIALS',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: LoginScreen(session: session),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      expect(auth.loginCalls, 0);
      expect(find.text('Enter a valid email.'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'buyer@example.invalid',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Synthetic123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(auth.loginCalls, 1);
      expect(find.text('Check your email and password.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'buyer@example.invalid',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty,
      );
    },
  );
  testWidgets(
    'consent checkbox starts unchecked and acceptance requires deliberate tap',
    (tester) async {
      storage.token = 'synthetic-test-token';
      policies.consent = ConsentStatus.parse(consentJson(required: true));
      await tester.runAsync(session.bootstrap);
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: ConsentScreen(
            repository: policies,
            session: session,
            launcher: TrustedLauncher(testConfig),
            returnTo: '/account',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final accept = find.widgetWithText(FilledButton, 'Accept this version');
      expect(tester.widget<FilledButton>(accept).onPressed, null);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(policies.accepts, 0);
      expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(policies.accepts, 1);
    },
  );
  testWidgets(
    'policy reader presents public content and truthful empty history',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: PolicyReaderScreen(
            repository: policies,
            launcher: TrustedLauncher(testConfig),
            type: PolicyType.terms,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Policy title'), findsOneWidget);
      await tester.tap(find.text('View policy history'));
      await tester.pumpAndSettle();
      expect(find.text('No published history is available.'), findsOneWidget);
      expect(auth.meCalls, 0);
    },
  );
  testWidgets(
    'recovery uses generic acknowledgement without promising delivery',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: RecoveryScreen(
            repository: auth,
            launcher: TrustedLauncher(testConfig),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField),
        'buyer@example.invalid',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Request recovery'));
      await tester.pumpAndSettle();
      expect(auth.recoveries, 1);
      expect(
        find.textContaining('If your account is eligible'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'narrow large-text login survives keyboard insets with reachable fields',
    (tester) async {
      await tester.runAsync(session.bootstrap);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: LoginScreen(session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      final button = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    },
  );
  testWidgets(
    'restoration never flashes a private identity while me is pending',
    (tester) async {
      storage.token = 'synthetic-test-token';
      final me = Completer<void>();
      auth.onMe = (_) async {
        await me.future;
        return auth.identity;
      };
      final dependencies = AppDependencies(
        config: testConfig,
        auth: auth,
        policies: policies,
        session: session,
        launcher: TrustedLauncher(testConfig),
      );
      await tester.pumpWidget(BuyerApp(dependencies: dependencies));
      await tester.pump();
      await tester.tap(find.text('Account'));
      await tester.pump();
      expect(find.text('Buyer A'), findsNothing);
      expect(session.active, false);
      me.complete();
      await tester.pumpAndSettle();
      expect(find.text('Buyer A'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
