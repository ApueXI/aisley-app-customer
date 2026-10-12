import 'package:flutter/material.dart';

import '../data/discovery_repository.dart';
import 'catalog_image.dart';

/// Public Product media beside authoritative item facts in checkout and Orders.
class ProductItemRow extends StatelessWidget {
  const ProductItemRow({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.discovery,
    required this.details,
  });

  final String? imageUrl;
  final String name;
  final DiscoveryRepository discovery;
  final List<Widget> details;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CatalogImage(
          url: imageUrl,
          discovery: discovery,
          width: 64,
          height: 64,
          label: 'Product image: $name',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: details,
        ),
      ),
    ],
  );
}
