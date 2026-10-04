import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/discovery_route_query.dart';
import 'package:aisley_mobile_buyer/app/router_guard.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/networking/snapshot_cache.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/account/data/account_models.dart';
import 'package:aisley_mobile_buyer/features/account/data/account_repository.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_models.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_repository.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/product_detail_model.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_models.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';

import '../support/fakes.dart';

class CaptureAdapter implements HttpClientAdapter {
  CaptureAdapter(this.reply);
  final Reply reply;
  final requests = <RequestOptions>[];
  final payloads = <Uint8List>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = BytesBuilder();
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.add(chunk);
      }
    }
    payloads.add(bytes.takeBytes());
    return await reply(options);
  }

  @override
  void close({bool force = false}) {}
}

const profileInput = ProfileInput(
  firstName: 'Buyer',
  middleName: '',
  lastName: 'Example',
  contactNumber: '00000000000',
  sex: 'prefer_not_to_say',
  birthDate: '2000-01-01',
);
const addressInput = AddressInput(
  type: 'both',
  label: 'Home',
  recipientName: 'Buyer',
  contactNumber: '00000000000',
  addressLine1: 'Example street',
  addressLine2: null,
  barangay: 'Example barangay',
  cityMunicipality: 'Example city',
  province: 'Example province',
  region: 'Example region',
  postalCode: '0000',
  country: 'Philippines',
  latitude: 14.5,
  longitude: 121.0,
  isDefault: true,
);

