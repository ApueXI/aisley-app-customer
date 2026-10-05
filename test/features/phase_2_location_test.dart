import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_models.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/map_location_service.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/psgc_loader.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/coordinate_dialog.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/psgc_fields.dart';

import '../support/fakes.dart';

class DiskAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

class MissingAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('Unavailable asset');
}

class CorruptRegionalAssets extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      key.endsWith('list-of-all-regions.json')
      ? File(key).readAsStringSync()
      : '{corrupt regional data';

  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();
}

class IncompleteHierarchyAssets extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.endsWith('list-of-all-regions.json')) {
      return File(key).readAsStringSync();
    }
    return jsonEncode({
      'region': {
        'psgc_code': '0100000000',
        'name': 'Region I (Ilocos Region)',
        'geographic_level': 'region',
        'children': [
          {
            'psgc_code': '0101000000',
            'name': 'Province',
            'geographic_level': 'province',
            'children': <Object>[],
          },
        ],
      },
    });
  }

  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();
}

class SelectorAssets extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.endsWith('list-of-all-regions.json')) {
      return File(key).readAsStringSync();
    }
    Map<String, dynamic> node(
      String code,
      String name,
      String level,
      List<Map<String, dynamic>> children,
    ) => {
      'psgc_code': code,
      'name': name,
      'geographic_level': level,
      'children': children,
    };
    if (key.contains('1300000000')) {
      return jsonEncode({
        'region': node(
          '1300000000',
          'National Capital Region (NCR)',
          'region',
          [
            node('1300100000', 'City', 'city', [
              node('1300100001', 'Barangay', 'barangay', []),
            ]),
          ],
        ),
      });
    }
    return jsonEncode({
      'region': node('0100000000', 'Region I (Ilocos Region)', 'region', [
        node('0101000000', 'Province', 'province', [
          node('0101010000', 'City', 'city', [
            node('0101010001', 'Barangay', 'barangay', []),
          ]),
        ]),
        node('0102000000', 'Direct City', 'city', [
          node('0102000001', 'Direct Barangay', 'barangay', []),
        ]),
      ]),
    });
  }

  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();
}

