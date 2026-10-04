import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/recovery_screen.dart';
import '../features/auth/presentation/registration_screen.dart';
import '../features/policies/data/policy_models.dart';
import '../features/policies/presentation/consent_screen.dart';
import '../features/policies/presentation/policy_reader_screen.dart';
import 'app_dependencies.dart';
import 'router_guard.dart';
import 'shell_screen.dart';

GoRouter buyerRouter(AppDependencies dependencies) {
  final session = dependencies.session;
  Widget policy(GoRouterState state, {bool history = false}) {
    final type = PolicyType.fromWire(state.pathParameters['type'] ?? '');
    final version = history
        ? int.tryParse(state.pathParameters['version'] ?? '')
        : null;
    if (type == null || history && (version == null || version < 1)) {
      return const _Unavailable();
    }
    return PolicyReaderScreen(
      key: ValueKey(state.uri.path),
      repository: dependencies.policies,
      launcher: dependencies.launcher,
      type: type,
      version: version,
    );
  }

  return GoRouter(
    refreshListenable: session,
    redirect: (_, state) => guardRoute(session, state.uri),
    errorBuilder: (_, _) => const _Unavailable(),
    routes: [
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, navigation) => NoTransitionPage(
          key: state.pageKey,
          child: BuyerShell(navigation: navigation, session: session),
        ),
        branches: [
          for (final entry in {
            '/': 'Home',
            '/shops': 'Shops',
            '/cart': 'Cart',
            '/account': 'Account',
          }.entries)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: entry.key,
                  builder: (_, _) =>
                      ShellScreen(section: entry.value, session: session),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (_, state) => LoginScreen(
          session: session,
          returnTo: safeReturn(state.uri.queryParameters['returnTo']),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => RegistrationScreen(
          repository: dependencies.auth,
          clock: dependencies.clock,
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => RecoveryScreen(
          repository: dependencies.auth,
          launcher: dependencies.launcher,
        ),
      ),
      GoRoute(path: '/approval', builder: (_, _) => const ApprovalScreen()),
      GoRoute(
        path: '/session',
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: SessionScreen(session: session),
        ),
      ),
      GoRoute(
        path: '/consent',
        builder: (_, state) => ConsentScreen(
          repository: dependencies.policies,
          session: session,
          launcher: dependencies.launcher,
          returnTo: safeReturn(state.uri.queryParameters['returnTo']),
        ),
      ),
      GoRoute(path: '/policies/:type', builder: (_, state) => policy(state)),
      GoRoute(
        path: '/policies/:type/history/:version',
        builder: (_, state) => policy(state, history: true),
      ),
    ],
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Unavailable')),
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/'),
        child: const Text('Return to Home'),
      ),
    ),
  );
}
