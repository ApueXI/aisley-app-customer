@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/platform/strict_json_browser_adapter.dart';

@JS('eval')
external JSAny? _evaluate(JSString source);

void main() {
  late ApiClient client;
  setUp(() {
    _evaluate('globalThis.originalBuyerFetch = globalThis.fetch;'.toJS);
    client = ApiClient(
      AppConfig(
        apiBaseUrl: 'https://api.example.invalid/api/v1',
        storefrontOrigin: 'https://shop.example.invalid',
      ),
      publicClient: Dio()..httpClientAdapter = StrictJsonBrowserAdapter(),
      privateClient: Dio()..httpClientAdapter = StrictJsonBrowserAdapter(),
      deadline: const Duration(milliseconds: 500),
    );
  });
  tearDown(() {
    client.close();
    _evaluate('globalThis.fetch = globalThis.originalBuyerFetch;'.toJS);
  });
  test(
    'browser public JSON and bearer requests omit cookies and reject redirects',
    () async {
      _evaluate(
        '''
      globalThis.buyerRequests = [];
      globalThis.fetch = async function(url, options) {
        if (options.credentials !== 'omit' || options.redirect !== 'error') throw new Error('Unsafe options');
        buyerRequests.push({method: options.method, body: options.body, headers: options.headers});
        return new Response(JSON.stringify({message: 'OK'}), {status: 200, headers: {'Content-Type': 'application/json'}});
      };
    '''
            .toJS,
      );
      await client.request(
        'POST',
        'customer/auth/login',
        body: {'email': 'buyer@example.invalid', 'password': 'Synthetic123'},
      );
      final lease = SessionLease('synthetic-test-token', () => true, (_) {});
      await client.request('GET', 'customer/auth/me', lease: lease);
      expect(
        (_evaluate(
          'buyerRequests.length === 2 && !buyerRequests[0].headers.Authorization && !!buyerRequests[1].headers.Authorization'
              .toJS,
        ) as JSBoolean).toDart,
        true,
      );
      expect(
        (_evaluate(
          'JSON.parse(buyerRequests[0].body).email === "buyer@example.invalid"'
              .toJS,
        ) as JSBoolean).toDart,
        true,
      );
      lease.cancellation.cancel();
    },
  );
  test('redirect failure does not retry a password mutation', () async {
    _evaluate(
      '''
      globalThis.buyerCount = 0;
      globalThis.fetch = async function(url, options) {
        buyerCount++;
        if (options.redirect === 'error') throw new TypeError('Redirect rejected');
        throw new Error('Unsafe transport');
      };
    '''
          .toJS,
    );
    await expectLater(
      client.request('POST', 'customer/auth/login', body: {}),
      throwsA(isA<ApiFailure>()),
    );
    expect((_evaluate('buyerCount === 1'.toJS) as JSBoolean).toDart, true);
  });
  test('overall timeout aborts the actual browser fetch', () async {
    _evaluate(
      '''
      globalThis.buyerAborted = false;
      globalThis.fetch = (url, options) => new Promise((resolve, reject) => {
        options.signal.addEventListener('abort', () => { buyerAborted = true; reject(new DOMException('Aborted', 'AbortError')); });
      });
    '''
          .toJS,
    );
    await expectLater(
      client.request('POST', 'customer/auth/register', body: {}),
      throwsA(
        isA<ApiFailure>().having((f) => f.kind, 'kind', FailureKind.timeout),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect((_evaluate('buyerAborted'.toJS) as JSBoolean).toDart, true);
  });
}
