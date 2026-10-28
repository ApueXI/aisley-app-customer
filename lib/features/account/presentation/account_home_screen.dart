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
    builder: (context, _) {
      if (!session.active || session.customer == null) {
        return const SizedBox.shrink();
      }
      return ListView(
        padding: pagePadding(context),
        children: [
          _VerifiedAccountCard(
            displayName: session.customer?.displayName ?? 'Buyer',
            onEdit: () => context.push('/account/profile'),
          ),
          const SizedBox(height: 16),
          if (session.notice != null)
            Semantics(liveRegion: true, child: Text(session.notice!)),
          MarketShortcutGrid(
            children: [
              _AccountShortcut(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
                onTap: () => context.push('/orders'),
              ),
              _AccountShortcut(
                icon: Icons.local_offer_outlined,
                label: 'My Vouchers',
                onTap: () => context.push('/account/vouchers'),
              ),
              _AccountShortcut(
                icon: Icons.favorite_border,
                label: 'Wishlist',
                onTap: () => context.push('/account/wishlist'),
              ),
              _AccountShortcut(
                icon: Icons.history,
                label: 'Recently viewed',
                onTap: () => context.push('/account/recently-viewed'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MarketSection(
            title: 'Account details',
            child: Column(
              children: const [
                _AccountDestination(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  route: '/account/profile',
                ),
                _AccountDestination(
                  icon: Icons.location_on_outlined,
                  title: 'Address book',
                  route: '/account/addresses',
                ),
                _AccountDestination(
                  icon: Icons.lock_outline,
                  title: 'Password',
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
                  route: '/notifications',
                ),
                _AccountDestination(
                  icon: Icons.storefront_outlined,
                  title: 'Shop messages',
                  route: '/messages/shops',
                ),
                _AccountDestination(
                  icon: Icons.local_shipping_outlined,
                  title: 'Logistics messages',
                  route: '/messages/logistics',
                ),
                _AccountDestination(
                  icon: Icons.delivery_dining_outlined,
                  title: 'Courier messages',
                  route: '/messages/courier',
                ),
                _AccountDestination(
                  icon: Icons.help_outline,
                  title: 'Support tickets',
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
                  route: '/account/preferences',
                ),
                _AccountDestination(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  route: '/policies/terms_of_service',
                ),
                _AccountDestination(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  route: '/policies/privacy_policy',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
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
            child: Text(session.signingOut ? 'Signing out…' : 'Sign out'),
          ),
        ],
      );
    },
  );
}

class _VerifiedAccountCard extends StatelessWidget {
  const _VerifiedAccountCard({required this.displayName, required this.onEdit});

  final String displayName;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 420 ||
              MediaQuery.textScalerOf(context).scale(16) > 24;
          final identity = Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
                foregroundColor: Theme.of(context).colorScheme.secondary,
                child: const Icon(Icons.person_outline, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const MarketStatusLabel('Active'),
                  ],
                ),
              ),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _AccountShortcut extends StatelessWidget {
  const _AccountShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _AccountDestination extends StatelessWidget {
  const _AccountDestination({
    required this.icon,
    required this.title,
    required this.route,
  });
  final IconData icon;
  final String title, route;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 60),
    child: Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 60,
          minVerticalPadding: 8,
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
        ),
        const Divider(height: 1),
      ],
    ),
  );
}
