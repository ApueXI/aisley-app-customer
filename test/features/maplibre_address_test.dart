import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/geoapify_map_style.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/map_location_service.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/address_map_adapter.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/map_pin_dialog.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';

import '../support/fakes.dart';

const saved = GeoCandidate(label: 'Saved pin', latitude: 14.6, longitude: 121);
const adjusted = GeoCandidate(
  label: 'Adjusted pin',
  latitude: 14.61,
  longitude: 121.02,
);
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
AppConfig mapConfig({bool enabled = true}) => AppConfig(
  apiBaseUrl: 'https://api.example.invalid',
  storefrontOrigin: 'https://shop.example.invalid',
  mapsRequested: enabled,
  geoapifyPublicApiKey: 'synthetic-public-key',
);

class FakeMaps extends MapLocationService {
  FakeMaps(super.config);
  int geocodes = 0, tiles = 0;
  bool tileFails = false, malformedTile = false;
  Completer<List<GeoCandidate>>? lookup;
  final tilePoints = <GeoCandidate>[];
  @override
  Future<List<GeoCandidate>> geocode(String confirmedAddress) async {
    geocodes++;
    return lookup != null ? lookup!.future : [saved];
  }

  @override
  Future<List<int>> pinTile(
    GeoCandidate point, {
    CancelToken? cancelToken,
  }) async {
    tiles++;
    tilePoints.add(point);
    if (tileFails) throw const MapProviderFailure();
    return malformedTile ? [1, 2, 3] : png;
  }

  @override
  Future<GeoCandidate> currentLocation() async => adjusted;
}

class FakeMap implements AddressMapAdapter {
  Completer<void>? pending;
  bool prepareFails = false, disposed = false;
  int prepares = 0, builds = 0;
  GeoCandidate? initial;
  VoidCallback? ready, error;
  ValueChanged<GeoCandidate>? select;
  final moves = <({GeoCandidate point, bool recenter})>[];
  @override
  Future<void> prepare() async {
    prepares++;
    if (prepareFails) throw StateError('Synthetic library failure');
    await pending?.future;
  }

  @override
  Widget build({
    required String style,
    required GeoCandidate initial,
    required VoidCallback onReady,
    required VoidCallback onError,
    required ValueChanged<GeoCandidate> onSelect,
  }) {
    builds++;
    this.initial ??= initial;
    ready = onReady;
    error = onError;
    select = onSelect;
    return const Center(child: Text('Synthetic map'));
  }

