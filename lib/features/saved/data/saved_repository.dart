import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import '../../discovery/data/catalog_models.dart';
import 'saved_models.dart';

class WishlistRepository {
  WishlistRepository(this.api);
  final ApiClient api;

  Future<CursorPage<WishlistEntry>> page(
    SessionLease lease, {
    String? cursor,
  }) async {
    final response = await api.request(
      'GET',
      'customer/wishlist',
      queryParameters: {'cursor': ?cursor},
      lease: lease,
    );
    return _cursorPage(response, WishlistEntry.parse);
  }

  Future<Map<String, bool>> statuses(
    SessionLease lease,
    List<String> productIds,
  ) async {
    if (productIds.isEmpty ||
        productIds.length > 50 ||
        productIds.toSet().length != productIds.length) {
      throw const ApiFailure(FailureKind.decode);
    }
    final response = await api.request(
      'GET',
      'customer/wishlist/status',
      queryParameters: {
        for (var i = 0; i < productIds.length; i++)
          'product_ids[$i]': productIds[i],
      },
      lease: lease,
    );
    final data = Wire(response).object('data');
    final result = <String, bool>{};
    for (final entry in data.entries) {
      if (!productIds.contains(entry.key) || entry.value is! bool) {
        throw const ApiFailure(FailureKind.decode);
      }
      result[entry.key] = entry.value as bool;
    }
    if (result.length != productIds.length) {
      throw const ApiFailure(FailureKind.decode);
    }
    return Map.unmodifiable(result);
  }

  Future<WishlistMutationResult> setSaved(
    SessionLease lease,
    String productId,
    bool saved,
  ) async {
    final response = await api.request(
      saved ? 'PUT' : 'DELETE',
      'customer/wishlist/${Uri.encodeComponent(productId)}',
      lease: lease,
    );
    return WishlistMutationResult.parse(Wire(response).object('data'));
  }

  Future<WishlistMutationResult> savedState(
    SessionLease lease,
    String productId,
  ) async {
    final result = await statuses(lease, [productId]);
    final saved = result[productId];
    if (saved == null) throw const ApiFailure(FailureKind.decode);
    return WishlistMutationResult(productId: productId, saved: saved);
  }
}

class RecentlyViewedRepository {
  RecentlyViewedRepository(this.api, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final ApiClient api;
  final DateTime Function() clock;

  Future<CursorPage<RecentlyViewedEntry>> page(
    SessionLease lease, {
    String? cursor,
    int limit = 20,
  }) async {
    final response = await api.request(
      'GET',
      'customer/recently-viewed',
      queryParameters: {'limit': limit, 'cursor': ?cursor},
      lease: lease,
    );
    return _cursorPage(response, RecentlyViewedEntry.parse);
  }

  Future<void> record(SessionLease lease, String productId) async {
    final response = await api.request(
      'PUT',
      'customer/recently-viewed/${Uri.encodeComponent(productId)}',
      lease: lease,
    );
    final data = Wire(Wire(response).object('data'));
    if (data.uuid('productId') != productId ||
        data.timestamp('lastViewedAt') == null) {
      throw const ApiFailure(FailureKind.decode);
    }
  }

  Future<bool> remove(SessionLease lease, String productId) async {
    final response = await api.request(
      'DELETE',
      'customer/recently-viewed/${Uri.encodeComponent(productId)}',
      lease: lease,
    );
    final data = Wire(Wire(response).object('data'));
    if (data.uuid('productId') != productId) {
      throw const ApiFailure(FailureKind.decode);
    }
    return data.boolean('removed');
  }

  Future<int> clear(SessionLease lease) async {
    final response = await api.request(
      'DELETE',
      'customer/recently-viewed',
      lease: lease,
    );
    final data = Wire(Wire(response).object('data'));
    final count = data.integer('removedCount');
    if (!data.boolean('cleared') || count < 0) {
      throw const ApiFailure(FailureKind.decode);
    }
    return count;
  }

  Future<RecentMergeResult> merge(
    SessionLease lease,
    List<GuestRecentHint> hints,
  ) async {
    final cutoff = clock().toUtc().subtract(const Duration(days: 365));
    final now = clock().toUtc();
    final eligible = hints
        .where(
          (hint) =>
              !hint.viewedAt.isAfter(now) && !hint.viewedAt.isBefore(cutoff),
        )
        .take(12)
        .toList();
    if (eligible.isEmpty) return const RecentMergeResult(productIds: []);
    final response = await api.request(
      'POST',
      'customer/recently-viewed/merge',
      body: {
        'items': [
          for (final hint in eligible)
            {
              'productId': hint.productId,
              'viewedAt': hint.viewedAt.toUtc().toIso8601String(),
            },
        ],
      },
      lease: lease,
    );
    final result = RecentMergeResult.parse(response);
    if (!eligible
        .map((hint) => hint.productId)
        .toSet()
        .containsAll(result.productIds)) {
      throw const ApiFailure(FailureKind.decode);
    }
    return result;
  }

  Future<List<ProductCard>> resolve(List<String> productIds) async {
    if (productIds.isEmpty ||
        productIds.length > 12 ||
        productIds.toSet().length != productIds.length) {
      throw const ApiFailure(FailureKind.decode);
    }
    final response = await api.request(
      'POST',
      'customer/products/resolve',
      body: {'productIds': productIds},
      readOnlyOperation: true,
    );
    return Wire(response).list('items', (value) => ProductCard.parse(value));
  }
}

CursorPage<T> _cursorPage<T>(
  Map<String, dynamic> response,
  T Function(Object?) parser,
) {
  final wire = Wire(response);
  final meta = Wire(wire.object('meta'));
  meta.string('path');
  meta.positiveInt('per_page');
  meta.nullableString('prev_cursor');
  final links = Wire(wire.object('links'));
  for (final field in ['first', 'last', 'prev', 'next']) {
    links.nullableString(field);
  }
  final cursor = meta.nullableString('next_cursor');
  if (cursor != null && cursor.length > 2048) {
    throw const ApiFailure(FailureKind.decode);
  }
  return CursorPage(items: wire.list('data', parser), nextCursor: cursor);
}
