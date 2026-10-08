import 'package:flutter/material.dart';

import '../data/catalog_models.dart';
import '../data/discovery_repository.dart';
import 'catalog_image.dart';
export 'catalog_image.dart';

class ProductCardTile extends StatelessWidget {
  const ProductCardTile({
    super.key,
    required this.product,
    required this.discovery,
    required this.onTap,
    this.trailing,
    this.onAddToCart,
    this.width = 184,
  });
  final ProductCard product;
  final DiscoveryRepository discovery;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final Widget? trailing;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE8E1E6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: CatalogImage(
                        url: product.thumbnailUrl,
                        discovery: discovery,
                        width: double.infinity,
                        label: product.title,
                      ),
                    ),
                    if (trailing != null)
                      Positioned(top: 4, right: 4, child: trailing!),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: _ProductCardInformation(product: product),
                ),
              ],
            ),
          ),
          if (onAddToCart != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: FilledButton.tonalIcon(
                onPressed: onAddToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Cart'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ProductCardInformation extends StatelessWidget {
  const _ProductCardInformation({required this.product});
  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodySmall;
    final titleStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    final titleLine = _lineHeight(context, titleStyle);
    final metadataLine = _lineHeight(context, body);
    final shownPrice = product.minPrice ?? product.price;
    final ranged =
        product.minPrice != null &&
        product.maxPrice != null &&
        product.minPrice != product.maxPrice;
    final promotion =
        product.discountPercent != null && product.discountPercent! > 0
        ? '${product.discountPercent}% off'
        : product.originalPrice != null && product.originalPrice! > shownPrice
        ? 'Was ₱${product.originalPrice!.toStringAsFixed(2)}'
        : '';
    final metadata = [
      if (product.averageRating != null)
        '★ ${product.averageRating!.toStringAsFixed(1)} · ${product.reviewCount}',
      if (product.soldCount > 0) '${product.soldCount} sold',
    ].join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: titleLine * 2,
          child: Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: metadataLine,
          child: Text(
            '${ranged ? 'From ' : ''}₱${shownPrice.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: metadataLine,
          child: Text(
            promotion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body?.copyWith(
              decoration: promotion.startsWith('Was ')
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: metadataLine,
          child: Text(
            product.shop.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body,
          ),
        ),
        SizedBox(
          height: metadataLine,
          child: Text(
            metadata,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body,
          ),
        ),
      ],
    );
  }
}

double _lineHeight(BuildContext context, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: 'Ag', style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.height;
}

class ShopCardTile extends StatelessWidget {
  const ShopCardTile({
    super.key,
    required this.shop,
    required this.discovery,
    required this.onTap,
  });
  final ShopSummary shop;
  final DiscoveryRepository discovery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFE8E1E6)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CatalogImage(
                url: shop.logoUrl,
                discovery: discovery,
                width: 72,
                height: 72,
                label: '${shop.name} logo',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (shop.category != null) Text(shop.category!.name),
                  if (shop.description != null)
                    Text(
                      shop.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      );
      if (action == null) return heading;
      if (constraints.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, action!],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 16),
          action!,
        ],
      );
    },
  );
}