class DeniedLocation implements LocationAccess {
  int checks = 0, requests = 0, positions = 0;
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  @override
  Future<bool> serviceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async {
    checks++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<Position> position() async {
    positions++;
    throw StateError('GPS unavailable');
  }
}

AppConfig mapsConfig({
  bool requested = true,
  String key = 'synthetic-public-key',
}) => AppConfig(
  apiBaseUrl: 'https://api.example.invalid',
  storefrontOrigin: 'https://shop.example.invalid',
  mapsRequested: requested,
  geoapifyPublicApiKey: key,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all nineteen source-identical assets parse every hierarchy including NCR and direct cities', () async {
    final manifest =
        jsonDecode(File('assets/psgc/manifest.json').readAsStringSync()) as Map;
    expect((manifest['files'] as List).length, 19);
    for (final item in manifest['files'] as List) {
      final copied = File('assets/psgc/${item['file']}').readAsBytesSync();
      expect(copied.length, item['bytes']);
      expect(
        copied,
        File('docs/assets/psgc/${item['file']}').readAsBytesSync(),
      );
    }
    final loader = PsgcLoader(bundle: DiskAssets());
    final regions = await loader.regions();
    expect(regions.length, 18);
    var nodes = 0, barangays = 0, direct = 0;
    void visit(PsgcNode node) {
      nodes++;
      expect(node.code, matches(r'^\d{10}$'));
      expect(node.name, isNotEmpty);
      if (node.level == 'barangay') barangays++;
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final region in regions) {
      final dataset = await loader.dataset(region);
      visit(dataset.region);
      direct += dataset.directCities.length;
      for (final province in dataset.provinces) {
        for (final city in dataset.citiesUnder(province)) {
          expect(dataset.barangaysUnder(city), isNotEmpty);
        }
      }
      if (region.code == '1300000000') {
        expect(dataset.provinces, isEmpty);
        expect(dataset.directCities, isNotEmpty);
      }
    }
    expect(nodes, greaterThan(40000));
    expect(barangays, greaterThan(40000));
    expect(direct, greaterThan(16));
  });
  test(
    'incomplete hierarchy is rejected before it can be offered for selection',
    () async {
      final loader = PsgcLoader(bundle: IncompleteHierarchyAssets());
      final region = (await loader.regions()).first;
      await expectLater(loader.dataset(region), throwsFormatException);
    },
  );
  test('provider and GPS remain inactive until both public configuration inputs exist', () async {
    for (final config in [
      mapsConfig(requested: false),
      mapsConfig(key: ''),
      mapsConfig(key: '   '),
    ]) {
      final location = DeniedLocation();
      final adapter = FakeAdapter(
        (_) => throw StateError('Must not call provider'),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final service = MapLocationService(
        config,
        client: dio,
        location: location,
      );
      expect(await service.geocode('Synthetic address'), isEmpty);
      await expectLater(
        service.currentLocation(),
        throwsA(isA<MapProviderFailure>()),
      );
      expect(adapter.requests, isEmpty);
      expect(location.checks, 0);
      expect(location.requests, 0);
    }
  });
  test('intentional geocoding uses documented JSON, country filter and isolated credentials', () async {
    final adapter = FakeAdapter(
      (_) => jsonReply({
        'results': [
          {
            'lat': 14.6,
            'lon': 121.0,
            'country_code': 'ph',
            'formatted': 'Synthetic candidate',
          },
          {'lat': 95, 'lon': 121},
          {'lat': 14, 'lon': 121, 'country_code': 'us'},
        ],
      }),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final candidates = await MapLocationService(
      mapsConfig(),
      client: dio,
    ).geocode('Reviewed address');
    expect(candidates.single.label, 'Synthetic candidate');
    final request = adapter.requests.single;
    expect(request.uri.origin, 'https://api.geoapify.com');
    expect(request.uri.queryParameters, {
      'text': 'Reviewed address',
      'filter': 'countrycode:ph',
      'format': 'json',
      'limit': '1',
      'apiKey': 'synthetic-public-key',
    });
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(request.followRedirects, isFalse);
  });
  test('GPS asks foreground permission only on request and handles denial or disabled service', () async {
    final location = DeniedLocation();
    final service = MapLocationService(mapsConfig(), location: location);
    expect(location.checks, 0);
    await expectLater(
      service.currentLocation(),
      throwsA(isA<LocationChoiceFailure>()),
    );
    expect(location.requests, 1);
    expect(location.positions, 0);
    location.permission = LocationPermission.deniedForever;
    await expectLater(
      service.currentLocation(),
      throwsA(isA<LocationChoiceFailure>()),
    );
    expect(location.requests, 1);
    location.enabled = false;
    await expectLater(
      service.currentLocation(),
      throwsA(isA<LocationChoiceFailure>()),
    );
    expect(location.positions, 0);
  });
  test('provider rejection preserves an explicit failure', () async {
    final adapter = FakeAdapter((_) => jsonReply({}, status: 403));
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    await expectLater(
      MapLocationService(mapsConfig(), client: dio).geocode('Reviewed address'),
      throwsA(isA<MapProviderFailure>()),
    );
  });
  test('address parser accepts documented decimals and rejects incomplete coordinates', () {
    final row =
        fixture('address-book', 'op-015')['data'][0] as Map<String, dynamic>;
    expect(
      BuyerAddress.parse({...row, 'latitude': '14.6', 'longitude': '121.0'})
          .latitude,
      14.6,
    );
    expect(
      () => BuyerAddress.parse({...row, 'latitude': 14.6, 'longitude': null}),
      throwsA(isA<ApiFailure>()),
    );
  });
  testWidgets(
    'unavailable PSGC selectors show retry and block locality entry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PsgcFields(
              loader: PsgcLoader(bundle: MissingAssets()),
              onChange: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('unavailable. Retry before saving.'),
        findsOneWidget,
      );
      expect(find.text('Retry address choices'), findsOneWidget);
      expect(find.textContaining('manual'), findsNothing);
      for (final menu in tester.widgetList<DropdownMenu<String>>(
        find.byType(DropdownMenu<String>),
      )) {
        expect(menu.enabled, isFalse);
      }
    },
  );
  testWidgets(
    'corrupt regional data preserves unmatched saved text and blocks submission',
    (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: PsgcFields(
                  initialValues: const {
                    'region': 'Region I (Ilocos Region)',
                    'province': 'Saved province for review',
                    'city_municipality': 'Saved city for review',
                    'barangay': 'Saved barangay for review',
                  },
                  loader: PsgcLoader(bundle: CorruptRegionalAssets()),
                  onChange: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('choices are unavailable'), findsOneWidget);
      expect(find.text('Retry address choices'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      final cityMenu = tester.widget<DropdownMenu<String>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownMenu<String> &&
              widget.label is Text &&
              (widget.label! as Text).data == 'City / Municipality',
        ),
      );
      expect(cityMenu.controller!.text, 'Saved city for review');
      expect(cityMenu.enabled, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'numeric coordinates require a valid pair and explicit confirmation',
    (tester) async {
      GeoCandidate? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<GeoCandidate>(
                    context: context,
                    builder: (_) => const CoordinateDialog(),
                  );
                },
                child: const Text('Coordinates'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Coordinates'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '14.6');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(CoordinateDialog), findsOneWidget);
      await tester.enterText(fields.last, '121');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result!.latitude, 14.6);
      expect(result!.longitude, 121);
    },
  );
  testWidgets(
    'PSGC suggestions cascade by selected parents and clear descendants on parent edits',
    (tester) async {
      final changes = <Map<String, String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PsgcFields(
                loader: PsgcLoader(bundle: SelectorAssets()),
                onChange: changes.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder field(String label) {
        final menu = find.byWidgetPredicate(
          (widget) =>
              widget is DropdownMenu<String> &&
              widget.label is Text &&
              (widget.label! as Text).data == label,
        );
        return find.descendant(of: menu, matching: find.byType(TextField));
      }

      await tester.tap(field('Region'));
      await tester.pumpAndSettle();
      expect(find.text('Region I (Ilocos Region)'), findsWidgets);
      await tester.enterText(field('Region'), 'National Capital');
      await tester.pumpAndSettle();
      await tester.tap(find.text('National Capital Region (NCR)').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('Province'));
      await tester.tap(field('Province'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Province'), 'National Capital');
      await tester.pumpAndSettle();
      await tester.tap(find.text('National Capital Region (NCR)').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('City / Municipality'));
      await tester.tap(field('City / Municipality'));
      await tester.pumpAndSettle();
      await tester.enterText(field('City / Municipality'), 'City');
      await tester.pumpAndSettle();
      await tester.tap(find.text('City').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('Barangay'));
      await tester.tap(field('Barangay'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Barangay'), 'Barangay');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barangay').last);
      await tester.pumpAndSettle();
      expect(changes.last['barangay'], 'Barangay');
      await tester.ensureVisible(field('Region'));
      await tester.tap(field('Region'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Region'), 'Region I');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Region I (Ilocos Region)').last);
      await tester.pumpAndSettle();
      expect(changes.last, {
        'region': 'Region I (Ilocos Region)',
        'province': '',
        'city_municipality': '',
        'barangay': '',
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'typed exact locality text is not selected until an option is chosen',
    (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: PsgcFields(
                  loader: PsgcLoader(bundle: SelectorAssets()),
                  onChange: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final regionMenu = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownMenu<String> &&
            widget.label is Text &&
            (widget.label! as Text).data == 'Region',
      );
      final regionField = find.descendant(
        of: regionMenu,
        matching: find.byType(TextField),
      );
      await tester.tap(regionField);
      await tester.pumpAndSettle();
      await tester.enterText(regionField, 'National Capital Region (NCR)');
      await tester.pumpAndSettle();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DropdownMenu<String>>(regionMenu).errorText,
        'Choose a listed Region option.',
      );

      await tester.tap(find.text('National Capital Region (NCR)').last);
      await tester.pumpAndSettle();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownMenu<String>>(regionMenu).errorText, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('unmapped regional direct cities cannot be submitted', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: PsgcFields(
                initialValues: const {
                  'region': 'Region I (Ilocos Region)',
                  'province': 'Province',
                },
                loader: PsgcLoader(bundle: SelectorAssets()),
                onChange: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cityMenu = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownMenu<String> &&
          widget.label is Text &&
          (widget.label! as Text).data == 'City / Municipality',
    );
    final cityField = find.descendant(
      of: cityMenu,
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(cityField);
    await tester.tap(cityField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Direct City — regional direct city').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('has no supported Province mapping'),
      findsOneWidget,
    );
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    final provinceMenu = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownMenu<String> &&
          widget.label is Text &&
          (widget.label! as Text).data == 'Province',
    );
    expect(
      tester.widget<DropdownMenu<String>>(provinceMenu).errorText,
      'No supported Province mapping is available for this city.',
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'matching locality text hydrates through the selected hierarchy',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PsgcFields(
              loader: PsgcLoader(bundle: SelectorAssets()),
              initialValues: const {
                'region': 'National Capital Region (NCR)',
                'province': 'National Capital Region (NCR)',
                'city_municipality': 'City',
                'barangay': 'Barangay',
              },
              onChange: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in const {
        'Region': 'National Capital Region (NCR)',
        'Province': 'National Capital Region (NCR)',
        'City / Municipality': 'City',
        'Barangay': 'Barangay',
      }.entries) {
        final menu = tester.widget<DropdownMenu<String>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DropdownMenu<String> &&
                widget.label is Text &&
                (widget.label! as Text).data == entry.key,
          ),
        );
        expect(menu.controller?.text, entry.value);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
