import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/home_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/product_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/shop_controllers.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';

import '../support/fakes.dart';

String idFor(int value) =>
    '${value.toString().padLeft(8, '0')}-1111-4111-8111-111111111111';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionController session;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = SessionController(
      FakeAuth(),
      FakePolicies(),
      MemoryTokenStore()..token = 'synthetic-token',
    );
    await session.bootstrap();
  });
  tearDown(() => session.dispose());
  DiscoveryRepository repository(FakeAdapter adapter) {
    final api = ApiClient(
      testConfig,
      publicClient: Dio()..httpClientAdapter = adapter,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    final repo = DiscoveryRepository(api: api, session: session);
    addTearDown(repo.dispose);
    return repo;
  }

  test('recommendations deduplicate IDs and stop at two hundred even when server has another cursor', () async {
    final home = fixture('customer-homepage', 'op-047');
    final item =
        fixture('search', 'op-019')['items'][0] as Map<String, dynamic>;
    var nextIndex = 1, pages = 0;
    Map<String, dynamic> page() => {
      'items': [
        for (var i = 0; i < 25; i++)
          <String, dynamic>{...item, 'id': idFor(nextIndex++)},
        <String, dynamic>{...item, 'id': idFor(1)},
      ],
      'nextCursor': 'cursor-${++pages}',
      'pageSize': 20,
    };
    home['recommendations'] = page();
    final adapter = FakeAdapter(
      (options) => jsonReply(
        options.uri.path.endsWith('/home') ? home : {'recommendations': page()},
      ),
    );
    final repo = repository(adapter);
    final controller = HomeController(
      discovery: repo,
      session: session,
      recentlyViewed: RecentlyViewedRepository(repo.api),
    );
    addTearDown(controller.dispose);
    await controller.load();
    while (controller.hasMore) {
      await controller.loadMore();
    }
    expect(controller.recommendations.length, 200);
    expect(
      controller.recommendations.map((item) => item.id).toSet().length,
      200,
    );
    final before = adapter.requests.length;
    await controller.loadMore();
    expect(adapter.requests.length, before);
  });
  test('recommendation failure preserves loaded items and is not an authoritative empty page', () async {
    final home = fixture('customer-homepage', 'op-047');
    home['recommendations']['nextCursor'] = 'next';
    final adapter = FakeAdapter(
      (options) => jsonReply(
        options.uri.path.endsWith('/home') ? home : {},
        status: options.uri.path.endsWith('/home') ? 200 : 503,
      ),
    );
    final repo = repository(adapter);
    final controller = HomeController(
      discovery: repo,
      session: session,
      recentlyViewed: RecentlyViewedRepository(repo.api),
    );
    addTearDown(controller.dispose);
    await controller.load();
    final ids = controller.recommendations.map((item) => item.id).toList();
    await controller.loadMore();
    expect(controller.recommendations.map((item) => item.id).toList(), ids);
    expect(controller.pageError, isNotNull);
    expect(controller.cursor, 'next');
  });
  test('variant selection uses only complete listed combinations and quantity stops at current stock', () async {
    final detail = fixture('view-product', 'op-024');
    final product = detail['data'] as Map<String, dynamic>;
    product['optionGroups'] = [
      <String, dynamic>{
        'id': idFor(10),
        'name': 'Size',
        'position': 1,
        'values': [
          <String, dynamic>{
            'id': idFor(11),
            'value': 'Small',
            'position': 1,
            'swatch': <String, dynamic>{'color': null, 'imageUrl': null},
          },
          <String, dynamic>{
            'id': idFor(12),
            'value': 'Large',
            'position': 2,
            'swatch': <String, dynamic>{'color': null, 'imageUrl': null},
          },
        ],
      },
    ];
    product['variants'] = [
      <String, dynamic>{
        'id': idFor(20),
        'sku': null,
        'optionValueIds': [idFor(11)],
        'price': 123,
        'originalPrice': null,
        'discountPercent': null,
        'stockQuantity': 2,
        'inStock': true,
        'primaryMediaId': null,
      },
    ];
    product['availability'] = <String, dynamic>{
      'inStock': true,
      'stockQuantity': null,
      'requiresVariantSelection': true,
    };
    final controller = ProductDetailController(
      repository(FakeAdapter((_) => jsonReply(detail))),
      customerId,
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.selectionValid, isFalse);
    controller.choose(idFor(10), idFor(99));
    expect(controller.selectedValues, isEmpty);
    controller.choose(idFor(10), idFor(12));
    expect(controller.selectionValid, isFalse);
    controller.choose(idFor(10), idFor(11));
    expect(controller.selectedVariant!.id, idFor(20));
    expect(controller.currentPrice, 123);
    controller.increment();
    controller.increment();
    expect(controller.quantity, 2);
    controller.choose(idFor(10), idFor(12));
    expect(controller.quantity, 1);
    expect(controller.available, isFalse);
  });
  test(
    'obsolete Shop category responses do not replace current filtered results',
    () async {
      final old = Completer<ResponseBody>();
      final adapter = FakeAdapter(
        (options) => options.uri.queryParameters['shop_category'] == 'old'
            ? old.future
            : jsonReply(fixture('browse-shop', 'op-021')),
      );
      final controller = ShopDirectoryController(repository(adapter));
      addTearDown(controller.dispose);
      final first = controller.setCategory('old');
      await Future<void>.delayed(Duration.zero);
      await controller.setCategory('new');
      final latest = controller.result;
      old.complete(jsonReply(fixture('browse-shop', 'op-021')));
      await first;
      expect(controller.category, 'new');
      expect(controller.result, same(latest));
    },
  );
  test('explicit Home refresh bypasses a fresh snapshot', () async {
    var calls = 0;
    final repo = repository(
      FakeAdapter((_) {
        calls++;
        return jsonReply(fixture('customer-homepage', 'op-047'));
      }),
    );
    await repo.home();
    await repo.home();
    expect(calls, 1);
    await repo.home(refresh: true);
    expect(calls, 2);
  });
}
