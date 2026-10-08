import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'marketplace_chrome.dart';

/// A clearly outlined surface for one Product and its related controls.
class ProductBoundaryCard extends StatelessWidget {
  const ProductBoundaryCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    semanticContainer: false,
    color: Theme.of(context).colorScheme.surface,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: Color(0xFF8B8188)),
    ),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}

/// A section surface with one clear heading and optional next action.
class MarketSection extends StatelessWidget {
  const MarketSection({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    semanticContainer: false,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

/// Unlike an overlay, this area participates in the scaffold's layout.
class PurchaseBar extends StatelessWidget {
  const PurchaseBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final available =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = ((available - 200) * .45).clamp(32.0, 240.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          padding: EdgeInsets.all(maxHeight < 100 ? 8 : 16),
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}

/// Always keeps the content in the same slot across resize transitions.
class AccountContext extends StatelessWidget {
  const AccountContext({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final path =
        GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path ??
        '';
    final wide =
        MarketplaceScope.maybeOf(context)?.active == true &&
        marketplaceDesktop(context) &&
        path.startsWith('/account/');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide)
          SizedBox(
            width: 216,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in const {
                  '/account': 'My account',
                  '/orders': 'Orders',
                  '/account/wishlist': 'Wishlist',
                  '/account/recently-viewed': 'Recently viewed',
                  '/account/profile': 'Profile',
                  '/account/password': 'Password',
                  '/account/addresses': 'Address book',
                  '/account/preferences': 'Promotional messages',
                  '/support-tickets': 'Support tickets',
                }.entries)
                  ListTile(
                    selected: path == entry.key,
                    title: Text(entry.value),
                    onTap: () => context.push(entry.key),
                  ),
              ],
            ),
          ),
        Expanded(key: const ValueKey('account-content'), child: child),
      ],
    );
  }
}

class MarketTabs<T> extends StatelessWidget {
  const MarketTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
  });
  final Map<T, String> values;
  final T selected;
  final void Function(T) onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in values.entries)
        Semantics(
          selected: entry.key == selected,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: entry.key == selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: TextButton(
              onPressed: () => onSelected(entry.key),
              child: Text(entry.value),
            ),
          ),
        ),
    ],
  );
}
