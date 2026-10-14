import 'package:aisley_mobile_buyer/features/auth/presentation/registration_screen.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/auth/data/registration_email.dart';
import 'package:aisley_mobile_buyer/features/auth/presentation/registration_email_controller.dart';
import 'package:aisley_mobile_buyer/features/auth/presentation/registration_email_fields.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';

const proofToken =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final instant = DateTime.utc(2026, 10, 14);

class VerificationFixture implements RegistrationEmailRepository {
  int requests = 0, verifications = 0;
  String? email, code;
  Object? error;
  Completer<RegistrationEmailChallenge>? pending;
  @override
  Future<RegistrationEmailChallenge> requestRegistrationCode(
    String value,
  ) async {
    requests++;
    email = value;
    if (error != null) throw error!;
    return pending?.future ??
        Future.value(
          RegistrationEmailChallenge(
            id: 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
            expiresAt: instant.add(const Duration(minutes: 10)),
            resendAt: instant.add(const Duration(seconds: 60)),
          ),
        );
  }

  @override
  Future<RegistrationEmailProof> verifyRegistrationEmail(
    String value,
    String id,
    String valueCode,
  ) async {
    verifications++;
    email = value;
    code = valueCode;
    if (error != null) throw error!;
    return RegistrationEmailProof(
      token: proofToken,
      expiresAt: instant.add(const Duration(hours: 1)),
    );
  }
}

void main() {
  test(
    'DTO rejects malformed secrets and timestamps without printing the proof',
    () {
      expect(
        () => RegistrationEmailProof.parse({
          'email_verification_token': 'x',
          'expires_at': instant.toIso8601String(),
        }),
        throwsFormatException,
      );
      expect(
        () => RegistrationEmailChallenge.parse({
          'challenge_id': 'x',
          'expires_at': 'bad',
          'resend_available_at': 'bad',
        }),
        throwsFormatException,
      );
      expect(
        RegistrationEmailProof(
          token: proofToken,
          expiresAt: instant,
        ).toString(),
        isNot(contains(proofToken)),
      );
    },
  );
  test('normalizes email, preserves leading zeros, enforces resend and proof expiry', () async {
    var now = instant;
    final repo = VerificationFixture();
    final c = RegistrationEmailController(repo, clock: () => now);
    addTearDown(c.dispose);
    expect(await c.send(' NEW@EXAMPLE.COM '), true);
    expect(repo.email, 'new@example.com');
    expect(await c.send('new@example.com'), false);
    expect(repo.requests, 1);
    expect(await c.verify('012345'), true);
    expect(repo.code, '012345');
    expect(c.verified, true);
    now = now.add(const Duration(hours: 1));
    expect(c.verified, false);
    c.reset();
    expect(c.proof, isNull);
  });
  test('change email and disposal ignore a pending old response', () async {
    final repo = VerificationFixture()
      ..pending = Completer<RegistrationEmailChallenge>();
    final c = RegistrationEmailController(repo, clock: () => instant);
    final request = c.send('old@example.com');
    c.reset();
    repo.pending!.complete(
      RegistrationEmailChallenge(
        id: 'old',
        expiresAt: instant.add(const Duration(minutes: 10)),
        resendAt: instant,
      ),
    );
    expect(await request, false);
    expect(c.challenge, isNull);
    repo.pending = Completer<RegistrationEmailChallenge>();
    final second = c.send('new@example.com');
    c.dispose();
    repo.pending!.complete(
      RegistrationEmailChallenge(
        id: 'late',
        expiresAt: instant,
        resendAt: instant,
      ),
    );
    expect(await second, false);
  });
  test('429 blocks direct requests until the server cooldown passes', () async {
    var now = instant;
    final repo = VerificationFixture()
      ..error = ApiFailure(
        FailureKind.http,
        status: 429,
        retryAt: now.add(const Duration(seconds: 90)),
      );
    final c = RegistrationEmailController(repo, clock: () => now);
    addTearDown(c.dispose);
    expect(await c.send('new@example.com'), false);
    expect(c.resendSeconds, 90);
    expect(await c.send('new@example.com'), false);
    expect(repo.requests, 1);
    now = now.add(const Duration(seconds: 90));
    repo.error = null;
    expect(await c.send('new@example.com'), true);
  });
  test(
    'incorrect code remains recoverable and never verifies identity',
    () async {
      final repo = VerificationFixture();
      final c = RegistrationEmailController(repo, clock: () => instant);
      addTearDown(c.dispose);
      await c.send('new@example.com');
      repo.error = const ApiFailure(
        FailureKind.http,
        status: 422,
        fields: {
          'verification_code': ['Check code.'],
        },
      );
      expect(await c.verify('999999'), false);
      expect(c.verified, false);
      expect(c.challenge, isNotNull);
      repo.error = null;
      expect(await c.verify('012345'), true);
    },
  );
  testWidgets(
    'registration details stay hidden until OTP and survive changing email',
    (tester) async {
      final auth = FakeAuth();
      final router = GoRouter(
        initialLocation: '/register',
        routes: [
          GoRoute(
            path: '/register',
            builder: (_, _) =>
                RegistrationScreen(repository: auth, clock: DateTime.now),
          ),
          GoRoute(
            path: '/approval',
            builder: (_, _) => const Scaffold(body: Text('Pending approval')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      expect(field('First name'), findsNothing);
      await tester.enterText(field('Email address'), 'buyer@example.com');
      await tester.ensureVisible(find.text('Send verification code'));
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Verification code'), '012345');
      await tester.ensureVisible(find.text('Verify email'));
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('First name'));
      await tester.enterText(field('First name'), 'Preserved');
      await tester.ensureVisible(find.text('Change email'));
      await tester.tap(find.text('Change email'));
      await tester.pumpAndSettle();
      expect(field('First name'), findsNothing);
      await tester.ensureVisible(find.text('Send verification code'));
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Verification code'), '012345');
      await tester.ensureVisible(find.text('Verify email'));
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('First name')).controller!.text,
        'Preserved',
      );
      expect(tester.widget<TextField>(field('Email')).readOnly, true);
      expect(auth.registrations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [320.0, 390.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('OTP paste and text scaling at $width $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = VerificationFixture();
        final c = RegistrationEmailController(repo, clock: () => instant);
        var verified = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                    ),
                    child: RegistrationEmailFields(
                      controller: c,
                      onVerified: () => verified = true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField).first, 'NEW@example.com');
        await tester.ensureVisible(find.text('Send verification code'));
        await tester.tap(find.text('Send verification code'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '012345');
        await tester.ensureVisible(find.text('Verify email'));
        await tester.tap(find.text('Verify email'));
        await tester.pumpAndSettle();
        expect(verified, true);
        expect(repo.code, '012345');
        expect(find.text('Your email is verified'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      });
    }
  }
}
