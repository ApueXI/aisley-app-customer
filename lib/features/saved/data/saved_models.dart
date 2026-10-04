import '../../../core/networking/wire.dart';
import '../../discovery/data/catalog_models.dart';

class WishlistEntry {
  const WishlistEntry({
    required this.id,
    required this.savedAt,
    required this.product,
  });
  final String id;
  final DateTime savedAt;
  final ProductCard product;

  factory WishlistEntry.parse(Object? json) {
    final wire = Wire(json);
    return WishlistEntry(
      id: wire.uuid('id'),
      savedAt: wire.timestamp('savedAt')!,
      product: ProductCard.parse(wire.object('product'), wishlist: true),
    );
  }
}

class RecentlyViewedEntry {
  const RecentlyViewedEntry({
    required this.id,
    required this.lastViewedAt,
    required this.product,
  });
  final String id;
  final DateTime lastViewedAt;
  final ProductCard product;

  factory RecentlyViewedEntry.parse(Object? json) {
    final wire = Wire(json);
    return RecentlyViewedEntry(
      id: wire.uuid('id'),
      lastViewedAt: wire.timestamp('lastViewedAt')!,
      product: ProductCard.parse(wire.object('product')),
    );
  }
}

class CursorPage<T> {
  const CursorPage({required this.items, required this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}

class GuestRecentHint {
  const GuestRecentHint({required this.productId, required this.viewedAt});
  final String productId;
  final DateTime viewedAt;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'viewedAt': viewedAt.toUtc().toIso8601String(),
  };

  factory GuestRecentHint.parse(Object? value) {
    final wire = Wire(value);
    final date = wire.timestamp('viewedAt');
    if (date == null) throw const FormatException('Invalid recency time.');
    return GuestRecentHint(productId: wire.uuid('productId'), viewedAt: date);
  }
}

class WishlistMutationResult {
  const WishlistMutationResult({required this.productId, required this.saved});
  final String productId;
  final bool saved;

  factory WishlistMutationResult.parse(Object? json) {
    final wire = Wire(json);
    return WishlistMutationResult(
      productId: wire.uuid('productId'),
      saved: wire.boolean('saved'),
    );
  }
}

class RecentMergeResult {
  const RecentMergeResult({required this.productIds});
  final List<String> productIds;

  factory RecentMergeResult.parse(Object? json) {
    final wire = Wire(json);
    final data = Wire(wire.object('data'));
    final ids = data.strings('mergedProductIds');
    if (ids.toSet().length != ids.length ||
        data.integer('mergedCount') != ids.length) {
      throw const FormatException('Invalid merge acknowledgement.');
    }
    for (final id in ids) {
      if (!_uuid.hasMatch(id)) throw const FormatException('Invalid UUID.');
    }
    return RecentMergeResult(productIds: List.unmodifiable(ids));
  }
}

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$');
