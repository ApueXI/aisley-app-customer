import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/policies/presentation/policy_view_models.dart';

import '../support/fakes.dart';

void main() {
  late FakePolicies policies;
  late SessionController session;
  late ConsentViewModel model;
  setUp(() async {
    policies = FakePolicies()
      ..consent = ConsentStatus.parse(consentJson(required: true));
    session = SessionController(
      FakeAuth(),
      policies,
      MemoryTokenStore()..token = 'synthetic-test-token',
    );
    await session.bootstrap();
    model = ConsentViewModel(policies, session);
  });
  tearDown(() {
    model.dispose();
    session.dispose();
  });
  test(
    'foreground publication refresh clears old confirmation immediately',
    () async {
      await model.load();
      model.confirm(true);
      policies.policy = PublicPolicy.parse(policyJson(version: 2));
      policies.consent = ConsentStatus.parse(
        consentJson(required: true, version: 2),
      );
      await session.refreshConsent();
      await Future<void>.delayed(Duration.zero);
      expect(model.confirmed, false);
      expect(model.policy?.version.version, 2);
      expect(model.mayAccept, false);
    },
  );
  test(
    'partial Terms acceptance does not unlock remaining Privacy requirement',
    () async {
      final privacy =
          Map<String, dynamic>.of(
              (consentJson(required: true)['policies'] as List).single
                  as Map<String, dynamic>,
            )
            ..['type'] = 'privacy_policy'
            ..['label'] = 'Privacy Policy';
      policies.consent = ConsentStatus.parse({
        'policies': [
          ...consentJson(required: true)['policies'] as List,
          privacy,
        ],
        'all_required_accepted': false,
      });
      await session.refreshConsent();
      await model.load();
      model.confirm(true);
      policies.onAccept = (type, version) async {
        policies.consent = ConsentStatus.parse({
          'policies': [privacy],
          'all_required_accepted': false,
        });
        policies.policy = PublicPolicy.parse(
          policyJson(type: 'privacy_policy'),
        );
        return PolicyAcceptance.parse({...policyJson(), 'accepted_at': null});
      };
      await model.accept();
      expect(session.active, false);
      expect(model.policy?.type, 'privacy_policy');
      expect(model.confirmed, false);
    },
  );
  test(
    'confirmation is explicit; acceptance rechecks status before unlocking',
    () async {
      await model.load();
      expect(model.confirmed, false);
      await model.accept();
      expect(policies.accepts, 0);
      model.confirm(true);
      await model.accept();
      expect(policies.accepts, 1);
      expect(session.active, true);
      expect(policies.statusCalls, 2);
    },
  );
  test('null required current version cannot fabricate acceptance', () async {
    policies.consent = ConsentStatus.parse(
      consentJson(required: true, nullCurrent: true),
    );
    await session.refreshConsent();
    await model.load();
    expect(model.failure?.kind, FailureKind.decode);
    expect(model.policy, null);
    expect(model.mayAccept, false);
  });
  test(
    'stale publication resets confirmation and reloads new content',
    () async {
      await model.load();
      model.confirm(true);
      policies.onAccept = (_, _) async {
        policies.policy = PublicPolicy.parse(policyJson(version: 2));
        policies.consent = ConsentStatus.parse(
          consentJson(required: true, version: 2),
        );
        throw const ApiFailure(
          FailureKind.http,
          status: 409,
          code: 'POLICY_VERSION_STALE',
        );
      };
      await model.accept();
      expect(model.confirmed, false);
      expect(model.policy?.version.version, 2);
      expect(model.failure?.code, 'POLICY_VERSION_STALE');
      expect(session.active, false);
    },
  );
  test(
    'uncertain acceptance only offers deliberate exact-version retry',
    () async {
      await model.load();
      model.confirm(true);
      final versions = <int>[];
      policies.onAccept = (_, version) async {
        versions.add(version);
        throw const ApiFailure(FailureKind.timeout);
      };
      await model.accept();
      expect(policies.accepts, 1);
      expect(model.confirmed, true);
      expect(session.active, false);
      await model.accept();
      expect(versions, [1, 1]);
    },
  );
  test('logout during acceptance drops late success and failure', () async {
    await model.load();
    model.confirm(true);
    final pending = Completer<PolicyAcceptance>();
    policies.onAccept = (_, _) => pending.future;
    final accepting = model.accept();
    await session.signOut();
    pending.completeError(const ApiFailure(FailureKind.http, status: 401));
    await accepting;
    expect(model.policy, null);
    expect(model.confirmed, false);
    expect(model.failure, null);
    expect(session.phase, SessionPhase.signedOut);
  });
  test('duplicate acceptance is serialized', () async {
    await model.load();
    model.confirm(true);
    final pending = Completer<PolicyAcceptance>();
    policies.onAccept = (_, _) => pending.future;
    final first = model.accept();
    await model.accept();
    expect(policies.accepts, 1);
    policies.consent = ConsentStatus.parse(consentJson());
    pending.complete(
      PolicyAcceptance.parse({...policyJson(), 'accepted_at': null}),
    );
    await first;
    expect(session.active, true);
  });
}
