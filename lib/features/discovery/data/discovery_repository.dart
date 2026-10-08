import 'dart:typed_data';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/snapshot_cache.dart';
import '../../../core/security/session_controller.dart';
import '../../../core/networking/wire.dart';
import 'catalog_models.dart';
import 'discovery_page_models.dart';
import 'home_models.dart';
import 'product_detail_model.dart';

class DiscoveryRepository {
  DiscoveryRepository({
    required this.api,
    required this.session,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now,
       _public = SnapshotCache<Object>(clock: clock ?? DateTime.now),
       _privateHome = SnapshotCache<Object>(clock: clock ?? DateTime.now) {
    session.registerPrivateCleanup(clearPrivate);
  }
  final ApiClient api;
  final SessionController session;
  final DateTime Function() clock;
  final SnapshotCache<Object> _public;
  final SnapshotCache<Object> _privateHome;

  int _privateEpoch = 0;
  void clearPrivate() {
    _privateEpoch++;
    _privateHome.clear();
  }

  void dispose() {
    session.unregisterPrivateCleanup(clearPrivate);
    clearPrivate();
    _public.clear();
  }

  Future<BuyerHome> home({int limit = 20, bool refresh = false}) async {
    final lease = session.active ? session.verifiedLease : null;
    final customerId = lease == null ? null : session.customer?.id;
    final key = 'home:$limit:${customerId ?? 'guest'}';
    if (lease == null) {
      return _cached(key, () async {
        final body = await api.request(
          'GET',
          'customer/home',
          queryParameters: {'limit': limit},
        );
        final result = _decode(() => BuyerHome.parse(body));
        if (result.viewer.isAuthenticated ||
            result.viewer.email != null ||
            result.viewer.deliveryLocation != null ||
            result.recentlyViewed.isNotEmpty) {
          throw const ApiFailure(FailureKind.decode);
        }
        return result;
      }, refresh: refresh);
    }
    final privateEpoch = _privateEpoch;
    final privateKey = '$key:${session.generation}';
    final existing = refresh ? null : _privateHome.get(privateKey);
    if (existing is BuyerHome) return existing;
    final body = await api.request(
      'GET',
      'customer/home',
      queryParameters: {'limit': limit},
      lease: lease,
    );
    final result = _decode(() => BuyerHome.parse(body));
    if (lease.isCurrent() && session.active && privateEpoch == _privateEpoch) {
      _privateHome.put(privateKey, result);
    }
    return result;
  }

  Future<HomeRecommendations> recommendations({
    String? cursor,
    int limit = 20,
  }) async {
    final lease = session.active ? session.verifiedLease : null;
    final response = await api.request(
      'GET',
      'customer/home/recommendations',
      queryParameters: {'limit': limit, 'cursor': ?cursor},
      lease: lease,
    );
    return _decode(
      () => HomeRecommendations.parse(response['recommendations']),
    );
  }

  Future<ProductSearchPage> searchProducts({
    required String query,
    int page = 1,
    int limit = 20,
  }) => _cached('product-search:${query.trim()}:$page:$limit', () async {
    final body = await api.request(
      'GET',
      'customer/products/search',
      queryParameters: {'q': query.trim(), 'page': page, 'limit': limit},
    );
    return _decode(() {
      final wire = Wire(body);
      return ProductSearchPage(
        items: wire.list('items', (value) => ProductCard.parse(value)),
        pagination: Pagination.parse(wire.object('pagination')),
      );
    });
  });

  Future<ShopSearchPage> searchShops({
    required String query,
    int page = 1,
    int limit = 20,
  }) => _cached('shop-search:${query.trim()}:$page:$limit', () async {
    final body = await api.request(
      'GET',
      'customer/search/shops',
      queryParameters: {'q': query.trim(), 'page': page, 'limit': limit},
    );
    return _decode(() {
      final wire = Wire(body);
      return ShopSearchPage(
        items: wire.list('items', ShopSummary.parse),
        pagination: Pagination.parse(wire.object('pagination')),
      );
    });
  });

  Future<ShopDirectoryPage> shops({
    String? category,
    int page = 1,
    int limit = 20,
  }) => _cached('shops:$category:$page:$limit', () async {
    final body = await api.request(
      'GET',
      'customer/shops',
      queryParameters: {
        'shop_category': ?category,
        'page': page,
        'limit': limit,
      },
    );
    return _decode(() {
      final wire = Wire(body);
      return ShopDirectoryPage(
        items: wire.list('items', ShopSummary.parse),
        categories: wire.list('categories', Category.parse),
        pagination: Pagination.parse(wire.object('pagination')),
      );
    });
  });

  Future<ShopSummary> shop(String slug) => _cached('shop:$slug', () async {
    final body = await api.request(
      'GET',
      'customer/shops/${Uri.encodeComponent(slug)}',
    );
    return _decode(() => ShopSummary.parse(body['data']));
  });

  Future<ShopProductPage> shopProducts({
    required String slug,
    String? query,
    String? category,
    int page = 1,
    int limit = 20,
  }) => _cached(
    'shop-products:$slug:${query?.trim()}:$category:$page:$limit',
    () async {
      final body = await api.request(
        'GET',
        'customer/shops/${Uri.encodeComponent(slug)}/products',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query.trim(),
          'category': ?category,
          'page': page,
          'limit': limit,
        },
      );
      return _decode(() {
        final wire = Wire(body);
        return ShopProductPage(
          shop: ShopSummary.parse(wire.object('shop')),
          categories: wire.list('categories', Category.parse),
          items: wire.list('items', (value) => ProductCard.parse(value)),
          pagination: Pagination.parse(wire.object('pagination')),
        );
      });
    },
  );

  Future<ProductDetail> product(String id, {bool refresh = false}) =>
      _cached('product:$id', () async {
        final body = await api.request(
          'GET',
          '/api/v1/products/${Uri.encodeComponent(id)}',
        );
        return _decode(() => ProductDetail.parse(body['data']));
      }, refresh: refresh);

  Future<Uint8List> publicMedia(String url) {
    final location = _apiLocation(url);
    final query = Uri(queryParameters: location.$2).query;
    final cacheKey = 'media:${location.$1}?$query';
    final cached = _public.get(cacheKey);
    if (cached is Uint8List) return Future.value(cached);
    if (cached is Future<Uint8List>) return cached;
    final request = api.requestBytes(location.$1, queryParameters: location.$2);
    // Keep in-flight and failed reads in the bounded short-lived cache too,
    // so a layout remount does not retry the same image immediately.
    _public.put(cacheKey, request);
    return request.then((bytes) {
      _public.put(cacheKey, bytes);
      return bytes;
    });
  }

  Future<Uint8List> privateMedia(String url, SessionLease lease) {
    final location = _apiLocation(url);
    return api.requestBytes(
      location.$1,
      queryParameters: location.$2,
      lease: lease,
    );
  }

  (String, Map<String, Object?>) _apiLocation(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasFragment || uri.userInfo.isNotEmpty) {
      throw const ApiFailure(FailureKind.decode);
    }
    final resolved = uri.hasAuthority
        ? uri
        : api.config.apiBase.resolveUri(uri);
    if (!api.config.trustsApi(resolved) ||
        !RegExp(
          r'^/api/v1/(?:product-media|product-description-assets|product-review-images|homepage-advertisement-images)/',
        ).hasMatch(resolved.path)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return (
      resolved.path,
      Map<String, Object?>.unmodifiable(resolved.queryParameters),
    );
  }

  Future<T> _cached<T extends Object>(
    String key,
    Future<T> Function() load, {
    bool refresh = false,
  }) async {
    final existing = refresh ? null : _public.get(key);
    if (existing is T) return existing;
    final value = await load();
    _public.put(key, value);
    return value;
  }

  T _decode<T extends Object>(T Function() parse) {
    try {
      return parse();
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
}
