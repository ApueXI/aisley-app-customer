import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_repository.dart';

import '../support/fakes.dart';

void main() {
  for (final malformed in [false, true]) {
    test(
      'batch wire contract validates returned versions: malformed=$malformed',
      () async {
        late RequestOptions request;
        final dio = Dio();
        dio.httpClientAdapter = FakeAdapter((options) {
          request = options;
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'acceptances': [
                  {
                    ...policyJson(version: malformed ? 2 : 1),
                    'accepted_at': '2026-11-03T00:00:00Z',
                  },
                ],
                'status': consentJson(),
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
        final client = ApiClient(
          AppConfig(
            apiBaseUrl: 'https://api.example.invalid',
            storefrontOrigin: 'https://shop.example.invalid',
          ),
          privateClient: dio,
        );
        final repository = ApiPolicyRepository(client);
        final lease = SessionLease(
          'synthetic-policy-token',
          () => true,
          (_) {},
        );
        final result = repository.acceptTogether(lease, {PolicyType.terms: 1});
        if (malformed) {
          await expectLater(result, throwsA(isA<ApiFailure>()));
        } else {
          expect((await result).acceptances.single.version.version, 1);
        }
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/policy-consent/accept');
        expect(
          request.headers['Authorization'],
          'Bearer synthetic-policy-token',
        );
        expect(request.data, {
          'acceptances': [
            {'type': 'terms_of_service', 'version': 1, 'confirmation': true},
          ],
        });
        client.publicClient.close();
        dio.close();
      },
    );
  }
}
