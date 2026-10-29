import 'package:flutter/material.dart';

import '../data/catalog_models.dart';

class ProductCardInformation extends StatelessWidget {
  const ProductCardInformation({super.key, required this.product});
  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodySmall;
    final titleStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    final titleLine = _lineHeight(context, titleStyle);
    final shownPrice = product.minPrice ?? product.price;
    final ranged =
        product.minPrice != null &&
        product.maxPrice != null &&
        product.minPrice != product.maxPrice;
    final promotion =
        product.originalPrice != null && product.originalPrice! > shownPrice
        ? '₱${product.originalPrice!.toStringAsFixed(2)}'
        : '';
    final metadata = [
      if (product.averageRating != null)
        '★ ${product.averageRating!.toStringAsFixed(1)} · ${product.reviewCount}',
      if (product.soldCount > 0) '${product.soldCount} sold',
    ].join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.shop.name, style: body),
        const SizedBox(height: 4),
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
        Text(
          '${ranged ? 'From ' : ''}₱${shownPrice.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (promotion.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              promotion,
              style: body?.copyWith(decoration: TextDecoration.lineThrough),
            ),
          ),
        if (metadata.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(metadata, style: body),
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
  final height = painter.height;
  painter.dispose();
  return height;
}
