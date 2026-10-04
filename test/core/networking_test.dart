import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_repository.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_repository.dart';

import '../support/fakes.dart';

void main() {
  test('transient reads retry once while mutations never retry', () async {
    var calls = 0;
    final adapter = FakeAdapter(
      (_) => ++calls == 1
          ? jsonReply({'message': 'Unavailable'}, status: 503)
          : jsonReply({'message': 'OK'}),
    );
    final client = ApiClient(
      testConfig,
      publicClient: Dio()..httpClientAdapter = adapter,
      readBackoff: Duration.zero,
    );
    addTearDown(client.close);
    await client.request('GET', 'platform/policies/terms_of_service');
    expect(calls, 2);
    calls = 0;
    await expectLater(
      client.request('POST', 'customer/auth/login', body: {}),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 1);
  });
  test(
    'config restricts cleartext to explicitly enabled local development',
    () {
      for (final url in [
        'http://api.example.invalid/api/v1',
        'https://u:p@example.invalid/api/v1',
        'https://api.example.invalid/api/v1?token=x',
        'https://api.example.invalid/api',
        'https://api.example.invalid/api/v2',
        'https://api.example.invalid?token=x',
        'https://api.example.invalid/#fragment',
      ]) {
        expect(
          () => AppConfig(
            apiBaseUrl: url,
            storefrontOrigin: 'https://shop.example.invalid',
          ),
          throwsFormatException,
        );
      }
      expect(
        () => AppConfig(
          apiBaseUrl: 'http://localhost:8000/api/v1',
          storefrontOrigin: 'http://localhost:3000',
        ),
        throwsFormatException,
      );
      expect(
        testConfig.apiUri('/api/v1/customer/auth/me').path,
        '/api/v1/customer/auth/me',
      );
      expect(testConfig.trustedLink('https://untrusted.invalid'), null);
      expect(testConfig.trustedLink('javascript:alert(1)'), null);
      expect(testConfig.trustedLink('mailto:buyer@example.invalid'), null);
      expect(testConfig.trustsApi(Uri.parse('javascript:alert(1)')), false);
      expect(
        testConfig.trustedLink('/reset-password')?.origin,
        'http://localhost:3000',
      );
    },
  );
  test(
    'API origin and versioned base resolve to the same trusted endpoints',
    () {
      for (final origin in [
        'http://127.0.0.1:8000',
        'http://localhost:8000',
        'http://10.0.2.2:8000',
        'https://api.example.invalid',
      ]) {
        for (final suffix in ['', '/', '/api/v1', '/api/v1/']) {
          final config = AppConfig(
            apiBaseUrl: '$origin$suffix',
            storefrontOrigin: 'https://shop.example.invalid',
            allowLocalHttp: origin.startsWith('http:'),
          );
          expect(config.apiBase.toString(), '$origin/api/v1');
          expect(config.apiBase.origin, origin);
          expect(
            config.apiUri('customer/auth/me').toString(),
            '$origin/api/v1/customer/auth/me',
          );
          expect(
            config.apiUri('/api/v1/customer/auth/me').toString(),
            '$origin/api/v1/customer/auth/me',
          );
          expect(
            config.trustsApi(Uri.parse('$origin/api/v1/customer/auth/me')),
            true,
          );
          expect(
            config.trustsApi(
              Uri.parse('https://untrusted.invalid/api/v1/customer/auth/me'),
            ),
            false,
          );
        }
      }
      expect(
        () => AppConfig(
          apiBaseUrl: 'http://127.0.0.1:8000',
          storefrontOrigin: 'https://shop.example.invalid',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'public request is credential-free; private bearer uses trusted origin',
    () async {
      final public = FakeAdapter((_) => jsonReply({'message': 'OK'}));
      final private = FakeAdapter((_) => jsonReply({'message': 'OK'}));
      final client = ApiClient(
        testConfig,
        publicClient: Dio()..httpClientAdapter = public,
        privateClient: Dio()..httpClientAdapter = private,
      );
      addTearDown(client.close);
      final lease = SessionLease('synthetic-test-token', () => true, (_) {});
      await client.request('GET', 'platform/policies/terms_of_service');
      await client.request('POST', 'customer/auth/logout', lease: lease);
      expect(
        public.requests.single.headers.containsKey('Authorization'),
        false,
      );
      expect(private.requests.single.headers['Authorization'], isNotNull);
      expect(private.requests.single.uri.origin, testConfig.apiBase.origin);
      expect(private.requests.single.followRedirects, false);
      expect(private.requests.single.data, null);
      lease.cancellation.cancel();
    },
  );
  test('malformed success never becomes an empty response', () async {
    final adapter = FakeAdapter((_) => jsonReply([]));
    final client = ApiClient(
      testConfig,
      publicClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.close);
    await expectLater(
      client.request('GET', 'platform/policies/terms_of_service'),
      throwsA(
        isA<ApiFailure>().having((f) => f.kind, 'kind', FailureKind.decode),
      ),
    );
  });
  test(
    'uncertain mutation is not retried; overall deadline cancels request',
    () async {
      final adapter = FakeAdapter((_) => Completer<ResponseBody>().future);
      final client = ApiClient(
        testConfig,
        publicClient: Dio()..httpClientAdapter = adapter,
        deadline: const Duration(milliseconds: 15),
      );
      addTearDown(client.close);
      await expectLater(
        client.request('POST', 'customer/auth/register', body: {}),
        throwsA(
          isA<ApiFailure>().having((f) => f.kind, 'kind', FailureKind.timeout),
        ),
      );
      expect(adapter.requests.length, 1);
    },
  );
  test('stale private errors never invalidate the new account', () async {
    final pending = Completer<ResponseBody>();
    var current = true, reported = 0;
    final adapter = FakeAdapter((_) => pending.future);
    final client = ApiClient(
      testConfig,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.close);
    final lease = SessionLease(
      'synthetic-test-token',
      () => current,
      (_) => reported++,
    );
    final request = client.request('GET', 'customer/auth/me', lease: lease);
    await Future<void>.delayed(Duration.zero);
    current = false;
    pending.complete(jsonReply({'message': 'Unauthenticated'}, status: 401));
    await expectLater(
      request,
      throwsA(
        isA<ApiFailure>().having((f) => f.kind, 'kind', FailureKind.cancelled),
      ),
    );
    expect(reported, 0);
    lease.cancellation.cancel();
  });
  test('errors support absent codes and integer/HTTP-date Retry-After', () {
    final now = DateTime.utc(2026, 10, 4);
    ApiFailure failure(String retry) => ApiFailure.response(
      Response(
        requestOptions: RequestOptions(),
        statusCode: 429,
        data: {'message': 'Too many attempts'},
        headers: Headers.fromMap({
          'retry-after': [retry],
        }),
      ),
      now,
    );
    expect(failure('60').retryAt, now.add(const Duration(seconds: 60)));
    expect(
      failure('Sun, 04 Oct 2026 00:01:00 GMT').retryAt,
      now.add(const Duration(seconds: 60)),
    );
    expect(failure('unknown').retryAt, null);
    expect(failure('60').code, null);
  });
  test(
    'DTOs parse supplied fixtures and reject missing/null/wrong required types',
    () {
      expect(
        LoginResult.parse(fixture('customer-auth', 'op-002'))
            .customer
            .isActiveCustomer,
        true,
      );
      expect(
        RegistrationResult.parse(fixture('customer-auth', 'op-001')).id,
        isNotEmpty,
      );
      expect(
        ConsentStatus.parse(fixture('policy-viewing-consent', 'op-082')['data'])
            .allRequiredAccepted,
        false,
      );
      expect(
        PublicPolicy.parse(fixture('policy-viewing-consent', 'op-084')['data'])
            .version
            .version,
        1,
      );
      expect(
        PolicyHistory.parse(fixture('policy-viewing-consent', 'op-085')['data'])
            .versions
            .length,
        1,
      );
      expect(
        PolicyAcceptance.parse(
          fixture('policy-viewing-consent', 'op-083')['data'],
        ).acceptedAt,
        null,
      );
      for (final payload in [
        identityJson()..remove('displayName'),
        identityJson()..['id'] = null,
        identityJson()..['status'] = true,
      ]) {
        expect(
          () => CustomerIdentity.parse(payload),
          throwsA(isA<ApiFailure>()),
        );
      }
      final login = fixture('customer-auth', 'op-002')..remove('token');
      expect(() => LoginResult.parse(login), throwsA(isA<ApiFailure>()));
      final consent = consentJson()..['all_required_accepted'] = 'false';
      expect(() => ConsentStatus.parse(consent), throwsA(isA<ApiFailure>()));
      expect(
        ConsentStatus.parse(consentJson(accepted: false)).allRequiredAccepted,
        true,
      );
    },
  );
  test(
    'auth operations use exact bodies, casing, envelopes and status',
    () async {
      final adapter = FakeAdapter((options) {
        final suffix = options.uri.path.split('/').last;
        return switch (suffix) {
          'login' => jsonReply(fixture('customer-auth', 'op-002')),
          'register' => jsonReply(
            fixture('customer-auth', 'op-001'),
            status: 201,
          ),
          'me' => jsonReply({'customer': identityJson()}),
          _ => jsonReply({'message': 'OK'}),
        };
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final client = ApiClient(
        testConfig,
        publicClient: dio,
        privateClient: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.close);
      final auth = ApiAuthRepository(client, deviceName: 'buyer-local-web');
      await auth.login(' Buyer@EXAMPLE.invalid ', 'Synthetic123');
      expect(adapter.requests.last.data, {
        'email': 'buyer@example.invalid',
        'password': 'Synthetic123',
        'device_name': 'buyer-local-web',
      });
      await auth.register(
        const RegistrationInput(
          firstName: 'Buyer',
          lastName: 'Example',
          contactNumber: '09000000000',
          sex: 'prefer_not_to_say',
          birthDate: '2000-01-01',
          email: ' Buyer@EXAMPLE.invalid ',
          password: 'Synthetic123',
          confirmation: 'Synthetic123',
        ),
      );
      final keys = (adapter.requests.last.data as Map).keys;
      expect(
        keys,
        unorderedEquals([
          'first_name',
          'last_name',
          'middle_name',
          'contact_number',
          'sex',
          'birth_date',
          'email',
          'password',
          'password_confirmation',
        ]),
      );
      await auth.forgotPassword(' Buyer@EXAMPLE.invalid ');
      expect(adapter.requests.last.data, {'email': 'buyer@example.invalid'});
      await auth.resetPassword(
        email: ' Buyer@EXAMPLE.invalid ',
        token: 'synthetic-reset-token',
        password: 'Synthetic123',
        confirmation: 'Synthetic123',
      );
      expect(
        adapter.requests.last.data,
        containsPair('password_confirmation', 'Synthetic123'),
      );
      final lease = SessionLease('synthetic-test-token', () => true, (_) {});
      await auth.me(lease);
      expect(adapter.requests.last.method, 'GET');
      expect(adapter.requests.last.data, null);
      await auth.logout(lease);
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.data, null);
      lease.cancellation.cancel();
    },
  );
  test(
    'policy public cache TTL and private no-store remain separate',
    () async {
      var now = DateTime.utc(2026, 10, 4);
      final adapter = FakeAdapter(
        (options) => jsonReply(
          options.uri.path.endsWith('status')
              ? {'data': consentJson()}
              : options.uri.path.endsWith('accept')
              ? {
                  'data': {...policyJson(), 'accepted_at': null},
                }
              : {'data': policyJson()},
        ),
      );
      final client = ApiClient(
        testConfig,
        publicClient: Dio()..httpClientAdapter = adapter,
        privateClient: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.close);
      final policies = ApiPolicyRepository(client, clock: () => now);
      await policies.current(PolicyType.terms);
      await policies.current(PolicyType.terms);
      expect(adapter.requests.length, 1);
      now = now.add(const Duration(seconds: 301));
      await policies.current(PolicyType.terms);
      expect(adapter.requests.length, 2);
      final lease = SessionLease('synthetic-test-token', () => true, (_) {});
      await policies.status(lease);
      await policies.status(lease);
      await policies.accept(lease, PolicyType.terms, 1);
      expect(adapter.requests.length, 5);
      expect(adapter.requests.last.data, {'confirmation': true});
      expect(
        adapter.requests.last.headers.containsKey('Idempotency-Key'),
        false,
      );
      lease.cancellation.cancel();
    },
  );
}
