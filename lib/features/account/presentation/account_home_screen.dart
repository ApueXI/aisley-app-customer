import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../../../core/ui/marketplace_surfaces.dart';
import '../../../core/security/session_controller.dart';
import '../../../core/ui/form_page.dart';

class AccountHomeScreen extends StatelessWidget {
  const AccountHomeScreen({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => ListView(
      padding: pagePadding(context),
      children: [
        const MarketPageHeading(title: 'Your account'),
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  size: 44,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    session.customer?.displayName ?? 'Buyer',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => context.push('/account/profile'),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (session.notice != null)
          Semantics(liveRegion: true, child: Text(session.notice!)),
        MarketSection(
          title: 'My shopping',
          child: MarketShortcutGrid(
            children: [
              MarketShortcut(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
                onTap: () => context.push('/orders'),
              ),
              MarketShortcut(
                icon: Icons.local_offer_outlined,
                label: 'My Vouchers',
                onTap: () => context.push('/account/vouchers'),
              ),
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
        const SizedBox(height: 16),
        MarketSection(
          title: 'Account details',
          child: Column(
            children: const [
              _AccountDestination(
                icon: Icons.person_outline,
                title: 'Profile',
                subtitle: 'Name, contact information, birthday and photo',
                route: '/account/profile',
              ),
              _AccountDestination(
                icon: Icons.location_on_outlined,
                title: 'Address book',
                subtitle: 'Shipping and billing addresses',
                route: '/account/addresses',
              ),
              _AccountDestination(
                icon: Icons.lock_outline,
                title: 'Password',
                subtitle: 'Change your current password',
                route: '/account/password',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MarketSection(
          title: 'Messages and help',
          child: Column(
            children: const [
              _AccountDestination(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Order updates and announcements',
                route: '/notifications',
              ),
              _AccountDestination(
                icon: Icons.storefront_outlined,
                title: 'Shop messages',
                subtitle: 'Questions about Products and purchases',
                route: '/messages/shops',
              ),
              _AccountDestination(
                icon: Icons.local_shipping_outlined,
                title: 'Logistics messages',
                subtitle: 'Contact your order’s handling team',
                route: '/messages/logistics',
              ),
              _AccountDestination(
                icon: Icons.delivery_dining_outlined,
                title: 'Courier messages',
                subtitle: 'Your delivery conversations',
                route: '/messages/courier',
              ),
              _AccountDestination(
                icon: Icons.help_outline,
                title: 'Support tickets',
                subtitle: 'Get help from AISLEY',
                route: '/support-tickets',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MarketSection(
          title: 'Settings and policies',
          child: Column(
            children: const [
              _AccountDestination(
                icon: Icons.tune,
                title: 'Promotional messages',
                subtitle: 'Choose whether to receive in-app promotions',
                route: '/account/preferences',
              ),
              _AccountDestination(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Read the current Terms',
                route: '/policies/terms_of_service',
              ),
              _AccountDestination(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How your information is handled',
                route: '/policies/privacy_policy',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: session.signingOut
              ? null
              : () async {
                  if (await confirmAction(
                    context,
                    title: 'Sign out?',
                    message: 'Sign out of this Buyer account?',
                    action: 'Sign out',
                  )) {
                    await session.signOut();
                  }
                },
          icon: const Icon(Icons.logout),
          label: Text(session.signingOut ? 'Signing out…' : 'Sign out'),
        ),
      ],
    ),
  );
}

class _AccountDestination extends StatelessWidget {
  const _AccountDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  final IconData icon;
  final String title, subtitle, route;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 56,
      minVerticalPadding: 12,
      visualDensity: VisualDensity.standard,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    ),
  );
}