  @override
  Future<void> setPin(GeoCandidate point, {required bool recenter}) async {
    moves.add((point: point, recenter: recenter));
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  late SessionController session;
  late AppDependencies dependencies;
  late FakeMaps maps;
  late FakeMap renderer;
  GeoCandidate? result;

  setUp(() async {
    final config = mapConfig();
    final auth = FakeAuth(), policies = FakePolicies();
    session = SessionController(
      auth,
      policies,
      MemoryTokenStore()..token = 'synthetic-token',
    );
    await session.bootstrap();
    maps = FakeMaps(config);
    renderer = FakeMap();
    result = null;
    dependencies = AppDependencies(
      config: config,
      auth: auth,
      policies: policies,
      session: session,
      launcher: TrustedLauncher(config),
      mapLocations: maps,
    );
  });
  tearDown(() => dependencies.dispose());

  Future<void> open(
    WidgetTester tester, {
    GeoCandidate? initial,
    AddressMapFactory? factory,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showAddressPinDialog(
                  context: context,
                  dependencies: dependencies,
                  addressText: 'Reviewed synthetic address',
                  initial: initial,
                  mapAdapterFactory: factory ?? () => renderer,
                );
              },
              child: const Text('Open pin'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open pin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // Image decoding completes outside the test binding's fake clock.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
  }

  test(
    'MapLibre style and tile probe use only the Geoapify public origin',
    () async {
      final config = mapConfig();
      final style = jsonDecode(geoapifyMapStyle('public key&value')) as Map;
      final source = style['sources']['geoapify'] as Map;
      final url = Uri.parse(source['tiles'][0] as String);
      expect(url.host, 'maps.geoapify.com');
      expect(url.queryParameters['apiKey'], 'public key&value');
      expect(style['version'], 8);
      final transport = FakeAdapter(
        (_) => ResponseBody.fromBytes(
          png,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        ),
      );
      final dio = Dio()..httpClientAdapter = transport;
      addTearDown(() => dio.close(force: true));
      final service = MapLocationService(config, client: dio);
      expect(await service.pinTile(saved), png);
      final request = transport.requests.single;
      expect(request.uri, geoapifyPinTile(14.6, 121, 'synthetic-public-key'));
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.headers['Accept'], 'image/png');
      expect(request.followRedirects, isFalse);
      expect(
        geoapifyPinTile(90, 180, 'test').path,
        '/v1/tile/osm-carto/16/65535/0.png',
      );
    },
  );

  test('disabled provider, tile denial and malformed tile remain explicit failures', () async {
    final transport = FakeAdapter((_) => jsonReply({}, status: 429));
    final dio = Dio()..httpClientAdapter = transport;
    addTearDown(() => dio.close(force: true));
    await expectLater(
      MapLocationService(mapConfig(enabled: false), client: dio).pinTile(saved),
      throwsA(isA<MapProviderFailure>()),
    );
    expect(transport.requests, isEmpty);
    await expectLater(
      MapLocationService(mapConfig(), client: dio).pinTile(saved),
      throwsA(isA<MapProviderFailure>()),
    );
  });

  testWidgets(
    'lookup is intentional and candidate review creates the map lazily',
    (tester) async {
      await open(tester);
      expect(maps.geocodes, 0);
      expect(maps.tiles, 0);
      expect(renderer.prepares, 0);
      await tap(tester, 'Find this address on the map');
      expect(maps.geocodes, 1);
      expect(renderer.prepares, 0);
      await tap(tester, 'Saved pin');
      expect(maps.tilePoints.single.latitude, 14.6);
      expect(renderer.initial!.longitude, 121);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      renderer.ready!();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      renderer.select!(
        adjusted,
      ); // Both tap and drag adapters report the same typed pair.
      await tester.pump();
      expect(renderer.moves.last.recenter, isFalse);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '14.610000',
      );
      await tap(tester, 'Use current location');
      expect(renderer.moves.last.recenter, isTrue);
      expect(maps.geocodes, 1);
      await tap(tester, 'Confirm these coordinates');
      await tester.pumpAndSettle();
      expect(result!.latitude, adjusted.latitude);
      expect(result!.longitude, adjusted.longitude);
      expect(renderer.disposed, isTrue);
    },
  );

  testWidgets(
    'saved pin survives library delay and later GPS selection is retained',
    (tester) async {
      renderer.pending = Completer<void>();
      await open(tester, initial: saved);
      expect(renderer.builds, 0);
      await tap(tester, 'Use current location');
      expect(renderer.moves.single.point.longitude, adjusted.longitude);
      renderer.pending!.complete();
      await tester.pump();
      expect(renderer.initial!.longitude, adjusted.longitude);
      renderer.ready!();
      await tap(tester, 'Cancel pin');
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(renderer.disposed, isTrue);
    },
  );

  testWidgets('system back cancels the pin and disposes its map', (
    tester,
  ) async {
    await open(tester, initial: saved);
    renderer.ready!();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(renderer.disposed, isTrue);
    expect(find.text('Open pin'), findsOneWidget);
  });

