import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/account/data/password_challenge.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/password_controller.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/password_screen.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

import '../support/fakes.dart';
import '../support/account_fake.dart';

Future<bool> requestCode(PasswordController controller) =>
    controller.requestCode(
      currentPassword: 'Synthetic123',
      password: 'Synthetic456',
      confirmation: 'Synthetic456',
    );
Future<bool> confirm(PasswordController controller) => controller.change(
  currentPassword: 'Synthetic123',
  password: 'Synthetic456',
  confirmation: 'Synthetic456',
  verificationCode: '012345',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionController session;
  late FakeAuth auth;
  late FakePolicies policies;
  late FakeAccountRepository repo;
  setUp(() async {
    auth = FakeAuth();
    policies = FakePolicies();
    repo = FakeAccountRepository();
    // Keep ordinary cooldown expired so tests isolate reconciliation lifetime.
    repo.onRequestCode = () async => PasswordChallenge(
      id: customerId,
      maskedEmail: 'b***@example.test',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      resendAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    session = SessionController(
      auth,
      policies,
      MemoryTokenStore()..token = 'synthetic-token',
    );
    await session.bootstrap();
  });
  tearDown(() => session.dispose());
  PasswordController create() {
    final controller = PasswordController(session, repo);
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> login(String id) async {
    auth.identity = CustomerIdentity.parse(identityJson(id: id));
    auth.onLogin = () async => LoginResult.parse({
      'message': 'OK',
      'customer': identityJson(id: id),
      'token': 'synthetic-session-$id',
    });
    await session.signIn('buyer@example.invalid', 'Synthetic123');
  }

  for (final failure in [
    const ApiFailure(FailureKind.timeout),
    const ApiFailure(FailureKind.offline),
    const ApiFailure(FailureKind.decode),
    const ApiFailure(FailureKind.cancelled),
    const ApiFailure(FailureKind.http, status: 408),
    const ApiFailure(FailureKind.http, status: 500),
    const FormatException('Synthetic malformed success'),
  ]) {
    test('reopening blocks both operations after $failure', () async {
      final first = PasswordController(session, repo);
      await requestCode(first);
      repo.onPassword = () async => throw failure;
      expect(await confirm(first), isFalse);
      expect(first.requiresReconciliation, isTrue);
      first.dispose();
      final reopened = create();
      expect(reopened.requiresReconciliation, isTrue);
      reopened.cancelVerification();
      expect(await requestCode(reopened), isFalse);
      expect(await confirm(reopened), isFalse);
      expect(repo.codeRequests, 1);
      expect(repo.passwordWrites, 1);
      expect(reopened.recoveryMessage, contains('Sign out'));
      await session.revalidate();
      expect(reopened.requiresReconciliation, isTrue);
      policies.consent = ConsentStatus.parse(consentJson(required: true));
      await session.refreshConsent();
      policies.consent = ConsentStatus.parse(consentJson());
      await session.refreshConsent();
      expect(reopened.requiresReconciliation, isTrue);
      expect(await requestCode(reopened), isFalse);
    });
  }

  for (final outcome in ['success', '422', 'timeout']) {
    test(
      'disposal while confirming settles $outcome in the same session',
      () async {
        final first = PasswordController(session, repo);
        await requestCode(first);
        final pending = Completer<void>();
        repo.onPassword = () => pending.future;
        final result = confirm(first);
        first.dispose();
        final reopened = create();
        expect(reopened.operationPending, isTrue);
        expect(await requestCode(reopened), isFalse);
        expect(repo.codeRequests, 1);
        if (outcome == 'success') {
          pending.complete();
        } else {
          pending.completeError(
            outcome == '422'
                ? const ApiFailure(FailureKind.http, status: 422)
                : const ApiFailure(FailureKind.timeout),
          );
        }
        expect(await result, isFalse); // Disposed view never reports success.
        expect(reopened.operationPending, isFalse);
        expect(reopened.challenge, isNull);
        expect(reopened.requiresReconciliation, outcome == 'timeout');
        expect(await requestCode(reopened), outcome != 'timeout');
        expect(repo.passwordWrites, 1);
      },
    );
  }

  for (final id in [customerId, otherId]) {
    test(
      'fresh sign-in resets recovery and ignores old failure for $id',
      () async {
        final first = create();
        await requestCode(first);
        final pending = Completer<void>();
        repo.onPassword = () => pending.future;
        final result = confirm(first);
        await session.signOut();
        await login(id);
        final next = create();
        expect(await requestCode(next), isTrue);
        pending.completeError(const ApiFailure(FailureKind.timeout));
        await result;
        expect(next.requiresReconciliation, isFalse);
        expect(next.challenge, isNotNull);
        expect(repo.codeRequests, 2);
      },
    );
  }

  test('identity loss resets recovery', () async {
    final first = create();
    await requestCode(first);
    repo.onPassword = () async => throw const ApiFailure(FailureKind.timeout);
    await confirm(first);
    auth.onMe = (_) async =>
        throw const ApiFailure(FailureKind.http, status: 401);
    await session.revalidate();
    expect(session.customer, isNull);
    expect(session.passwordChanges.reconciliationRequired, isFalse);
    expect(await requestCode(first), isFalse);
  });

  test('code cooldown survives cancel and new controller; confirmation remains available', () async {
    repo.onRequestCode = () async => PasswordChallenge(
      id: customerId,
      maskedEmail: 'b***@example.test',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      resendAt: DateTime.now().add(const Duration(seconds: 60)),
    );
    final first = PasswordController(session, repo);
    await requestCode(first);
    expect(
      await confirm(first),
      isTrue,
    ); // Resend cooldown does not block confirmation.
    first.cancelVerification();
    first.dispose();
    final next = create();
    expect(await requestCode(next), isFalse);
    expect(next.resendBlocked, isTrue);
    expect(repo.codeRequests, 1);
  });

  test('Retry-After survives screen disposal', () async {
    final first = PasswordController(session, repo);
    repo.onRequestCode = () async => throw ApiFailure(
      FailureKind.http,
      status: 429,
      retryAt: DateTime.now().add(const Duration(seconds: 60)),
    );
    expect(await requestCode(first), isFalse);
    first.dispose();
    final next = create();
    expect(await requestCode(next), isFalse);
    expect(repo.codeRequests, 1);
    expect(next.requestBlocked, isTrue);
    expect(next.requiresReconciliation, isFalse);
  });

  for (final failure in [
    const ApiFailure(FailureKind.timeout),
    const FormatException('Synthetic malformed code response'),
  ]) {
    test(
      'code uncertainty retains cooldown after disposal for $failure',
      () async {
        final first = PasswordController(session, repo);
        repo.onRequestCode = () async => throw failure;
        expect(await requestCode(first), isFalse);
        first.dispose();
        final next = create();
        expect(next.requestBlocked, isTrue);
        expect(next.requiresReconciliation, isFalse);
        expect(await requestCode(next), isFalse);
        expect(repo.codeRequests, 1);
      },
    );
  }

  testWidgets('actual screen remount retains recovery and clears credentials', (
    tester,
  ) async {
    final first = PasswordController(session, repo);
    await requestCode(first);
    repo.onPassword = () async => throw const ApiFailure(FailureKind.timeout);
    await confirm(first);
    first.dispose();
    final dependencies = AppDependencies(
      config: testConfig,
      auth: auth,
      policies: policies,
      session: session,
      launcher: TrustedLauncher(testConfig),
      accounts: repo,
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: PasswordScreen(
            key: ValueKey(attempt),
            dependencies: dependencies,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('outcome is uncertain'), findsOneWidget);
      expect(find.text('Sign out to verify password'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
    }
    expect(repo.codeRequests, 1);
    expect(repo.passwordWrites, 1);
  });
}
