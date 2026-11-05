import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/auth/data/registration_email.dart';
import 'package:aisley_mobile_buyer/features/auth/presentation/registration_screen.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';

import '../support/fakes.dart';

class AutomaticAuth extends FakeAuth
    implements RegistrationConfigurationRepository {
  bool required = false, configFailure = false, active = false;
  ApiFailure? registrationFailure;
  RegistrationInput? input;
  @override
  Future<bool> registrationEmailRequired() async {
    if (configFailure) throw const FormatException('Unavailable');
    return required;
  }

  @override
  Future<RegistrationResult> register(RegistrationInput value) async {
    registrations++;
    input = value;
    if (registrationFailure case final failure?) throw failure;
    final json = fixture('customer-auth', 'op-001');
    (json['customer'] as Map<String, dynamic>)['status'] = active
        ? 'active'
        : 'pending';
    return RegistrationResult.parse(json);
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
  skipOffstage: false,
);

Future<void> openForm(WidgetTester tester, AutomaticAuth auth) async {
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/register',
        builder: (_, _) =>
            RegistrationScreen(repository: auth, clock: DateTime.now),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Sign in destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  for (final entry in {
    'First name': 'Ana',
    'Last name': 'Buyer',
    'Contact number': '09171234567',
    'Email': 'buyer@example.com',
    'Password': 'Synthetic123',
    'Confirm password': 'Synthetic123',
  }.entries) {
    await tester.ensureVisible(field(entry.key));
    await tester.enterText(field(entry.key), entry.value);
  }
  await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Female').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(field('Birth date'));
  await tester.tap(field('Birth date'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('2000').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  for (final active in [true, false]) {
    testWidgets(
      'OTP bypass shows confirmed ${active ? 'ready' : 'pending'} success without a login',
      (tester) async {
        final auth = AutomaticAuth()..active = active;
        await openForm(tester, auth);
        await press(tester, 'Create account');
        expect(auth.registrations, 1);
        expect(
          auth.input!.toJson().containsKey('email_verification_token'),
          false,
        );
        expect(auth.loginCalls, 0);
        expect(find.text('Account created successfully'), findsOneWidget);
        expect(
          find.textContaining(
            active ? 'Your account is ready' : 'Please wait for Admin approval',
          ),
          findsOneWidget,
        );
        await press(tester, 'Go to sign in');
        expect(find.text('Sign in destination'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'failed config blocks submission, explicit retry preserves input',
    (tester) async {
      final auth = AutomaticAuth()..configFailure = true;
      await openForm(tester, auth);
      expect(auth.registrations, 0);
      expect(find.text('Retry registration settings'), findsOneWidget);
      auth.configFailure = false;
      await press(tester, 'Retry registration settings');
      expect(
        tester.widget<TextField>(field('Password')).controller!.text,
        'Synthetic123',
      );
      await press(tester, 'Create account');
      expect(auth.registrations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('server re-enables OTP without replaying registration', (
    tester,
  ) async {
    final auth = AutomaticAuth()
      ..registrationFailure = const ApiFailure(
        FailureKind.http,
        status: 422,
        fields: {
          'email_verification_token': ['Verify again.'],
        },
      );
    await openForm(tester, auth);
    await press(tester, 'Create account');
    expect(auth.registrations, 1);
    expect(find.text('Continue to email verification'), findsOneWidget);
    expect(
      tester.widget<TextField>(field('First name')).controller!.text,
      'Ana',
    );
    expect(
      tester.widget<TextField>(field('Password')).controller!.text,
      isEmpty,
    );
    auth.registrationFailure = null;
    for (final label in ['Password', 'Confirm password']) {
      await tester.ensureVisible(field(label));
      await tester.enterText(field(label), 'Synthetic123');
    }
    await press(tester, 'Continue to email verification');
    await tester.ensureVisible(field('Verification code'));
    await tester.enterText(field('Verification code'), '012345');
    await press(tester, 'Verify email');
    expect(auth.registrations, 2);
    expect(auth.input!.emailVerificationToken, isNotEmpty);
    expect(find.text('Account created successfully'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('unconfirmed submission never retries on resume or timer', (
    tester,
  ) async {
    final auth = AutomaticAuth()
      ..registrationFailure = const ApiFailure(FailureKind.timeout);
    await openForm(tester, auth);
    await press(tester, 'Create account');
    expect(find.textContaining('result is unconfirmed'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(auth.registrations, 1);
    expect(find.text('Account created successfully'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
