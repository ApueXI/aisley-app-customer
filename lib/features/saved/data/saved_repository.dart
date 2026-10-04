import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

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

class GuestRecentStore {
  GuestRecentStore({
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? clock,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       clock = clock ?? DateTime.now;
  static const storageKey = 'buyer.public_recent_ids_v1';
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() clock;
  List<GuestRecentHint> _memory = const [];
  Future<void> _tail = Future.value();
  bool persisted = true;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<GuestRecentHint>> read() => _serial(_read);
  Future<List<GuestRecentHint>> _read() async {
    try {
      final values = (await _preferences()).getStringList(storageKey) ?? [];
      final parsed = <GuestRecentHint>[];
      for (final value in values) {
        try {
          parsed.add(GuestRecentHint.parse(jsonDecode(value)));
        } catch (_) {}
      }
      _memory = _bounded([...parsed, ..._memory]);
    } catch (_) {
      persisted = false;
    }
    return List.unmodifiable(_memory);
  }

  Future<void> record(String productId, DateTime viewedAt) => _serial(() async {
    final hint = GuestRecentHint.parse({
      'productId': productId,
      'viewedAt': viewedAt.toUtc().toIso8601String(),
    });
    final current = await _read();
    await _write(_bounded([hint, ...current]));
  });

  Future<void> removeAcknowledged(
    Iterable<String> productIds, {
    List<GuestRecentHint>? hints,
    bool Function()? canCommit,
  }) => _serial(() async {
    if (canCommit?.call() == false) return;
    final ids = productIds.toSet();
    final acknowledged = {
      for (final hint in hints ?? <GuestRecentHint>[])
        hint.productId: hint.viewedAt,
    };
    final current = await _read();
    await _write(
      current
          .where(
            (hint) =>
                !ids.contains(hint.productId) ||
                (hints != null &&
                    (acknowledged[hint.productId] == null ||
                        hint.viewedAt.isAfter(acknowledged[hint.productId]!))),
          )
          .toList(),
      canCommit: canCommit,
    );
  });

  Future<bool> remove(String productId) => _serial(() async {
    final current = await _read();
    await _write(current.where((hint) => hint.productId != productId).toList());
    return persisted;
  });

  Future<bool> clear() => _serial(() async {
    await _write(const []);
    return persisted;
  });

  List<GuestRecentHint> _bounded(Iterable<GuestRecentHint> values) {
    final now = clock().toUtc(),
        cutoff = clock().toUtc().subtract(const Duration(days: 365));
    final sorted =
        values
            .where(
              (hint) =>
                  !hint.viewedAt.isAfter(now) &&
                  !hint.viewedAt.isBefore(cutoff),
            )
            .toList()
          ..sort((left, right) => right.viewedAt.compareTo(left.viewedAt));
    final unique = <String, GuestRecentHint>{};
    for (final item in sorted) {
      unique.putIfAbsent(item.productId, () => item);
    }
    return unique.values.take(12).toList();
  }

  Future<void> _write(
    List<GuestRecentHint> values, {
    bool Function()? canCommit,
  }) async {
    try {
      final preferences = await _preferences();
      if (canCommit?.call() == false) return;
      _memory = _bounded(values);
      persisted = await preferences.setStringList(
        storageKey,
        _memory.map((hint) => jsonEncode(hint.toJson())).toList(),
      );
    } catch (_) {
      if (canCommit?.call() == false) return;
      _memory = _bounded(values);
      persisted = false;
    }
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
