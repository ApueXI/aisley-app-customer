import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/profile_screen.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_repository.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/address_form_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/home_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/product_detail_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/search_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/search_controller.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/saved_status_controller.dart';

import '../support/fakes.dart';
import '../support/account_fake.dart';

void main() {
  late SessionController session;
  late AppDependencies dependencies;
  late ApiClient api;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = FakeAuth(), policies = FakePolicies();
    session = SessionController(
      auth,
      policies,
      MemoryTokenStore()..token = 'synthetic-token',
    );
    await session.bootstrap();
    final home = fixture('customer-homepage', 'op-047'),
        detail = fixture('view-product', 'op-024'),
        products = fixture('search', 'op-019');
    final adapter = FakeAdapter((options) {
      if (options.uri.path.endsWith('/home')) return jsonReply(home);
      if (options.uri.path.contains('/products/search')) {
        return jsonReply(products);
      }
      if (options.uri.path.contains('/wishlist/status')) {
        return jsonReply({
          'data': {customerId: false},
        });
      }
      if (options.uri.path == '/api/v1/products/$customerId') {
        return jsonReply(detail);
      }
      return jsonReply({}, status: 404);
    });
    api = ApiClient(
      testConfig,
      publicClient: Dio()..httpClientAdapter = adapter,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    dependencies = AppDependencies(
      config: testConfig,
      auth: auth,
      policies: policies,
      session: session,
      launcher: TrustedLauncher(testConfig),
      discovery: DiscoveryRepository(api: api, session: session),
      accounts: FakeAccountRepository(),
      addresses: AddressRepository(api),
      guestRecent: GuestRecentStore(),
      recentlyViewed: RecentlyViewedRepository(api),
      savedStatus: SavedStatusController(session, WishlistRepository(api)),
    );
  });
  tearDown(() {
    dependencies.savedStatus!.dispose();
    dependencies.discovery!.dispose();
    session.dispose();
    api.close();
  });
  Future<void> show(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'profile hydrates without build errors and exposes date-only and read-only identity',
    (tester) async {
      await show(tester, ProfileScreen(dependencies: dependencies));
      expect(tester.takeException(), isNull);
      expect(find.text('buyer@example.invalid'), findsOneWidget);
      expect(find.text('Birthday'), findsOneWidget);
      await tester.ensureVisible(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('manual address form works at large text with maps disabled', (
    tester,
  ) async {
    await show(tester, AddressFormScreen(dependencies: dependencies));
    expect(find.textContaining('Choose address pin'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Home recommendation cards fit a narrow viewport at doubled text',
    (tester) async {
      await show(
        tester,
        Scaffold(body: HomeScreen(dependencies: dependencies)),
      );
      expect(find.text('Search Products and Shops'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('search controls and results fit doubled text and small height', (
    tester,
  ) async {
    await show(
      tester,
      SearchScreen(
        dependencies: dependencies,
        mode: SearchMode.products,
        query: 'buyer',
        page: 1,
        validRoute: true,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Products'), findsOneWidget);
    tester.view.physicalSize = const Size(360, 500);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Product detail records displayed detail when commerce is not configured',
    (tester) async {
      await show(
        tester,
        ProductDetailScreen(dependencies: dependencies, productId: customerId),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Purchasing is unavailable.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'profile draft cancel asks before leaving and successful save returns without discard',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Account hub')),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => ProfileScreen(dependencies: dependencies),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: buyerTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Draft');
      await tester.pump();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Leave this screen?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('Draft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