void main() {
  late SessionController session;
  setUp(() async {
    session = SessionController(FakeAuth(), FakePolicies(), MemoryTokenStore());
    await session.bootstrap();
  });
  tearDown(() => session.dispose());

  test('public discovery uses documented endpoints, envelopes and scalar query keys', () async {
    final bodies = {
      '/api/v1/customer/home': fixture('customer-homepage', 'op-047'),
      '/api/v1/customer/home/recommendations': fixture(
        'customer-homepage',
        'op-048',
      ),
      '/api/v1/customer/products/search': fixture('search', 'op-019'),
      '/api/v1/customer/search/shops': fixture('search', 'op-020'),
      '/api/v1/customer/shops': fixture('browse-shop', 'op-021'),
      '/api/v1/customer/shops/demo': fixture('browse-shop', 'op-023'),
      '/api/v1/customer/shops/demo/products': fixture('browse-shop', 'op-022'),
      '/api/v1/products/$customerId': fixture('view-product', 'op-024'),
      '/api/v1/customer/products/resolve': fixture(
        'recently-viewed-items',
        'op-046',
      ),
    };
    final adapter = CaptureAdapter(
      (options) => jsonReply(bodies[options.uri.path]!),
    );
    final api = ApiClient(
      testConfig,
      publicClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    final repository = DiscoveryRepository(api: api, session: session);
    addTearDown(repository.dispose);
    expect((await repository.home()).recommendations.items, isNotEmpty);
    await repository.recommendations(cursor: 'opaque+/=', limit: 8);
    await repository.searchProducts(query: '%_', page: 3, limit: 8);
    await repository.searchShops(query: 'Demo', page: 2);
    await repository.shops(category: 'fashion');
    await repository.shop('demo');
    await repository.shopProducts(
      slug: 'demo',
      query: 'coat',
      category: 'jackets',
      page: 4,
    );
    expect((await repository.product(customerId)).media.single.id, isNull);
    await RecentlyViewedRepository(api).resolve([customerId]);
    expect(adapter.requests.map((request) => request.method), [
      'GET',
      'GET',
      'GET',
      'GET',
      'GET',
      'GET',
      'GET',
      'GET',
      'POST',
    ]);
    expect(
      adapter.requests.every(
        (request) => !request.headers.containsKey('Authorization'),
      ),
      isTrue,
    );
    expect(adapter.requests[1].uri.queryParameters, {
      'cursor': 'opaque+/=',
      'limit': '8',
    });
    expect(adapter.requests[2].uri.queryParameters, {
      'q': '%_',
      'page': '3',
      'limit': '8',
    });
    expect(adapter.requests[4].uri.queryParameters['shop_category'], 'fashion');
    expect(adapter.requests[6].uri.queryParameters, {
      'q': 'coat',
      'category': 'jackets',
      'page': '4',
      'limit': '20',
    });
    expect(adapter.requests.last.data, {
      'productIds': [customerId],
    });
  });

  test('account operations use full profile/password/preference bodies and authenticated multipart/image bytes', () async {
    final adapter = CaptureAdapter((options) {
      final path = options.uri.path;
      if (path.endsWith('profile-photo') && options.method == 'GET') {
        return ResponseBody.fromBytes(
          [137, 80, 78, 71],
          200,
          headers: {
            'content-type': ['image/png'],
          },
        );
      }
      final id = path.endsWith('profile-photo')
          ? options.method == 'POST'
                ? 'op-011'
                : 'op-012'
          : path.endsWith('profile')
          ? 'op-008'
          : path.endsWith('password')
          ? 'op-009'
          : path.endsWith('notification-preferences')
          ? options.method == 'PATCH'
                ? 'op-014'
                : 'op-013'
          : 'op-007';
      return jsonReply(fixture('account-management', id));
    });
    final api = ApiClient(
      testConfig,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    final lease = SessionLease('synthetic-test-token', () => true, (_) {});
    addTearDown(() => lease.cancellation.cancel());
    final repository = ApiAccountRepository(api);
    expect((await repository.account(lease)).email, isNotEmpty);
    await repository.updateProfile(lease, profileInput);
    await repository.updatePassword(
      lease,
      currentPassword: 'Synthetic123',
      password: 'Synthetic456',
      confirmation: 'Synthetic456',
    );
    expect(
      await repository.profilePhoto(
        lease,
        '/api/v1/customer/account/profile-photo?v=2',
      ),
      [137, 80, 78, 71],
    );
    await repository.uploadPhoto(
      lease,
      bytes: Uint8List.fromList([137, 80, 78, 71, 0, 255]),
      filename: 'photo.png',
      mimeType: 'image/png',
    );
    await repository.removePhoto(lease);
    await repository.promotionPreference(lease);
    await repository.setPromotionPreference(lease, false);
    expect(adapter.requests.map((request) => request.method), [
      'GET',
      'PATCH',
      'PATCH',
      'GET',
      'POST',
      'DELETE',
      'GET',
      'PATCH',
    ]);
    expect(
      adapter.requests.every(
        (request) =>
            request.headers['Authorization'] == 'Bearer synthetic-test-token',
      ),
      isTrue,
    );
    expect(adapter.requests[1].data, profileInput.toJson());
    expect(adapter.requests[1].data.keys, isNot(contains('email')));
    expect(adapter.requests[2].data, {
      'current_password': 'Synthetic123',
      'password': 'Synthetic456',
      'password_confirmation': 'Synthetic456',
    });
    expect(adapter.requests[3].uri.queryParameters, {'v': '2'});
    expect(adapter.requests.last.data, {'promotional_in_app_opted_in': false});
    final multipart = latin1.decode(adapter.payloads[4]);
    expect(multipart, contains('name="photo"; filename="photo.png"'));
    expect(multipart, contains('content-type: image/png'));
    expect(adapter.payloads[4], containsAllInOrder([137, 80, 78, 71, 0, 255]));
    expect(adapter.requests[4].sendTimeout, const Duration(seconds: 60));
    expect(
      adapter.requests[4].contentType,
      startsWith('multipart/form-data; boundary='),
    );
    await expectLater(
      repository.profilePhoto(
        lease,
        'https://evil.invalid/api/v1/customer/account/profile-photo',
      ),
      throwsFormatException,
    );
  });

  test('address CRUD has complete snake case bodies and accepts an empty 204 delete', () async {
    final adapter = CaptureAdapter(
      (options) => options.method == 'DELETE'
          ? ResponseBody.fromString('', 204)
          : jsonReply(
              fixture(
                'address-book',
                options.method == 'GET'
                    ? 'op-015'
                    : options.method == 'POST'
                    ? 'op-016'
                    : 'op-017',
              ),
            ),
    );
    final api = ApiClient(
      testConfig,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    final lease = SessionLease('synthetic-test-token', () => true, (_) {});
    addTearDown(() => lease.cancellation.cancel());
    final repository = AddressRepository(api);
    await repository.list(lease);
    await repository.create(lease, addressInput);
    await repository.update(lease, customerId, addressInput);
    await repository.delete(lease, customerId);
    expect(adapter.requests.map((request) => request.method), [
      'GET',
      'POST',
      'PATCH',
      'DELETE',
    ]);
    expect(adapter.requests[1].data, addressInput.toJson());
    expect(adapter.requests[2].data, addressInput.toJson());
    expect(adapter.requests[3].data, isNull);
    expect(adapter.requests[1].data.keys, isNot(contains('user_id')));
  });

  test('Wishlist and account recency use cursor/status arrays and empty mutation bodies', () async {
    final adapter = CaptureAdapter((options) {
      final path = options.uri.path;
      if (path.contains('wishlist')) {
        return jsonReply(
          fixture(
            'wishlist',
            path.endsWith('/status')
                ? 'op-038'
                : path.endsWith(customerId)
                ? options.method == 'PUT'
                      ? 'op-039'
                      : 'op-040'
                : 'op-037',
          ),
        );
      }
      return jsonReply(
        fixture(
          'recently-viewed-items',
          path.endsWith('/merge')
              ? 'op-045'
              : path.endsWith(customerId)
              ? options.method == 'PUT'
                    ? 'op-042'
                    : 'op-043'
              : options.method == 'GET'
              ? 'op-041'
              : 'op-044',
        ),
      );
    });
    final api = ApiClient(
      testConfig,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    final lease = SessionLease('synthetic-test-token', () => true, (_) {});
    addTearDown(() => lease.cancellation.cancel());
    final wishlist = WishlistRepository(api);
    final recent = RecentlyViewedRepository(
      api,
      clock: () => DateTime.utc(2026, 10, 4),
    );
    await wishlist.page(lease, cursor: 'opaque');
    await wishlist.statuses(lease, [customerId]);
    await wishlist.setSaved(lease, customerId, true);
    await wishlist.setSaved(lease, customerId, false);
    await recent.page(lease, cursor: 'next', limit: 50);
    await recent.record(lease, customerId);
    await recent.remove(lease, customerId);
    await recent.clear(lease);
    await recent.merge(lease, [
      GuestRecentHint(
        productId: customerId,
        viewedAt: DateTime.utc(2026, 10, 3),
      ),
    ]);
    expect(adapter.requests[0].uri.queryParameters, {'cursor': 'opaque'});
    expect(adapter.requests[1].uri.queryParameters, {
      'product_ids[0]': customerId,
    });
    expect(adapter.requests[4].uri.queryParameters, {
      'limit': '50',
      'cursor': 'next',
    });
    for (final index in [2, 3, 5, 6, 7]) {
      expect(adapter.requests[index].data, isNull);
    }
    expect((adapter.requests.last.data['items'] as List).single, {
      'productId': customerId,
      'viewedAt': '2026-10-03T00:00:00.000Z',
    });
  });

  test(
    'public cache expires at sixty seconds and evicts beyond 64 snapshots',
    () {
      var now = DateTime.utc(2026, 10, 4);
      final cache = SnapshotCache<int>(clock: () => now);
      for (var index = 0; index < 65; index++) {
        cache.put('$index', index);
      }
      expect(cache.get('0'), isNull);
      expect(cache.get('64'), 64);
      now = now.add(const Duration(seconds: 60));
      expect(cache.get('64'), isNull);
    },
  );

  test('route parsing rejects repeated/array/unknown/bounded query inputs and safe returns never carry mutations', () {
    for (final query in [
      'q=a&q=b',
      'q[]=a',
      'unknown=a',
      'page=0',
      'page=10001',
      'limit=7',
      'limit=51',
      'mode=sellers',
      'q=${'a' * 101}',
    ]) {
      expect(
        DiscoveryRouteQuery.parse(
          Uri.parse('/search?$query'),
          kind: 'search',
        ).valid,
        isFalse,
        reason: query,
      );
    }
    expect(
      DiscoveryRouteQuery.parse(
        Uri.parse('/search?q=%25_&mode=shops&page=2&limit=8'),
        kind: 'search',
      ).query,
      '%_',
    );
    expect(
      safeReturn('/search?q=coat&mode=products&page=2'),
      '/search?q=coat&mode=products&page=2',
    );
    expect(safeReturn('/products/$customerId'), '/products/$customerId');
    expect(safeReturn('/account/addresses'), '/account/addresses');
    for (final value in [
      '/products/not-an-id',
      '/account/addresses/new',
      '/cart?add=1',
      '/search?save=1',
      '//evil.invalid',
      '/account#token',
    ]) {
      expect(safeReturn(value), '/account');
    }
    expect(
      guardRoute(session, Uri.parse('/account/photo')),
      '/login?returnTo=%2Faccount%2Fphoto',
    );
  });

  test('required nullability and response types are strict', () {
    final data =
        fixture('view-product', 'op-024')['data'] as Map<String, dynamic>;
    expect(ProductDetail.parse(data).originalPrice, isNull);
    expect(
      () => ProductDetail.parse({...data}..remove('media')),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => ProductDetail.parse({...data, 'price': '100.00'}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => ProductDetail.parse({...data, 'averageRating': '4.5'}),
      throwsA(isA<ApiFailure>()),
    );
  });
}
