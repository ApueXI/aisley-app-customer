import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/commerce/commerce_value.dart';
import '../features/shop_messages/presentation/shop_screens.dart';
import '../features/logistics_messages/presentation/logistics_screens.dart';
import '../features/courier_messages/presentation/courier_screens.dart';
import '../features/notifications/presentation/notification_screens.dart';
import '../features/questions/presentation/questions_screen.dart';
import '../features/reviews/presentation/reviews_screen.dart';
import '../features/reviews/presentation/review_composer_screen.dart';
import '../features/support/presentation/support_screens.dart';
import 'app_dependencies.dart';

List<RouteBase> communicationRoutes(AppDependencies d) {
  Widget unavailable() => const Scaffold(
    body: Center(child: Text('This destination is unavailable.')),
  );
  bool plain(GoRouterState s) => d.communication != null && !s.uri.hasQuery;
  bool id(GoRouterState s) => plain(s) && validUuid(s.pathParameters['id']!);
  return [
    GoRoute(
      path: '/messages/shops',
      builder: (_, s) =>
          plain(s) ? ShopInboxScreen(dependencies: d) : unavailable(),
    ),
    GoRoute(
      path: '/messages/logistics',
      builder: (_, s) =>
          plain(s) ? LogisticsInboxScreen(dependencies: d) : unavailable(),
    ),
    GoRoute(
      path: '/messages/courier',
      builder: (_, s) =>
          plain(s) ? CourierInboxScreen(dependencies: d) : unavailable(),
    ),
    GoRoute(
      path: '/messages/shops/new/:id',
      builder: (_, s) {
        if (d.communication == null || !validShopEntry(s.uri)) {
          return unavailable();
        }
        return ShopThreadScreen(
          key: ValueKey(s.uri.toString()),
          dependencies: d,
          controller: d.communication!.shopThread(
            shop: s.pathParameters['id'],
            contextType: s.uri.queryParameters['context_type'],
            contextId: s.uri.queryParameters['context_id'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/messages/logistics/order/:id',
      builder: (_, s) => id(s)
          ? LogisticsThreadScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              controller: d.communication!.logisticsThread(
                order: s.pathParameters['id'],
              ),
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/messages/courier/order/:id',
      builder: (_, s) => id(s)
          ? CourierThreadScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              controller: d.communication!.courierThread(
                order: s.pathParameters['id'],
              ),
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/messages/shops/:id',
      builder: (_, s) => id(s)
          ? ShopThreadScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              controller: d.communication!.shopThread(
                id: s.pathParameters['id'],
              ),
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/messages/logistics/:id',
      builder: (_, s) => id(s)
          ? LogisticsThreadScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              controller: d.communication!.logisticsThread(
                id: s.pathParameters['id'],
              ),
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/messages/courier/:id',
      builder: (_, s) => id(s)
          ? CourierThreadScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              controller: d.communication!.courierThread(
                id: s.pathParameters['id'],
              ),
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, s) =>
          plain(s) ? NotificationInboxScreen(dependencies: d) : unavailable(),
    ),
    GoRoute(
      path: '/notifications/:id',
      builder: (_, s) => id(s)
          ? NotificationDetailScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              id: s.pathParameters['id']!,
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/products/:id/questions',
      builder: (_, s) => id(s)
          ? QuestionsScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              product: s.pathParameters['id']!,
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/products/:id/reviews',
      builder: (_, s) => id(s)
          ? ReviewsScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              product: s.pathParameters['id']!,
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/order-items/:id/review/:product',
      builder: (_, s) => id(s) && validUuid(s.pathParameters['product']!)
          ? ReviewComposerScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              controller: d.communication!.review(
                s.pathParameters['id']!,
                s.pathParameters['product']!,
              ),
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/support-tickets',
      builder: (_, s) =>
          plain(s) ? TicketInboxScreen(dependencies: d) : unavailable(),
    ),
    GoRoute(
      path: '/support-tickets/new',
      builder: (_, s) => plain(s)
          ? TicketComposerScreen(
              dependencies: d,
              controller: d.communication!.ticket(),
            )
          : unavailable(),
    ),
    GoRoute(
      path: '/support-tickets/:id',
      builder: (_, s) => id(s)
          ? TicketDetailScreen(
              key: ValueKey(s.uri.path),
              dependencies: d,
              controller: d.communication!.ticket(s.pathParameters['id']),
            )
          : unavailable(),
    ),
  ];
}

bool validShopEntry(Uri uri) {
  final p = uri.path.split('/');
  if (p.length != 5 ||
      p[1] != 'messages' ||
      p[2] != 'shops' ||
      p[3] != 'new' ||
      !validUuid(p[4])) {
    return false;
  }
  if (uri.queryParametersAll.values.any((v) => v.length != 1)) return false;
  if (uri.queryParameters.keys.any(
    (k) => k != 'context_type' && k != 'context_id',
  )) {
    return false;
  }
  if (!uri.hasQuery) return true;
  return const [
        'product',
        'order',
      ].contains(uri.queryParameters['context_type']) &&
      validUuid(uri.queryParameters['context_id'] ?? '');
}
