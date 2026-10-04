import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';

void main() {
  final enabled = Platform.environment['BUYER_LIVE_API'] == '1';
  final config = AppConfig(
    apiBaseUrl: 'http://localhost:8000',
    storefrontOrigin: 'http://localhost:3000',
    allowLocalHttp: true,
  );
  const id = '11111111-1111-4111-8111-111111111111';
  group(
    'Phase 3 local denial and preflight',
    () {
      late ApiClient api;
      setUp(() => api = ApiClient(config));
      tearDown(() => api.close());
      for (final path in [
        'customer/cart',
        'customer/orders',
        'customer/orders/$id',
        'customer/orders/$id/tracking',
        'customer/checkout/$id',
      ]) {
        test('unauthenticated $path denies private facts', () async {
          await expectLater(
            api.request('GET', path),
            throwsA(isA<ApiFailure>().having((f) => f.status, 'status', 401)),
          );
        });
      }
      for (final entry in {
        'POST': 'customer/checkout/place',
        'PATCH': 'customer/orders/$id/modification',
      }.entries) {
        test(
          '${entry.key} permits exact-origin idempotency-header preflight',
          () async {
            final http = HttpClient();
            addTearDown(() => http.close(force: true));
            final request = await http.openUrl(
              'OPTIONS',
              config.apiUri(entry.value),
            );
            request.headers.set('Origin', 'http://localhost:8766');
            request.headers.set('Access-Control-Request-Method', entry.key);
            request.headers.set(
              'Access-Control-Request-Headers',
              'authorization,content-type,idempotency-key',
            );
            final response = await request.close();
            expect(response.statusCode, 204);
            expect(
              response.headers.value('access-control-allow-origin'),
              'http://localhost:8766',
            );
            final headers = response.headers
                .value('access-control-allow-headers')!
                .toLowerCase();
            expect(headers, contains('authorization'));
            expect(headers, contains('content-type'));
            expect(headers, contains('idempotency-key'));
            expect(
              response.headers
                  .value('access-control-allow-methods')!
                  .toUpperCase(),
              contains(entry.key),
            );
            await response.drain<void>();
          },
        );
      }
    },
    skip: enabled ? false : 'Opt in with BUYER_LIVE_API=1; localhost API must already be running.',
  );
}
