import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_repository.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/map_location_service.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/psgc_loader.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/address_form_screen.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/map_pin_dialog.dart';

import '../support/fakes.dart';

AppConfig mapConfig({bool enabled = true}) => AppConfig(
  apiBaseUrl: 'https://api.example.invalid',
  storefrontOrigin: 'https://shop.example.invalid',
  mapsRequested: enabled,
  geoapifyPublicApiKey: 'synthetic-public-key',
);

class NcrAssets extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.endsWith('list-of-all-regions.json')) {
      return File(key).readAsStringSync();
    }
    if (!key.contains('1300000000-')) {
      throw StateError('Unexpected regional asset: $key');
    }
    return jsonEncode({
      'region': {
        'psgc_code': '1300000000',
        'name': 'National Capital Region (NCR)',
        'geographic_level': 'region',
        'children': [
          {
            'psgc_code': '1380600000',
            'name': 'City of Manila',
            'geographic_level': 'city',
            'children': [
              {
                'psgc_code': '1380601000',
                'name': 'Barangay 1',
                'geographic_level': 'barangay',
                'children': <Object>[],
              },
            ],
          },
        ],
      },
    });
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

class UnavailableMaps extends MapLocationService {
  UnavailableMaps(super.config);
  int lookups = 0, gps = 0;
  @override
  Future<List<GeoCandidate>> geocode(String confirmedAddress) async {
    lookups++;
    throw const MapProviderFailure();
  }

  @override
  Future<GeoCandidate> currentLocation() async {
    gps++;
    throw const LocationChoiceFailure(
      'Permission denied. Save your manual address.',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDependencies dependencies;
  late ApiClient api;
  late GoRouter router;
  late UnavailableMaps maps;
  late Map<String, dynamic> row;
  late List<Map<String, dynamic>> writes;

  Future<void> open(
    WidgetTester tester, {
    bool mapsEnabled = true,
    double scale = 1,
  }) async {
    final loader = PsgcLoader(bundle: NcrAssets());
    final ncr = (await loader.regions()).firstWhere(
      (region) => region.code == '1300000000',
    );
    row =
        Map<String, dynamic>.from(
          (fixture('address-book', 'op-015')['data'] as List).first as Map,
        )..addAll({
          'region': ncr.name,
          'province': ncr.name,
          'cityMunicipality': 'City of Manila',
          'barangay': 'Barangay 1',
          'postalCode': '1000',
          'country': 'Philippines',
          'latitude': null,
          'longitude': null,
        });
    writes = [];
    final config = mapConfig(enabled: mapsEnabled);
    final auth = FakeAuth(), policies = FakePolicies();
    final session = SessionController(
      auth,
      policies,
      MemoryTokenStore()..token = 'synthetic-token',
    );
    await session.bootstrap();
    final adapter = FakeAdapter((options) {
      if (options.method == 'PATCH') {
        writes.add(Map<String, dynamic>.from(options.data as Map));
        return jsonReply({'data': row});
      }
      return jsonReply({
        'data': [row],
      });
    });
    api = ApiClient(
      config,
      publicClient: Dio()..httpClientAdapter = adapter,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    maps = UnavailableMaps(config);
    dependencies = AppDependencies(
      config: config,
      auth: auth,
      policies: policies,
      session: session,
      launcher: TrustedLauncher(config),
      addresses: AddressRepository(api),
      mapLocations: maps,
    );
    router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Saved addresses')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => AddressFormScreen(
                dependencies: dependencies,
                addressId: row['id'] as String,
                psgcLoader: loader,
              ),
            ),
          ],
        ),
      ],
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      router.dispose();
      dependencies.dispose();
      api.close();
    });
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
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  for (final failure in ['disabled', 'permission', 'provider']) {
    testWidgets('valid manual NCR address saves after $failure pin fallback', (
      tester,
    ) async {
      await open(tester, mapsEnabled: failure != 'disabled', scale: 2);
      if (failure != 'disabled') {
        await tap(tester, 'Pin location or use GPS');
        expect(find.byType(MapPinDialog), findsOneWidget);
        await tap(
          tester,
          failure == 'permission'
              ? 'Use current location'
              : 'Find this address on the map',
        );
        expect(find.text('Open location settings'), findsNothing);
        await tap(tester, 'Cancel pin');
        expect(find.byType(MapPinDialog), findsNothing);
      }
      await tap(tester, 'Save address');
      expect(writes, hasLength(1));
      expect(writes.single['region'], row['region']);
      expect(writes.single['province'], 'National Capital Region (NCR)');
      expect(writes.single['barangay'], row['barangay']);
      expect(writes.single['latitude'], isNull);
      expect(writes.single['longitude'], isNull);
      expect(find.text('Saved addresses'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('unselected exact Barangay text blocks save and provider entry', (
    tester,
  ) async {
    await open(tester);
    final selector = find.byWidgetPredicate(
      (w) => w is DropdownMenu<String> && (w.label as Text).data == 'Barangay',
    );
    final field = find.descendant(
      of: selector,
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '${row['barangay']}x');
    await tester.pumpAndSettle();
    await tester.enterText(field, row['barangay'] as String);
    await tester.pumpAndSettle();
    // Dismiss only the search menu; do not choose its matching option.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tap(tester, 'Save address');
    expect(writes, isEmpty);
    expect(find.text('Choose a listed Barangay option.'), findsOneWidget);
    await tap(tester, 'Pin location or use GPS');
    expect(find.byType(MapPinDialog), findsNothing);
    expect(maps.lookups, 0);
    expect(maps.gps, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
