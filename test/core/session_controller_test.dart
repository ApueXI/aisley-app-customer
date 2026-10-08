import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/app/router_guard.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

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
  test(
    'late login after local sign-out is revoked without being persisted',
    () async {
      await session.bootstrap();
      final pending = Completer<LoginResult>();
      auth.onLogin = () => pending.future;
      final login = session.signIn('buyer@example.invalid', 'Synthetic123');
      while (auth.loginCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await session.signOut();
      pending.complete(
        LoginResult.parse({
          'message': 'OK',
          'customer': identityJson(),
          'token': 'synthetic-test-token',
        }),
      );
      await login;
      expect(storage.writes, 0);
      expect(storage.token, null);
      expect(session.customer, null);
      expect(auth.logoutCalls, 1);
      expect(session.notice, contains('could not be confirmed'));
    },
  );
  test(
    'late consent refresh cannot overwrite a newer policy requirement',
    () async {
      storage.token = 'synthetic-test-token';
      await session.bootstrap();
      final old = Completer<ConsentStatus>(),
          recent = Completer<ConsentStatus>();
      var calls = 0;
      policies.onStatus = () => ++calls == 1 ? old.future : recent.future;
      final first = session.refreshConsent(), second = session.refreshConsent();
      recent.complete(
        ConsentStatus.parse(consentJson(required: true, version: 2)),
      );
      await second;
      old.complete(ConsentStatus.parse(consentJson()));
      await first;
      expect(session.phase, SessionPhase.consentRequired);
      expect(session.active, false);
      expect(session.consent?.policies.first.currentVersion?.version, 2);
    },
  );

  test(
    'guest bootstrap deduplicates secure read and does not call me',
    () async {
      await Future.wait([session.bootstrap(), session.bootstrap()]);
      expect(storage.reads, 1);
      expect(auth.meCalls, 0);
      expect(session.phase, SessionPhase.signedOut);
    },
  );
  test(
    'stored bearer verifies me and current consent once before active',
    () async {
      storage.token = 'synthetic-test-token';
      final me = Completer<CustomerIdentity>();
      auth.onMe = (_) => me.future;
      final boot = session.bootstrap();
      await Future<void>.delayed(Duration.zero);
      expect(session.active, false);
      expect(session.customer, null);
      final refresh = session.refresh();
      me.complete(auth.identity);
      await Future.wait([boot, refresh]);
      expect(auth.meCalls, 1);
      expect(policies.statusCalls, 1);
      expect(session.active, true);
    },
  );
  test('login persists token, rechecks identity and consent', () async {
    await session.bootstrap();
    await session.signIn('buyer@example.invalid', 'Synthetic123');
    expect(storage.writes, 1);
    expect(auth.meCalls, 1);
    expect(session.active, true);
  });
  test('background checks deduplicate and keep an active route through offline failure', () async {
    storage.token = 'synthetic-test-token';
    await session.bootstrap();
    final pending = Completer<CustomerIdentity>();
    auth.onMe = (_) => pending.future;
    final first = session.revalidate();
    final second = session.revalidate();
    await Future<void>.delayed(Duration.zero);
    expect(session.active, isTrue);
    expect(guardRoute(session, Uri.parse('/products/$customerId')), isNull);
    pending.complete(auth.identity);
    await Future.wait([first, second]);
    expect(auth.meCalls, 2);
    expect(policies.statusCalls, 2);

    auth.onMe = (_) async => throw const ApiFailure(FailureKind.offline);
    await session.revalidate();
    expect(session.active, isTrue);
    expect(session.customer?.id, customerId);
    expect(session.revalidationFailure?.kind, FailureKind.offline);
    expect(guardRoute(session, Uri.parse('/products/$customerId')), isNull);
  });
  test('late background identity response is ignored after logout', () async {
    storage.token = 'synthetic-test-token';
    await session.bootstrap();
    final pending = Completer<CustomerIdentity>();
    auth.onMe = (_) => pending.future;
    final background = session.revalidate();
    await Future<void>.delayed(Duration.zero);
    await session.signOut();
    pending.complete(auth.identity);
    await background;
    expect(session.phase, SessionPhase.signedOut);
    expect(session.customer, isNull);
    expect(session.revalidationFailure, isNull);
  });
  test(
    'required consent retains identity and token without private access',
    () async {
      storage.token = 'synthetic-test-token';
      policies.consent = ConsentStatus.parse(consentJson(required: true));
      await session.bootstrap();
      expect(session.phase, SessionPhase.consentRequired);
      expect(session.customer?.id, customerId);
      expect(storage.token, isNotNull);
      expect(session.active, false);
    },
  );
  test('consent transport failure retains valid identity for retry', () async {
    storage.token = 'synthetic-test-token';
    policies.onStatus = () async => throw const ApiFailure(FailureKind.offline);
    await session.bootstrap();
    expect(session.phase, SessionPhase.consentUnavailable);
    expect(session.customer, isNotNull);
    expect(storage.token, isNotNull);
    policies.onStatus = null;
    await session.retry();
    expect(session.active, true);
  });
  for (final kind in [
    FailureKind.offline,
    FailureKind.timeout,
    FailureKind.decode,
  ]) {
    test(
      'identity ${kind.name} keeps token but blocks private screens',
      () async {
        storage.token = 'synthetic-test-token';
        auth.onMe = (_) async => throw ApiFailure(kind);
        await session.bootstrap();
        expect(session.phase, SessionPhase.identityUnavailable);
        expect(session.customer, null);
        expect(storage.token, isNotNull);
      },
    );
  }
  for (final status in ['pending', 'rejected', 'suspended', 'deactivated']) {
    test('$status identity clears credential and denies account', () async {
      storage.token = 'synthetic-test-token';
      auth.identity = CustomerIdentity.parse(identityJson(status: status));
      await session.bootstrap();
      expect(session.phase, SessionPhase.accountDenied);
      expect(session.customer, null);
      expect(storage.token, null);
      expect(policies.statusCalls, 0);
    });
  }
  test('wrong role and revoked token clear private state', () async {
    storage.token = 'synthetic-test-token';
    auth.onMe = (_) async =>
        throw const ApiFailure(FailureKind.http, status: 401);
    var cleanups = 0;
    session.registerPrivateCleanup(() => cleanups++);
    await session.bootstrap();
    expect(session.phase, SessionPhase.signedOut);
    expect(cleanups, 1);
    expect(storage.token, null);
    auth.onMe = null;
    storage.token = 'synthetic-test-token';
    auth.identity = CustomerIdentity.parse(identityJson(role: 'seller'));
    await session.retry();
    expect(session.phase, SessionPhase.accountDenied);
    expect(storage.token, null);
  });
  test(
    'storage read failure is retryable and does not become sign-out',
    () async {
      storage.readFails = true;
      await session.bootstrap();
      expect(session.phase, SessionPhase.storageUnavailable);
      expect(auth.meCalls, 0);
      storage.readFails = false;
      await session.retry();
      expect(session.phase, SessionPhase.signedOut);
    },
  );
  test(
    'login write failure revokes new token and never exposes identity',
    () async {
      await session.bootstrap();
      storage.writeFails = true;
      await expectLater(
        session.signIn('buyer@example.invalid', 'Synthetic123'),
        throwsA(isA<ApiFailure>()),
      );
      expect(session.phase, SessionPhase.storageUnavailable);
      expect(session.customer, null);
      expect(auth.logoutCalls, 1);
      storage.writeFails = false;
      await session.retry();
      expect(session.phase, SessionPhase.signedOut);
    },
  );
  test(
    'failed secure deletion blocks restoration until deletion succeeds',
    () async {
      storage.token = 'synthetic-test-token';
      await session.bootstrap();
      storage.deleteFails = true;
      await session.signOut();
      expect(session.phase, SessionPhase.storageUnavailable);
      expect(session.customer, null);
      final reads = storage.reads;
      await session.retry();
      expect(storage.reads, reads);
      storage.deleteFails = false;
      await session.retry();
      expect(session.phase, SessionPhase.signedOut);
      expect(storage.token, null);
    },
  );
  test(
    'offline logout clears locally and reports unconfirmed remote revocation',
    () async {
      storage.token = 'synthetic-test-token';
      await session.bootstrap();
      auth.onLogout = () async => throw const ApiFailure(FailureKind.timeout);
      await session.signOut();
      expect(storage.token, null);
      expect(session.phase, SessionPhase.signedOut);
      expect(session.notice, contains('could not be confirmed'));
    },
  );
  for (final oldError in [false, true]) {
    test(
      'delayed ${oldError ? '401' : 'success'} cannot revive account A after A-B-A switch',
      () async {
        storage.token = 'synthetic-test-token';
        await session.bootstrap();
        final pending = Completer<CustomerIdentity>();
        auth.onMe = (_) => pending.future;
        final old = session.refresh();
        await Future<void>.delayed(Duration.zero);
        await session.signOut();
        auth.onMe = null;
        auth.identity = CustomerIdentity.parse(identityJson(id: otherId));
        await session.signIn('b@example.invalid', 'Synthetic123');
        if (oldError) {
          pending.completeError(
            const ApiFailure(FailureKind.http, status: 401),
          );
        } else {
          pending.complete(CustomerIdentity.parse(identityJson()));
        }
        await old;
        expect(session.customer?.id, otherId);
        expect(session.active, true);
        await session.signOut();
        auth.identity = CustomerIdentity.parse(identityJson());
        await session.signIn('a@example.invalid', 'Synthetic123');
        expect(session.customer?.id, customerId);
      },
    );
  }
  test(
    'logout serializes deletion after an outstanding secure write',
    () async {
      await session.bootstrap();
      storage.delayedWrite = Completer<void>();
      final login = session.signIn('a@example.invalid', 'Synthetic123');
      while (storage.writes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final logout = session.signOut();
      storage.delayedWrite!.complete();
      await Future.wait([login, logout]);
      expect(storage.token, null);
      expect(session.active, false);
      expect(auth.logoutCalls, 1);
      expect(session.notice, contains('could not be confirmed'));
    },
  );
}
