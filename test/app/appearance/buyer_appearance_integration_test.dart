import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/buyer_app.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_controller.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_scope.dart';
import 'package:aisley_mobile_buyer/app/appearance/appearance_tile.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';

import '../../support/fakes.dart';
import 'appearance_controller_test.dart' show MemoryAppearanceStore;

void main() {
  testWidgets(
    'Buyer Account offers appearance and retains it through sign out',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = FakeAuth(), policies = FakePolicies();
      final session = SessionController(
        auth,
        policies,
        MemoryTokenStore()..token = 'synthetic-token',
      );
      final appearance = AppearanceController(
        store: MemoryAppearanceStore(),
        defaultMode: ThemeMode.light,
      );
      await tester.pumpWidget(
        AppearanceRoot(
          controller: appearance,
          child: BuyerApp(
            dependencies: AppDependencies(
              config: testConfig,
              auth: auth,
              policies: policies,
              session: session,
              launcher: TrustedLauncher(testConfig),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go('/account');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(AppearanceTile),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/account');
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        Theme.of(tester.element(find.byType(AppearanceTile))).brightness,
        Brightness.dark,
      );
      await session.signOut();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
}
