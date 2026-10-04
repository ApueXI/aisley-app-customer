import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/recovery_screen.dart';
import '../features/auth/presentation/registration_screen.dart';
import '../features/policies/data/policy_models.dart';
import '../features/policies/presentation/consent_screen.dart';
import '../features/policies/presentation/policy_reader_screen.dart';
import '../features/account/presentation/account_home_screen.dart';
import '../features/account/presentation/profile_screen.dart';
import '../features/account/presentation/password_screen.dart';
import '../features/account/presentation/photo_screen.dart';
import '../features/account/presentation/preferences_screen.dart';
import '../features/addresses/presentation/address_book_screen.dart';
import '../features/addresses/presentation/address_form_screen.dart';
import '../features/discovery/presentation/home_screen.dart';
import '../features/discovery/presentation/search_screen.dart';
import '../features/discovery/presentation/search_controller.dart';
import '../features/discovery/presentation/shop_screen.dart';
import '../features/discovery/presentation/shop_directory_screen.dart';
import '../features/discovery/presentation/product_detail_screen.dart';
import '../features/saved/presentation/saved_products_screen.dart';
import '../features/saved/presentation/saved_products_controller.dart';
import '../core/commerce/commerce_value.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/checkout/presentation/batch_result_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/orders/presentation/order_detail_screen.dart';
import 'discovery_route_query.dart';
import 'communication_routes.dart';
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
      ...communicationRoutes(dependencies),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, navigation) => NoTransitionPage(
          key: state.pageKey,
          child: BuyerShell(
            navigation: navigation,
            session: session,
            commerce: dependencies.commerce,
          ),
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
                  builder: (_, state) {
                    if (entry.key == '/' && dependencies.discovery != null) {
                      return HomeScreen(dependencies: dependencies);
                    }
                    if (entry.key == '/shops' &&
                        dependencies.discovery != null) {
                      final query = DiscoveryRouteQuery.parse(
                        state.uri,
                        kind: 'directory',
                      );
                      return query.valid
                          ? ShopDirectoryScreen(
                              key: ValueKey(state.uri.toString()),
                              dependencies: dependencies,
                              category: query.category,
                              page: query.page,
                              limit: query.limit,
                            )
                          : const _Unavailable(embedded: true);
                    }
                    if (entry.key == '/cart' && dependencies.commerce != null) {
                      return CartScreen(dependencies: dependencies);
                    }
                    if (entry.key == '/account') {
                      return AccountHomeScreen(session: session);
                    }
                    return ShellScreen(section: entry.value, session: session);
                  },
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/checkout',
        builder: (_, state) =>
            dependencies.commerce != null && !state.uri.hasQuery
            ? CheckoutScreen(dependencies: dependencies)
            : const _Unavailable(),
      ),
      GoRoute(
        path: '/checkout/result/:batch',
        builder: (_, state) {
          final id = state.pathParameters['batch']!;
          return dependencies.commerce != null &&
                  validUuid(id) &&
                  !state.uri.hasQuery
              ? BatchResultScreen(
                  key: ValueKey(id),
                  dependencies: dependencies,
                  id: id,
                )
              : const _Unavailable();
        },
      ),
      GoRoute(
        path: '/orders',
        builder: (_, state) =>
            dependencies.commerce != null && !state.uri.hasQuery
            ? OrdersScreen(dependencies: dependencies)
            : const _Unavailable(),
      ),
      GoRoute(
        path: '/orders/:order',
        builder: (_, state) {
          final id = state.pathParameters['order']!;
          return dependencies.commerce != null &&
                  validUuid(id) &&
                  !state.uri.hasQuery
              ? OrderDetailScreen(
                  key: ValueKey(id),
                  dependencies: dependencies,
                  id: id,
                )
              : const _Unavailable();
        },
      ),
      GoRoute(
        path: '/search',
        builder: (_, state) {
          final query = DiscoveryRouteQuery.parse(state.uri, kind: 'search');
          return SearchScreen(
            key: ValueKey(state.uri.toString()),
            dependencies: dependencies,
            mode: query.mode == 'shops'
                ? SearchMode.shops
                : SearchMode.products,
            query: query.query,
            page: query.page,
            limit: query.limit,
            validRoute: query.valid,
          );
        },
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          if (!RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
              .hasMatch(id)) {
            return const _Unavailable();
          }
          return ProductDetailScreen(
            key: ValueKey(id),
            dependencies: dependencies,
            productId: id,
          );
        },
      ),
      GoRoute(
        path: '/shops/:slug',
        builder: (_, state) {
          final query = DiscoveryRouteQuery.parse(state.uri, kind: 'shop');
          if (!query.valid ||
              !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,254}$')
                  .hasMatch(state.pathParameters['slug']!)) {
            return const _Unavailable();
          }
          return ShopScreen(
            key: ValueKey(state.uri.toString()),
            dependencies: dependencies,
            slug: state.pathParameters['slug']!,
            query: query.query,
            category: query.category,
            page: query.page,
            limit: query.limit,
          );
        },
      ),
      GoRoute(
        path: '/account/profile',
        builder: (_, _) => ProfileScreen(dependencies: dependencies),
      ),
      GoRoute(
        path: '/account/password',
        builder: (_, _) => PasswordScreen(dependencies: dependencies),
      ),
      GoRoute(
        path: '/account/photo',
        builder: (_, _) => PhotoScreen(dependencies: dependencies),
      ),
      GoRoute(
        path: '/account/preferences',
        builder: (_, _) => PreferencesScreen(dependencies: dependencies),
      ),
      GoRoute(
        path: '/account/addresses',
        builder: (_, _) => AddressBookScreen(dependencies: dependencies),
      ),
      GoRoute(
        path: '/account/addresses/new',
        builder: (_, _) => AddressFormScreen(dependencies: dependencies),
      ),
      GoRoute(
        path: '/account/addresses/:id',
        builder: (_, state) => AddressFormScreen(
          dependencies: dependencies,
          addressId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/account/wishlist',
        builder: (_, _) => SavedProductsScreen(
          dependencies: dependencies,
          collection: SavedCollection.wishlist,
        ),
      ),
      GoRoute(
        path: '/account/recently-viewed',
        builder: (_, _) => SavedProductsScreen(
          dependencies: dependencies,
          collection: SavedCollection.recentlyViewed,
        ),
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
  const _Unavailable({this.embedded = false});
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This destination is unavailable.'),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    return embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Unavailable')),
            body: body,
          );
  }
}
