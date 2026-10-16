import 'package:flutter/material.dart';

import '../data/catalog_models.dart';
import '../data/discovery_repository.dart';
import 'catalog_image.dart';
import 'product_card_information.dart';
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    if (product.discountPercent != null &&
                        product.discountPercent! > 0)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: Container(
                          color: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            '${product.discountPercent}% off',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  child: ProductCardInformation(product: product),
                ),
              ],
            ),
          ),
          if (onAddToCart != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: OutlinedButton(
                onPressed: onAddToCart,
                child: const Text('Add to Cart'),
              ),
            ),
        ],
      ),
    ),
  );
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
      final targetAction = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: action!,
      );
      if (constraints.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, targetAction],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 16),
          targetAction,
        ],
      );
    },
  );
}
