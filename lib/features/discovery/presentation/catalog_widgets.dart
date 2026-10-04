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
    this.width = 184,
  });
  final ProductCard product;
  final DiscoveryRepository discovery;
  final VoidCallback onTap;
  final Widget? trailing;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: const Color(0xFFFFFBFD),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE8E1E6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CatalogImage(
                  url: product.thumbnailUrl,
                  discovery: discovery,
                  width: double.infinity,
                  height: 142,
                  label: product.title,
                ),
                if (trailing != null)
                  Positioned(top: 4, right: 4, child: trailing!),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₱${product.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    product.shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (product.averageRating != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFFB86B00),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${product.averageRating!.toStringAsFixed(1)} · ${product.reviewCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
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
      borderRadius: BorderRadius.circular(12),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      ?action,
    ],
  );
}
