import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/communication_state.dart';
import 'package:aisley_mobile_buyer/app/router.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/ui/marketplace_chrome.dart';
import 'package:aisley_mobile_buyer/core/ui/marketplace_widgets.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 3),
);

void main() {
  testWidgets(
    'mobile destinations retain Notifications state and utility pages open without the bottom bar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final harness = CommerceHarness();
      await tester.runAsync(harness.initialize);
      harness.reply = (request) {
        if (request.uri.path.endsWith('/notifications')) {
          return jsonReply(fixture('notifications', 'op-054'));
        }
        return harness.defaultReply(request);
      };
      final communication = CommunicationState(harness.session, harness.api);
      final dependencies = AppDependencies(
        config: testConfig,
        auth: harness.auth,
        policies: harness.policies,
        session: harness.session,
        launcher: TrustedLauncher(testConfig),
        client: harness.api,
        commerce: harness.commerce,
        communication: communication,
        discovery: DiscoveryRepository(
          api: harness.api,
          session: harness.session,
        ),
        recentlyViewed: RecentlyViewedRepository(harness.api),
      );
      addTearDown(dependencies.dispose);
      final router = buyerRouter(dependencies);
      addTearDown(router.dispose);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: buyerTheme(),
          routerConfig: router,
          builder: (context, child) => MarketplaceScope(
            active: dependencies.session.active,
            cartCount: dependencies.commerce!.cart.badge,
            child: child!,
          ),
        ),
      );
      await _settle(tester);

      NavigationBar navigationBar() =>
          tester.widget<NavigationBar>(find.byType(NavigationBar));

      expect(
        navigationBar().destinations.cast<NavigationDestination>().map(
          (destination) => destination.label,
        ),
        ['Home', 'Notifications', 'Account'],
      );
      expect(navigationBar().selectedIndex, 0);
      expect(find.byKey(const ValueKey('messages-action')), findsOneWidget);
      final cartActionFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.message?.startsWith('Cart') == true,
      );
      expect(cartActionFinder, findsOneWidget);
      expect(find.byTooltip('Terms and privacy'), findsOneWidget);

      navigationBar().onDestinationSelected!(1);
      await _settle(tester);
      expect(router.routeInformationProvider.value.uri.path, '/notifications');
      var tabs = tester.widget<MarketTabs<String>>(
        find.byType(MarketTabs<String>),
      );
      expect(tabs.selected, 'all');
      tabs.onSelected('unread');
      await _settle(tester);
      expect(
        tester
            .widget<MarketTabs<String>>(find.byType(MarketTabs<String>))
            .selected,
        'unread',
      );

      navigationBar().onDestinationSelected!(0);
      await _settle(tester);
      expect(router.routeInformationProvider.value.uri.path, '/');
      navigationBar().onDestinationSelected!(1);
      await _settle(tester);
      expect(
        tester
            .widget<MarketTabs<String>>(find.byType(MarketTabs<String>))
            .selected,
        'unread',
      );

      navigationBar().onDestinationSelected!(2);
      await _settle(tester);
      expect(router.routeInformationProvider.value.uri.path, '/account');
      navigationBar().onDestinationSelected!(1);
      await _settle(tester);
      expect(
        tester
            .widget<MarketTabs<String>>(find.byType(MarketTabs<String>))
            .selected,
        'unread',
      );

      router.push('/shops');
      await _settle(tester);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/shops',
      );
      expect(find.text('Explore Shops'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      router.pop();
      await _settle(tester);
      expect(navigationBar().selectedIndex, 1);

      await tester.tap(cartActionFinder);
      await _settle(tester);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/cart',
      );
      expect(find.text('Your Cart'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
      router.pop();
      await _settle(tester);
      expect(navigationBar().selectedIndex, 1);

      router.go('/notifications?unsupported=true');
      await _settle(tester);
      expect(find.text('This destination is unavailable.'), findsOneWidget);
      expect(navigationBar().selectedIndex, 1);
    },
  );
}
