// Synthetic pin verification. No live API, GPS, provider key or token storage.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:dio/dio.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/core/security/token_store.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_repository.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_repository.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/map_location_service.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/address_map_adapter.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/map_pin_dialog.dart';

late SemanticsHandle semantics;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  final config = AppConfig(
    apiBaseUrl: 'https://api.example.invalid',
    storefrontOrigin: 'https://shop.example.invalid',
    mapsRequested: true,
    geoapifyPublicApiKey: 'synthetic-public-key',
  );
  final auth = _Auth(), policies = _Policies();
  final session = SessionController(auth, policies, _Token())
    ..phase = SessionPhase.active;
  final dependencies = AppDependencies(
    config: config,
    auth: auth,
    policies: policies,
    session: session,
    launcher: TrustedLauncher(config),
    mapLocations: _Maps(config),
  );
  runApp(
    MaterialApp(
      theme: buyerTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Synthetic address')),
          body: TextButton(
            child: const Text('Open pin'),
            onPressed: () async {
              final point = await showAddressPinDialog(
                context: context,
                dependencies: dependencies,
                addressText: 'Synthetic address',
                initial: _Maps.point,
                mapAdapterFactory: _Map.new,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      point == null ? 'Pin cancelled' : 'Pin confirmed',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    ),
  );
}

class _Maps extends MapLocationService {
  _Maps(super.config);
  static const point = GeoCandidate(
    label: 'Selected address',
    latitude: 14.6,
    longitude: 121,
  );
  @override
  Future<List<int>> pinTile(
    GeoCandidate point, {
    CancelToken? cancelToken,
  }) async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  @override
  Future<List<GeoCandidate>> geocode(String confirmedAddress) async => [point];
  @override
  Future<GeoCandidate> currentLocation() async => point;
}

class _Map extends MapLibreAddressMap {
  @override
  Widget build({
    required String style,
    required GeoCandidate initial,
    required VoidCallback onReady,
    required VoidCallback onError,
    required ValueChanged<GeoCandidate> onSelect,
  }) => super.build(
    style: '{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#e9e2e8"}}]}',
    initial: initial,
    onReady: onReady,
    onError: onError,
    onSelect: onSelect,
  );
}

class _Auth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Policies implements PolicyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Token implements TokenStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
