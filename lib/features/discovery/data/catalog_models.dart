import '../../../core/networking/wire.dart';

class Category {
  const Category({required this.id, required this.slug, required this.name});
  final String id, slug, name;

  factory Category.parse(Object? json) {
    final wire = Wire(json);
    return Category(
      id: wire.uuid('id'),
      slug: wire.string('slug'),
      name: wire.string('name'),
    );
  }
}

class ShopIdentity {
  const ShopIdentity({
    required this.id,
    required this.slug,
    required this.name,
  });
  final String id, slug, name;

  factory ShopIdentity.parse(Object? json) {
    final wire = Wire(json);
    return ShopIdentity(
      id: wire.uuid('id'),
      slug: wire.string('slug'),
      name: wire.string('name'),
    );
  }
}

class ShopSummary {
  const ShopSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.bannerUrl,
    required this.category,
  });
  final String id, slug, name;
  final String? description, logoUrl, bannerUrl;
  final Category? category;

  factory ShopSummary.parse(Object? json) {
    final wire = Wire(json);
    final category = wire.field('category');
    return ShopSummary(
      id: wire.uuid('id'),
      slug: wire.string('slug'),
      name: wire.string('name'),
      description: wire.nullableString('description'),
      logoUrl: wire.nullableString('logoUrl'),
      bannerUrl: wire.nullableString('bannerUrl'),
      category: category == null ? null : Category.parse(category),
    );
  }
}

class Pagination {
  const Pagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });
  final int currentPage, lastPage, perPage, total;
  bool get hasNext => currentPage < lastPage;

  factory Pagination.parse(Object? json) {
    final wire = Wire(json);
    return Pagination(
      currentPage: wire.positiveInt('currentPage'),
      lastPage: wire.positiveInt('lastPage'),
      perPage: wire.positiveInt('perPage'),
      total: wire.integer('total'),
    );
  }
}

class ProductDeal {
  const ProductDeal({
    required this.stock,
    required this.soldCount,
    required this.remainingStock,
    required this.progressPercent,
  });
  final int stock, soldCount, remainingStock, progressPercent;

  factory ProductDeal.parse(Object? json) {
    final wire = Wire(json);
    return ProductDeal(
      stock: wire.integer('stock'),
      soldCount: wire.integer('soldCount'),
      remainingStock: wire.integer('remainingStock'),
      progressPercent: wire.integer('progressPercent'),
    );
  }
}

class ProductCard {
  const ProductCard({
    required this.id,
    required this.slug,
    required this.title,
    required this.thumbnailUrl,
    required this.price,
    required this.originalPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.discountPercent,
    required this.averageRating,
    required this.reviewCount,
    required this.soldCount,
    required this.stockStatus,
    required this.shop,
    required this.badges,
    required this.deal,
    required this.requiresVariantSelection,
  });
  final String id, slug, title, stockStatus;
  final String? thumbnailUrl;
  final double price;
  final double? originalPrice, minPrice, maxPrice, averageRating;
  final int? discountPercent;
  final int reviewCount, soldCount;
  final ShopIdentity shop;
  final List<String> badges;
  final ProductDeal? deal;
  final bool? requiresVariantSelection;

  factory ProductCard.parse(Object? json, {bool wishlist = false}) {
    final wire = Wire(json);
    final dealJson = wire.data['deal'];
    final result = ProductCard(
      id: wire.uuid('id'),
      slug: wire.string('slug'),
      title: wire.string('title'),
      thumbnailUrl: wire.nullableString('thumbnailUrl'),
      price: wire.number('price'),
      originalPrice: wire.nullableNumber('originalPrice'),
      minPrice: wire.nullableNumber('minPrice'),
      maxPrice: wire.nullableNumber('maxPrice'),
      discountPercent: wire.nullableInt('discountPercent'),
      averageRating: wire.nullableNumber('averageRating'),
      reviewCount: wire.integer('reviewCount'),
      soldCount: wire.integer('soldCount'),
      stockStatus: wire.string('stockStatus'),
      shop: ShopIdentity.parse(wire.object('shop')),
      badges: wire.strings('badges'),
      deal: dealJson == null ? null : ProductDeal.parse(dealJson),
      requiresVariantSelection: wishlist
          ? wire.boolean('requiresVariantSelection')
          : null,
    );
    return result;
  }
}

List<T> parseList<T>(Object? value, T Function(Object?) parser) {
  if (value is! List) throw const FormatException('Expected a list.');
  return List<T>.unmodifiable(value.map(parser));
}

Map<String, dynamic> parseObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected an object.');
  }
  return value;
}
