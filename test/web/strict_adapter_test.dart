@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

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
  test('commerce UUID header survives Fetch and no automatic placement retry occurs', () async {
    _evaluate(
      "globalThis.buyerCount = 0; globalThis.fetch = async (url, options) => { buyerCount++; globalThis.buyerKey = options.headers['Idempotency-Key']; globalThis.buyerMode = JSON.parse(options.body).mode; return new Response(JSON.stringify({code:'QUOTE_STALE'}), {status:409, headers:{'Content-Type':'application/json'}}); }"
          .toJS,
    );
    final lease = SessionLease('synthetic-token', () => true, (_) {});
    await expectLater(
      client.request(
        'POST',
        'customer/checkout/place',
        body: {'mode': 'buy_now'},
        lease: lease,
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      (_evaluate(
        "buyerCount === 1 && buyerKey === '11111111-1111-4111-8111-111111111111' && buyerMode === 'buy_now'"
            .toJS,
      ) as JSBoolean).toDart,
      true,
    );
    lease.cancellation.cancel();
  });
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
  test('authenticated binary bytes and multipart content survive browser Fetch without false progress', () async {
    _evaluate(
      '''globalThis.buyerRequests = [];
      globalThis.fetch = async (url, options) => {
        buyerRequests.push(options);
        if (options.method === 'GET') return new Response(new Uint8Array([0, 128, 255]), {status: 200, headers: {'Content-Type': 'image/png'}});
        if (!(options.body instanceof Uint8Array)) throw new Error('Multipart must use bytes');
        const request = new Request(url, {method: 'POST', headers: options.headers, body: options.body});
        const form = await request.formData();
        const photo = form.get('photo');
        const bytes = new Uint8Array(await photo.arrayBuffer());
        globalThis.buyerMultipartValid = photo.name === 'synthetic.png' && photo.type === 'image/png' && bytes.length === 3 && bytes[0] === 0 && bytes[1] === 128 && bytes[2] === 255;
        return new Response(JSON.stringify({message:'OK'}), {status: 200, headers:{'Content-Type':'application/json'}});
      };'''
          .toJS,
    );
    final lease = SessionLease('synthetic-token', () => true, (_) {});
    expect(
      await client.requestBytes('customer/account/profile-photo', lease: lease),
      [0, 128, 255],
    );
    await client.uploadBytes(
      'customer/account/profile-photo',
      fieldName: 'photo',
      bytes: Uint8List.fromList([0, 128, 255]),
      filename: 'synthetic.png',
      mimeType: 'image/png',
      lease: lease,
    );
    expect(
      (_evaluate(
        'buyerMultipartValid && buyerRequests.every(o => o.credentials === "omit" && o.redirect === "error" && o.referrerPolicy === "no-referrer" && o.headers.Authorization === "Bearer synthetic-token")'
            .toJS,
      ) as JSBoolean).toDart,
      true,
    );
    lease.cancellation.cancel();
  });
  test(
    'empty 204 and binary account denial use the same session rules',
    () async {
      _evaluate(
        '''globalThis.fetch = async (url, options) => options.method === 'DELETE' ? new Response(null, {status:204}) : new Response(JSON.stringify({message:'Denied', code:'CUSTOMER_INACTIVE'}), {status:403,headers:{'Content-Type':'application/json'}});'''
            .toJS,
      );
      ApiFailure? denial;
      final lease = SessionLease(
        'synthetic-token',
        () => true,
        (failure) => denial = failure,
      );
      expect(
        await client.request(
          'DELETE',
          'customer/addresses/11111111-1111-4111-8111-111111111111',
          lease: lease,
        ),
        isEmpty,
      );
      await expectLater(
        client.requestBytes('customer/account/profile-photo', lease: lease),
        throwsA(isA<ApiFailure>().having((f) => f.status, 'status', 403)),
      );
      expect(denial?.code, 'CUSTOMER_INACTIVE');
      lease.cancellation.cancel();
    },
  );
  test(
    'only the isolated public map provider sends an origin referrer',
    () async {
      _evaluate(
        '''globalThis.fetch = async (url, options) => {globalThis.buyerReferrer = options.referrerPolicy; return new Response(JSON.stringify({results:[]}),{status:200,headers:{'Content-Type':'application/json'}});};'''
            .toJS,
      );
      final provider = Dio()
        ..httpClientAdapter = StrictJsonBrowserAdapter(publicMapProvider: true);
      await provider.get('https://api.geoapify.com/v1/geocode/search');
      expect(
        (_evaluate(
          'buyerReferrer === "strict-origin-when-cross-origin"'.toJS,
        ) as JSBoolean).toDart,
        true,
      );
      await provider.get('https://api.example.invalid/api/v1/public');
      expect(
        (_evaluate('buyerReferrer === "no-referrer"'.toJS) as JSBoolean).toDart,
        true,
      );
      provider.close(force: true);
    },
  );
}