  testWidgets(
    'tile failure keeps numeric inputs and deliberate retry uses a fresh renderer',
    (tester) async {
      maps.tileFails = true;
      final renderers = <FakeMap>[];
      await open(
        tester,
        initial: saved,
        factory: () {
          final map = FakeMap();
          renderers.add(map);
          return map;
        },
      );
      expect(find.text('Retry map'), findsOneWidget);
      expect(renderers.single.disposed, isTrue);
      expect(maps.geocodes, 0);
      maps.tileFails = false;
      await tap(tester, 'Retry map');
      expect(renderers.length, 2);
      expect(renderers.last.builds, greaterThan(0));
      renderers.last.ready!();
      await tester.pump();
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'NaN');
      await tap(tester, 'Confirm these coordinates');
      expect(
        find.text('Enter a finite, valid latitude and longitude pair.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, '14.62');
      await tap(tester, 'Confirm these coordinates');
      await tester.pumpAndSettle();
      expect(result!.latitude, 14.62);
    },
  );

  for (final failure in ['library', 'renderer', 'deadline']) {
    testWidgets(
      '$failure failure exposes safe fallback and ignores obsolete readiness',
      (tester) async {
        renderer.prepareFails = failure == 'library';
        await open(tester, initial: saved);
        final ready = renderer.ready;
        if (failure == 'renderer') renderer.error!();
        if (failure == 'deadline') {
          await tester.pump(const Duration(seconds: 16));
        }
        await tester.pump();
        expect(find.text('Retry map'), findsOneWidget);
        ready?.call();
        await tester.pump();
        expect(find.text('Retry map'), findsOneWidget);
        expect(renderer.disposed, isTrue);
        await tap(tester, 'Confirm these coordinates');
        await tester.pumpAndSettle();
        expect(result!.longitude, 121);
      },
    );
  }

  for (final loss in ['logout', 'consent']) {
    testWidgets(
      '$loss clears the map and rejects delayed callback coordinates',
      (tester) async {
        await open(tester, initial: saved);
        final ready = renderer.ready!, select = renderer.select!;
        if (loss == 'logout') {
          await session.signOut();
        } else {
          session.verifiedLease!.onFailure(
            const ApiFailure(
              FailureKind.http,
              status: 403,
              code: 'POLICY_CONSENT_REQUIRED',
            ),
          );
        }
        await tester.pump();
        ready();
        select(adjusted);
        await tester.pump();
        expect(renderer.disposed, isTrue);
        expect(find.text('Synthetic map'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          isEmpty,
        );
        await tap(tester, 'Cancel pin');
        await tester.pumpAndSettle();
        expect(result, isNull);
      },
    );
  }

  testWidgets(
    'closing or signing out during lookup cannot restore candidates',
    (tester) async {
      maps.lookup = Completer<List<GeoCandidate>>();
      await open(tester);
      await tap(tester, 'Find this address on the map');
      await session.signOut();
      maps.lookup!.complete([saved]);
      await tester.pumpAndSettle();
      expect(find.text('Saved pin'), findsNothing);
      expect(maps.tiles, 0);
    },
  );

  testWidgets('account switching cannot reuse the previous address dialog', (
    tester,
  ) async {
    await open(tester, initial: saved);
    final select = renderer.select!;
    await session.signOut();
    (dependencies.auth as FakeAuth).identity = CustomerIdentity.parse(
      identityJson(id: otherId),
    );
    await session.signIn('synthetic@example.invalid', 'Synthetic123');
    expect(session.customer!.id, otherId);
    await tester.pump();
    select(adjusted);
    await tap(tester, 'Find this address on the map');
    expect(maps.geocodes, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await tap(tester, 'Confirm these coordinates');
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('malformed raster image exposes fallback before SDK creation', (
    tester,
  ) async {
    maps.malformedTile = true;
    await open(tester, initial: saved);
    expect(find.text('Retry map'), findsOneWidget);
    expect(renderer.prepares, 0);
    expect(renderer.disposed, isTrue);
    await tap(tester, 'Confirm these coordinates');
    await tester.pumpAndSettle();
    expect(result!.longitude, saved.longitude);
  });

  testWidgets('disabled map configuration never constructs a renderer', (
    tester,
  ) async {
    dependencies = AppDependencies(
      config: mapConfig(enabled: false),
      auth: dependencies.auth,
      policies: dependencies.policies,
      session: session,
      launcher: dependencies.launcher,
      mapLocations: maps,
    );
    await open(tester, initial: saved);
    await tap(tester, 'Find this address on the map');
    expect(maps.geocodes, 0);
    expect(maps.tiles, 0);
    expect(renderer.prepares, 0);
    await tap(tester, 'Cancel pin');
    await tester.pumpAndSettle();
  });

  testWidgets(
    'narrow doubled text and landscape retain reachable map and coordinate actions',
    (tester) async {
      await open(tester, initial: saved, size: const Size(320, 480), scale: 2);
      renderer.ready!();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tap(tester, '© OpenMapTiles');
      await tester.ensureVisible(find.byType(TextField).last);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      expect(maps.tiles, 1);
      await tap(tester, 'Cancel pin');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
