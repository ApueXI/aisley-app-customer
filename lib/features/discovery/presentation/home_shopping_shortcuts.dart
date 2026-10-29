import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/marketplace_surfaces.dart';

class HomeShoppingShortcuts extends StatelessWidget {
  const HomeShoppingShortcuts({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: MarketShortcutGrid(
      children: [
        MarketShortcut(
          icon: Icons.storefront_outlined,
          label: 'Shops',
          onTap: () => context.push('/shops'),
        ),
        if (dependencies.vouchers != null)
          MarketShortcut(
            icon: Icons.local_offer_outlined,
            label: 'Vouchers',
            onTap: () => context.push('/vouchers'),
          ),
        if (dependencies.commerce != null)
          MarketShortcut(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onTap: () => context.push('/orders'),
          ),
        if (dependencies.wishlist != null)
          MarketShortcut(
            icon: Icons.favorite_border,
            label: 'Wishlist',
            onTap: () => context.push('/account/wishlist'),
          ),
        MarketShortcut(
          icon: Icons.history,
          label: 'Recent',
          onTap: () => context.push('/account/recently-viewed'),
        ),
      ],
    ),
  );
}
