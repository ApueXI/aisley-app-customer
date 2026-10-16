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
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: MarketShortcutGrid(
          children: [
            if (dependencies.vouchers != null)
              MarketShortcut(
                icon: Icons.local_offer_outlined,
                label: 'Discover vouchers',
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
              label: 'Recently viewed',
              onTap: () => context.push('/account/recently-viewed'),
            ),
          ],
        ),
      ),
    ),
  );
}
