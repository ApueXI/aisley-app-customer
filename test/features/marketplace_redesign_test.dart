import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/account_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';

void main() {
  const destinations = {
    'Orders': '/orders',
    'My Vouchers': '/account/vouchers',
    'Wishlist': '/account/wishlist',
    'Recently viewed': '/account/recently-viewed',
    'Profile': '/account/profile',
    'Address book': '/account/addresses',
    'Password': '/account/password',
    'Notifications': '/notifications',
    'Shop messages': '/messages/shops',
    'Logistics messages': '/messages/logistics',
    'Courier messages': '/messages/courier',
    'Support tickets': '/support-tickets',
    'Promotional messages': '/account/preferences',
    'Terms of Service': '/policies/terms_of_service',
    'Privacy Policy': '/policies/privacy_policy',
  };

  for (final width in [320.0, 390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'account destinations remain reachable at $width and text $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final session = SessionController(
            FakeAuth(),
            FakePolicies(),
            MemoryTokenStore()..token = 'synthetic-token',
          );
          await session.bootstrap();
          addTearDown(session.dispose);
          final router = GoRouter(
            initialLocation: '/account',
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, _) =>
                    Scaffold(body: AccountHomeScreen(session: session)),
              ),
              for (final route in destinations.values)
                GoRoute(
                  path: route,
                  builder: (_, _) => Scaffold(body: Text('Opened $route')),
                ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              theme: buyerTheme(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(session.active, isTrue);
          for (final entry in destinations.entries) {
            final target = find.text(entry.key);
            await tester.scrollUntilVisible(
              target,
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
            expect(find.text('Opened ${entry.value}'), findsOneWidget);
            router.pop();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
