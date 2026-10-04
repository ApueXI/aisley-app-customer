import '../../../core/networking/wire.dart';

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.shortDescription,
    required this.descriptionMarkdown,
    required this.specifications,
    required this.price,
    required this.originalPrice,
    required this.discountPercent,
    required this.badges,
    required this.averageRating,
    required this.reviewCount,
    required this.soldCount,
    required this.availability,
    required this.media,
    required this.optionGroups,
    required this.variants,
    required this.shop,
  });
  final String id, slug, title;
  final String? shortDescription, descriptionMarkdown;
  final Object? specifications;
  final double price;
  final double? originalPrice, averageRating;
  final int? discountPercent;
  final List<String> badges;
  final int reviewCount, soldCount;
  final ProductAvailability availability;
  final List<ProductMedia> media;
  final List<OptionGroup> optionGroups;
  final List<ProductVariant> variants;
  final ProductShop shop;

  factory ProductDetail.parse(Object? json) {
    final wire = Wire(json);
    final specifications = wire.field('specifications');
    final groups = wire.list('optionGroups', OptionGroup.parse).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final variants = wire.list('variants', ProductVariant.parse);
    final groupIds = groups.map((group) => group.id).toSet();
    for (final variant in variants) {
      if (variant.optionValueIds.length != groups.length) {
        throw const FormatException('Variant option groups are incomplete.');
      }
      if (groups.any(
        (group) =>
            group.values
                .where((value) => variant.optionValueIds.contains(value.id))
                .length !=
            1,
      )) {
        throw const FormatException(
          'Variant does not select exactly one value per group.',
        );
      }
      final valueIds = groups
          .expand((group) => group.values)
          .map((value) => value.id)
          .toSet();
      if (!valueIds.containsAll(variant.optionValueIds) ||
          variant.optionValueIds.toSet().length !=
              variant.optionValueIds.length) {
        throw const FormatException('Variant options are not listed.');
      }
    }
    if (groupIds.length != groups.length) {
      throw const FormatException('Duplicate Product option groups.');
    }
    return ProductDetail(
      id: wire.uuid('id'),
      slug: wire.string('slug'),
      title: wire.string('title'),
      shortDescription: wire.nullableString('shortDescription'),
      descriptionMarkdown: wire.nullableString('descriptionMarkdown'),
      specifications: _freezeJson(specifications),
      price: wire.number('price'),
      originalPrice: wire.nullableNumber('originalPrice'),
      discountPercent: wire.nullableInt('discountPercent'),
      badges: wire.strings('badges'),
      averageRating: wire.nullableNumber('averageRating'),
      reviewCount: wire.integer('reviewCount'),
      soldCount: wire.integer('soldCount'),
      availability: ProductAvailability.parse(wire.object('availability')),
      media: List.unmodifiable(
        wire.list('media', ProductMedia.parse).toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
      ),
      optionGroups: List.unmodifiable(groups),
      variants: List.unmodifiable(variants),
      shop: ProductShop.parse(wire.object('shop')),
    );
  }
}

class ProductAvailability {
  const ProductAvailability({
    required this.inStock,
    required this.stockQuantity,
    required this.requiresVariantSelection,
  });
  final bool inStock, requiresVariantSelection;
  final int? stockQuantity;

  factory ProductAvailability.parse(Object? json) {
    final wire = Wire(json);
    return ProductAvailability(
      inStock: wire.boolean('inStock'),
      stockQuantity: wire.nullableInt('stockQuantity'),
      requiresVariantSelection: wire.boolean('requiresVariantSelection'),
    );
  }
}

class ProductMedia {
  const ProductMedia({
    required this.id,
    required this.url,
    required this.altText,
    required this.position,
    required this.variantId,
  });
  final String? id, variantId;
  final String url, altText;
  final int position;

