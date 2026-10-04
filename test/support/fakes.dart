import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/security/token_store.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_repository.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_repository.dart';

const customerId = '11111111-1111-4111-8111-111111111111';
const otherId = '22222222-2222-4222-8222-222222222222';
final testConfig = AppConfig(
  apiBaseUrl: 'http://localhost:8000/api/v1',
  storefrontOrigin: 'http://localhost:3000',
  allowLocalHttp: true,
);

Map<String, dynamic> fixture(String feature, String operation) {
  final data = jsonDecode(
    File('docs/api/examples/$feature.json').readAsStringSync(),
  ) as Map;
  final item = (data['operations'] as List).cast<Map>().firstWhere(
    (o) => o['id'] == operation,
  );
  return item['response_example'] as Map<String, dynamic>;
}

Map<String, dynamic> identityJson({
  String id = customerId,
  String role = 'customer',
  String status = 'active',
}) => {
  'id': id,
  'displayName': id == customerId ? 'Buyer A' : 'Buyer B',
  'avatarUrl': null,
  'role': role,
  'status': status,
};
Map<String, dynamic> policyJson({
  int version = 1,
  String type = 'terms_of_service',
}) => {
  'type': type,
  'label': type == 'terms_of_service' ? 'Terms of Service' : 'Privacy Policy',
  'version': {
    'id': customerId,
    'version': version,
    'title': 'Policy title',
    'content': 'Readable policy content.',
    'status': 'published',
    'change_summary': null,
    'requires_reconsent': true,
    'published_at': null,
  },
};
Map<String, dynamic> consentJson({
  bool required = false,
  int version = 1,
  bool accepted = false,
  bool nullCurrent = false,
}) => {
  'policies': [
    {
      'type': 'terms_of_service',
      'label': 'Terms of Service',
      'required': required,
      'accepted': accepted,
      'accepted_at': null,
      'current_version': nullCurrent
          ? null
          : (Map<String, dynamic>.of(
                policyJson(version: version)['version'] as Map<String, dynamic>,
              )
              ..remove('content')
              ..remove('status')),
      'accepted_version': null,
    },
  ],
  'all_required_accepted': !required,
};

class MemoryTokenStore implements TokenStore {
  String? token;
  bool readFails = false, writeFails = false, deleteFails = false;
  Completer<void>? delayedWrite;
  int reads = 0, writes = 0, deletes = 0;
  @override
  Future<String?> read() async {
    reads++;
    if (readFails) throw StateError('storage');
    return token;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    if (delayedWrite != null) await delayedWrite!.future;
    if (writeFails) throw StateError('storage');
    token = value;
  }

  @override
  Future<void> delete() async {
    deletes++;
    if (deleteFails) throw StateError('storage');
    token = null;
  }
}

class FakeAuth implements AuthRepository {
  CustomerIdentity identity = CustomerIdentity.parse(identityJson());
  Future<CustomerIdentity> Function(SessionLease)? onMe;
  Future<LoginResult> Function()? onLogin;
  Future<void> Function()? onLogout;
  int meCalls = 0,
      loginCalls = 0,
      logoutCalls = 0,
      registrations = 0,
      recoveries = 0;
  @override
  Future<LoginResult> login(String email, String password) async {
    loginCalls++;
    return onLogin != null
        ? onLogin!()
        : LoginResult.parse({
            'message': 'OK',
            'customer': identityJson(),
            'token': 'synthetic-test-token',
          });
  }

  @override
  Future<CustomerIdentity> me(SessionLease lease) async {
    meCalls++;
    return onMe != null ? onMe!(lease) : identity;
  }

  @override
  Future<void> logout(SessionLease lease) async {
    logoutCalls++;
    if (onLogout != null) await onLogout!();
  }

  @override
  Future<RegistrationResult> register(RegistrationInput input) async {
    registrations++;
    return RegistrationResult.parse(fixture('customer-auth', 'op-001'));
  }

  @override
  Future<void> forgotPassword(String email) async {
    recoveries++;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confirmation,
  }) async {}
}

class FakePolicies implements PolicyRepository {
  ConsentStatus consent = ConsentStatus.parse(consentJson());
  PublicPolicy policy = PublicPolicy.parse(policyJson());
  Future<ConsentStatus> Function()? onStatus;
  Future<PolicyAcceptance> Function(PolicyType, int)? onAccept;
  Completer<PublicPolicy>? delayedCurrent;
  int statusCalls = 0, accepts = 0;
  @override
  Future<ConsentStatus> status(SessionLease lease) async {
    statusCalls++;
    return onStatus != null ? onStatus!() : consent;
  }

  @override
  Future<PolicyAcceptance> accept(
    SessionLease lease,
    PolicyType type,
    int version,
  ) async {
    accepts++;
    if (onAccept != null) return onAccept!(type, version);
    consent = ConsentStatus.parse(consentJson());
    return PolicyAcceptance.parse({
      ...policyJson(version: version, type: type.wire),
      'accepted_at': null,
    });
  }

  @override
  Future<PublicPolicy> current(PolicyType type, {bool refresh = false}) async =>
      delayedCurrent != null ? delayedCurrent!.future : policy;
  @override
  Future<PolicyHistory> history(PolicyType type) async => PolicyHistory.parse({
    'type': type.wire,
    'label': type.label,
    'versions': [],
  });
  @override
  Future<PublicPolicy> version(PolicyType type, int version) async =>
      PublicPolicy.parse(policyJson(version: version, type: type.wire));
}

typedef Reply = FutureOr<ResponseBody> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.reply);
  final Reply reply;
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonReply(
  Object body, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
    ...headers,
  },
);
