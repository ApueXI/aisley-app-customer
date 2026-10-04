import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/security/session_controller.dart';
import '../core/ui/form_page.dart';
import 'commerce_state.dart';

class BuyerShell extends StatelessWidget {
  const BuyerShell({
    super.key,
    required this.navigation,
    required this.session,
    this.commerce,
  });
  final StatefulNavigationShell navigation;
  final SessionController session;
  final CommerceState? commerce;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: commerce?.cart ?? session,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('AISLEY'),
        actions: [
          IconButton(
            tooltip: 'Terms and privacy',
            icon: const Icon(Icons.policy_outlined),
            onPressed: () => context.push('/policies/terms_of_service'),
          ),
        ],
      ),
      body: SafeArea(child: navigation),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigation.currentIndex,
        onDestinationSelected: (index) {
          if (index == 2) commerce?.cart.load();
          navigation.goBranch(
            index,
            initialLocation: index == navigation.currentIndex,
          );
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Shops',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible:
                  commerce?.cart.badge != null && commerce!.cart.badge! > 0,
              label: Text('${commerce?.cart.badge ?? 0}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
      ),
    ),
  );
}

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.section, required this.session});
  final String section;
  final SessionController session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final private = section == 'Account' || section == 'Cart';
      if (private && !session.active) {
        return const Center(child: Text('Verifying access…'));
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  section == 'Home' ? 'Welcome to AISLEY' : section,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(switch (section) {
                  'Home' => 'Product discovery is not available in this version. You can sign in, register, or read our policies.',
                  'Shops' => 'Shop browsing is not available in this version.',
                  'Cart' =>
                    'Your shopping cart is not available in this version.',
                  _ => 'Profile and address management are not available in this version.',
                }),
                const SizedBox(height: 24),
                if (session.notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(session.notice!),
                  ),
                if (section == 'Account') ...[
                  Text(session.customer?.displayName ?? 'Buyer'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: session.signingOut
                        ? null
                        : () async {
                            if (await confirmDiscard(
                              context,
                              'Sign out of this Buyer account?',
                            )) {
                              await session.signOut();
                            }
                          },
                    child: const Text('Sign out'),
                  ),
                ] else if (section == 'Home') ...[
                  if (!session.active)
                    FilledButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Sign in'),
                    ),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Create an account'),
                  ),
                ],
                TextButton(
                  onPressed: () => context.push('/policies/terms_of_service'),
                  child: const Text('Terms of Service'),
                ),
                TextButton(
                  onPressed: () => context.push('/policies/privacy_policy'),
                  child: const Text('Privacy Policy'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => FormPage(
      title: 'Checking your session',
      children: [
        if (session.checking)
          const LinearProgressIndicator(semanticsLabel: 'Checking session'),
        Text(
          session.checking
              ? 'Verifying your account and current policy requirements…'
              : 'Your account could not be verified.',
        ),
        if (session.failure != null) FailureNotice(session.failure!),
        if (!session.checking)
          FilledButton(onPressed: session.retry, child: const Text('Retry')),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Public Home'),
        ),
        if (!session.checking)
          TextButton(
            onPressed: session.signOut,
            child: const Text('Sign out locally'),
          ),
      ],
    ),
  );
}

class ApprovalScreen extends StatelessWidget {
  const ApprovalScreen({super.key});
  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Registration submitted',
    children: [
      const Text(
        'Your registration is pending Admin approval. No sign-in session has been created.',
      ),
      const Text(
        'Try signing in after approval. Approval tracking and resubmission are unavailable in Buyer.',
      ),
      FilledButton(
        onPressed: () => context.go('/login'),
        child: const Text('Return to sign in'),
      ),
      TextButton(
        onPressed: () => context.go('/'),
        child: const Text('Public Home'),
      ),
    ],
  );
}
