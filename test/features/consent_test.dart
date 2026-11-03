import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/policies/presentation/policy_view_models.dart';

import '../support/fakes.dart';

Map<String, dynamic> both({
  bool termsRequired = true,
  bool privacyRequired = true,
  int version = 1,
}) => {
  'policies': [
    ...(consentJson(required: termsRequired, version: version)['policies']
        as List),
    for (final item
        in consentJson(required: privacyRequired)['policies'] as List)
      {
        ...item as Map<String, dynamic>,
        'type': 'privacy_policy',
        'label': 'Privacy Policy',
      },
  ],
  'all_required_accepted': !termsRequired && !privacyRequired,
};
PolicyBatchAcceptance saved(Map<PolicyType, int> versions) =>
    PolicyBatchAcceptance.parse({
      'acceptances': [
        for (final entry in versions.entries)
          {
            ...policyJson(type: entry.key.wire, version: entry.value),
            'accepted_at': null,
          },
      ],
      'status': both(termsRequired: false, privacyRequired: false),
    });

void main() {
  late FakePolicies policies;
  late SessionController session;
  late ConsentViewModel model;
  setUp(() async {
    policies = FakePolicies()..consent = ConsentStatus.parse(both());
    session = SessionController(
      FakeAuth(),
      policies,
      MemoryTokenStore()..token = 'synthetic-test-token',
    );
    await session.bootstrap();
    model = ConsentViewModel(policies, session);
    await model.load();
  });
  tearDown(() {
    model.dispose();
    session.dispose();
  });

  test('both confirmations produce exactly one atomic request', () async {
    expect(model.documents.length, 2);
    expect(model.mayAccept, false);
    model.confirm(PolicyType.terms, true);
    await model.accept();
    expect(policies.accepts, 0);
    expect(model.mayAccept, false);
    model.confirm(PolicyType.privacy, true);
    Map<PolicyType, int>? selection;
    policies.onAcceptTogether = (versions) async {
      selection = versions;
      policies.consent = ConsentStatus.parse(
        both(termsRequired: false, privacyRequired: false),
      );
      return saved(versions);
    };
    await model.accept();
    expect(selection, {PolicyType.terms: 1, PolicyType.privacy: 1});
    expect(policies.accepts, 1);
    expect(session.active, true);
  });

  test(
    'covered document stays satisfied and only pending version is sent',
    () async {
      policies.consent = ConsentStatus.parse(both(termsRequired: false));
      await model.load();
      expect(model.confirmed(PolicyType.terms), true);
      expect(model.confirmed(PolicyType.privacy), false);
      model.confirm(PolicyType.privacy, true);
      Map<PolicyType, int>? selection;
      policies.onAcceptTogether = (versions) async {
        selection = versions;
        policies.consent = ConsentStatus.parse(
          both(termsRequired: false, privacyRequired: false),
        );
        return saved(versions);
      };
      await model.accept();
      expect(selection, {PolicyType.privacy: 1});
    },
  );

  test('foreground publication clears affected confirmation only', () async {
    model.confirm(PolicyType.terms, true);
    model.confirm(PolicyType.privacy, true);
    policies.policy = PublicPolicy.parse(policyJson(version: 2));
    policies.consent = ConsentStatus.parse(both(version: 2));
    await session.refreshConsent();
    await Future<void>.delayed(Duration.zero);
    expect(model.confirmed(PolicyType.terms), false);
    expect(model.confirmed(PolicyType.privacy), true);
    expect(model.documents[PolicyType.terms]?.version.version, 2);
    expect(model.mayAccept, false);
  });

  test(
    'publication before submission sends nothing and reloads new version',
    () async {
      model.confirm(PolicyType.terms, true);
      model.confirm(PolicyType.privacy, true);
      policies.policy = PublicPolicy.parse(policyJson(version: 2));
      policies.consent = ConsentStatus.parse(both(version: 2));
      await model.accept();
      expect(policies.accepts, 0);
      expect(model.failure?.code, 'POLICY_VERSION_STALE');
      expect(model.confirmed(PolicyType.terms), false);
      expect(session.active, false);
    },
  );

  test('null required current version never enables acceptance', () async {
    policies.consent = ConsentStatus.parse(
      consentJson(required: true, nullCurrent: true),
    );
    await model.load();
    expect(model.failure?.kind, FailureKind.decode);
    expect(model.mayAccept, false);
  });

  test(
    'uncertain result reconciles committed consent without replay',
    () async {
      model.confirm(PolicyType.terms, true);
      model.confirm(PolicyType.privacy, true);
      policies.onAcceptTogether = (_) async {
        policies.consent = ConsentStatus.parse(
          both(termsRequired: false, privacyRequired: false),
        );
        throw const ApiFailure(FailureKind.timeout);
      };
      await model.accept();
      expect(policies.accepts, 1);
      expect(session.active, true);
      expect(model.failure, null);
    },
  );

  test(
    'uncertain unsaved result retains exact confirmations for deliberate retry',
    () async {
      model.confirm(PolicyType.terms, true);
      model.confirm(PolicyType.privacy, true);
      final selections = <Map<PolicyType, int>>[];
      policies.onAcceptTogether = (versions) async {
        selections.add(versions);
        throw const ApiFailure(FailureKind.timeout);
      };
      await model.accept();
      expect(model.confirmed(PolicyType.terms), true);
      expect(model.confirmed(PolicyType.privacy), true);
      expect(session.active, false);
      await model.accept();
      expect(selections, [
        {PolicyType.terms: 1, PolicyType.privacy: 1},
        {PolicyType.terms: 1, PolicyType.privacy: 1},
      ]);
    },
  );

  test(
    'duplicate submission is serialized and logout discards late result',
    () async {
      model.confirm(PolicyType.terms, true);
      model.confirm(PolicyType.privacy, true);
      final pending = Completer<PolicyBatchAcceptance>();
      policies.onAcceptTogether = (_) => pending.future;
      final accepting = model.accept();
      await Future<void>.delayed(Duration.zero);
      await model.accept();
      expect(policies.accepts, 1);
      await session.signOut();
      pending.complete(saved({PolicyType.terms: 1, PolicyType.privacy: 1}));
      await accepting;
      expect(model.documents, isEmpty);
      expect(model.confirmations, isEmpty);
      expect(session.phase, SessionPhase.signedOut);
    },
  );
}