  factory ProductMedia.parse(Object? json) {
    final wire = Wire(json);
    return ProductMedia(
      id: _nullableUuid(wire, 'id'),
      url: wire.string('url'),
      altText: wire.string('altText'),
      position: wire.integer('position'),
      variantId: _nullableUuid(wire, 'variantId'),
    );
  }
}

class OptionGroup {
  const OptionGroup({
    required this.id,
    required this.name,
    required this.position,
    required this.values,
  });
  final String id, name;
  final int position;
  final List<OptionValue> values;

  factory OptionGroup.parse(Object? json) {
    final wire = Wire(json);
    return OptionGroup(
      id: wire.uuid('id'),
      name: wire.string('name'),
      position: wire.integer('position'),
      values: List.unmodifiable(
        wire.list('values', OptionValue.parse).toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
      ),
    );
  }
}

class OptionValue {
  const OptionValue({
    required this.id,
    required this.value,
    required this.position,
    required this.swatch,
  });
  final String id, value;
  final int position;
  final ProductSwatch swatch;

  factory OptionValue.parse(Object? json) {
    final wire = Wire(json);
    return OptionValue(
      id: wire.uuid('id'),
      value: wire.string('value'),
      position: wire.integer('position'),
      swatch: ProductSwatch.parse(wire.object('swatch')),
    );
  }
}

class ProductSwatch {
  const ProductSwatch({required this.color, required this.imageUrl});
  final String? color, imageUrl;

  factory ProductSwatch.parse(Object? json) {
    final wire = Wire(json);
    return ProductSwatch(
      color: wire.nullableString('color'),
      imageUrl: wire.nullableString('imageUrl'),
    );
  }
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.sku,
    required this.optionValueIds,
    required this.price,
    required this.originalPrice,
    required this.discountPercent,
    required this.stockQuantity,
    required this.inStock,
    required this.primaryMediaId,
  });
  final String id;
  final String? sku, primaryMediaId;
  final List<String> optionValueIds;
  final double price;
  final double? originalPrice;
  final int? discountPercent;
  final int stockQuantity;
  final bool inStock;

  factory ProductVariant.parse(Object? json) {
    final wire = Wire(json);
    final ids = wire.strings('optionValueIds');
    for (final id in ids) {
      if (!_uuid.hasMatch(id)) throw const FormatException('Invalid UUID.');
    }
    return ProductVariant(
      id: wire.uuid('id'),
      sku: wire.nullableString('sku'),
      optionValueIds: List.unmodifiable(ids),
      price: wire.number('price'),
      originalPrice: wire.nullableNumber('originalPrice'),
      discountPercent: wire.nullableInt('discountPercent'),
      stockQuantity: wire.integer('stockQuantity'),
      inStock: wire.boolean('inStock'),
      primaryMediaId: _nullableUuid(wire, 'primaryMediaId'),
    );
  }
}

class ProductShop {
  const ProductShop({
    required this.id,
    required this.slug,
    required this.name,
    required this.logoUrl,
    required this.isOnVacation,
    required this.vacationMessage,
    required this.storefrontUrl,
  });
  final String id, slug, name, storefrontUrl;
  final String? logoUrl, vacationMessage;
  final bool isOnVacation;

  factory ProductShop.parse(Object? json) {
    final wire = Wire(json);
    return ProductShop(
      id: wire.uuid('id'),
      slug: wire.string('slug'),
      name: wire.string('name'),
      logoUrl: wire.nullableString('logoUrl'),
      isOnVacation: wire.boolean('isOnVacation'),
      vacationMessage: wire.nullableString('vacationMessage'),
      storefrontUrl: wire.string('storefrontUrl'),
    );
  }
}

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$');

String? _nullableUuid(Wire wire, String key) {
  final value = wire.nullableString(key);
  if (value != null && !_uuid.hasMatch(value)) {
    throw const FormatException('Invalid UUID.');
  }
  return value;
}

Object? _freezeJson(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _freezeJson(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freezeJson));
  return value;
}
