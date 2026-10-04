import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_repository.dart';

void main() {
  final enabled = Platform.environment['BUYER_LIVE_API'] == '1';
  final config = AppConfig(
    apiBaseUrl: 'http://localhost:8000/api/v1',
    storefrontOrigin: 'http://localhost:3000',
    allowLocalHttp: true,
  );
  group(
    'authorized local API public smoke',
    () {
      late ApiClient client;
      late ApiPolicyRepository policies;
      setUp(() {
        client = ApiClient(config);
        policies = ApiPolicyRepository(client);
      });
      tearDown(() => client.close());
      for (final type in PolicyType.values) {
        test(
          '${type.wire} current/history/version matches typed contracts',
          () async {
            final current = await policies.current(type);
            final history = await policies.history(type);
            expect(current.type, type.wire);
            expect(history.type, type.wire);
            expect(history.versions, isNotEmpty);
            final version = await policies.version(
              type,
              current.version.version,
            );
            expect(version.version.id, current.version.id);
          },
        );
      }
      for (final path in ['customer/auth/me', 'policy-consent/status']) {
        test('unauthenticated $path denies access', () async {
          await expectLater(
            client.request('GET', path),
            throwsA(isA<ApiFailure>().having((f) => f.status, 'status', 401)),
          );
        });
      }
      test(
        'CORS permits exact Buyer origin and required POST headers',
        () async {
          final http = HttpClient();
          addTearDown(() => http.close(force: true));
          final request = await http.openUrl(
            'OPTIONS',
            config.apiUri('customer/auth/login'),
          );
          request.headers.set('Origin', 'http://localhost:8766');
          request.headers.set('Access-Control-Request-Method', 'POST');
          request.headers.set(
            'Access-Control-Request-Headers',
            'authorization,content-type',
          );
          final response = await request.close();
          expect(response.statusCode, 204);
          expect(
            response.headers.value('access-control-allow-origin'),
            'http://localhost:8766',
          );
          final allowed = response.headers
              .value('access-control-allow-headers')!
              .toLowerCase();
          expect(allowed, contains('authorization'));
          expect(allowed, contains('content-type'));
          await response.drain<void>();
        },
      );
    },
    skip: enabled ? false : 'Opt in with BUYER_LIVE_API=1; localhost API must already be running.',
  );
}
