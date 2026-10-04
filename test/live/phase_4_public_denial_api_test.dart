import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/networking/wire.dart';
import 'package:aisley_mobile_buyer/features/questions/data/question_repository.dart';
import 'package:aisley_mobile_buyer/features/reviews/data/review_repository.dart';

void main() {
  final enabled = Platform.environment['BUYER_LIVE_API'] == '1';
  final config = AppConfig(
    apiBaseUrl: 'http://localhost:8000',
    storefrontOrigin: 'http://localhost:3000',
    allowLocalHttp: true,
  );
  const id = '11111111-1111-4111-8111-111111111111';
  group(
    'Phase 4 public and denial localhost',
    () {
      late ApiClient api;
      setUp(() => api = ApiClient(config));
      tearDown(() => api.close());
      test('Public Q&A and Review pages parse with no bearer', () async {
        final home = await api.request('GET', 'customer/home');
        final items = [
          ...Wire(home).list('topProducts', (v) => Wire(v).uuid('id')),
          ...Wire(Wire(home).object('recommendations'))
              .list('items', (v) => Wire(v).uuid('id')),
        ];
        expect(
          items,
          isNotEmpty,
          reason: 'Public Product needed for this read-only check.',
        );
        final q = await QuestionRepository(api).list(items.first);
        expect(q.page, 1);
        final reviews = await ReviewRepository(api).list(items.first);
        expect(reviews.page, 1);
        expect(reviews.summary.count, greaterThanOrEqualTo(0));
      });
      for (final path in [
        'customer/conversations',
        'customer/conversations/$id',
        'customer/conversations/$id/messages',
        'customer/logistics-conversations',
        'customer/courier-conversations',
        'customer/courier-conversations/order-context/$id',
        'customer/notifications',
        'customer/notifications/$id',
        'customer/support-tickets',
        'customer/support-tickets/$id',
      ]) {
        test('GET $path denies unauthenticated access', () async {
          await expectLater(
            api.request('GET', path),
            throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
          );
        });
      }
      for (final path in [
        'customer/conversations',
        'customer/logistics-conversations',
        'customer/courier-conversations',
        'customer/support-tickets',
        'products/$id/questions',
        'customer/order-items/$id/review',
        'customer/reviews/$id/images',
      ]) {
        test('POST $path denies invalid bearer without a write', () async {
          final lease = SessionLease(
            'invalid-phase4-denial',
            () => true,
            (_) {},
          );
          addTearDown(() => lease.cancellation.cancel());
          await expectLater(
            api.request(
              'POST',
              path,
              lease: lease,
              body: {},
              idempotencyKey:
                  path.endsWith('/review') || path.endsWith('/images')
                  ? null
                  : id,
            ),
            throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
          );
        });
      }
      for (final path in [
        'customer/conversations',
        'customer/support-tickets',
        'products/$id/questions',
        'customer/reviews/$id/images',
      ]) {
        test('POST $path permits fixed-origin headers preflight', () async {
          final http = HttpClient();
          addTearDown(() => http.close(force: true));
          final request = await http.openUrl('OPTIONS', config.apiUri(path));
          request.headers.set('Origin', 'http://localhost:8766');
          request.headers.set('Access-Control-Request-Method', 'POST');
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
          await response.drain<void>();
        });
      }
    },
    skip: enabled
        ? false
        : 'Opt in with BUYER_LIVE_API=1; API must already be running.',
  );
}
