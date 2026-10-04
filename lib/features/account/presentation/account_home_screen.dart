import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/responsive_layout.dart';

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
        Text('Your account', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(session.customer?.displayName ?? 'Buyer'),
        const SizedBox(height: 20),
        if (session.notice != null)
          Semantics(liveRegion: true, child: Text(session.notice!)),
        _AccountDestination(
          icon: Icons.person_outline,
          title: 'Profile',
          subtitle: 'Name, contact information and birthday',
          route: '/account/profile',
        ),
        _AccountDestination(
          icon: Icons.photo_camera_back_outlined,
          title: 'Profile photo',
          subtitle: 'View or update your account photo',
          route: '/account/photo',
        ),
        _AccountDestination(
          icon: Icons.lock_outline,
          title: 'Password',
          subtitle: 'Change your current password',
          route: '/account/password',
        ),
        _AccountDestination(
          icon: Icons.notifications_outlined,
          title: 'Promotional messages',
          subtitle: 'Optional in-app promotional preference',
          route: '/account/preferences',
        ),
        _AccountDestination(
          icon: Icons.location_on_outlined,
          title: 'Address book',
          subtitle: 'Shipping and billing addresses',
          route: '/account/addresses',
        ),
        _AccountDestination(
          icon: Icons.receipt_long_outlined,
          title: 'Orders',
          subtitle: 'Status, tracking and permitted changes',
          route: '/orders',
        ),
        _AccountDestination(
          icon: Icons.favorite_border,
          title: 'Wishlist',
          subtitle: 'Products you saved',
          route: '/account/wishlist',
        ),
        _AccountDestination(
          icon: Icons.history,
          title: 'Recently viewed',
          subtitle: 'Products in your account history',
          route: '/account/recently-viewed',
        ),
        for (final entry in {
          '/notifications': 'Notifications',
          '/messages/shops': 'Shop messages',
          '/messages/logistics': 'Logistics messages',
          '/messages/courier': 'Courier messages',
          '/support-tickets': 'Support tickets',
        }.entries)
          _AccountDestination(
            icon: Icons.chat_bubble_outline,
            title: entry.value,
            subtitle: 'Open ${entry.value.toLowerCase()}',
            route: entry.key,
          ),
        const SizedBox(height: 20),
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      minTileHeight: 64,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    ),
  );
}
