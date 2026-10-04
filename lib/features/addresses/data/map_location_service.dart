import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';

class GeoCandidate {
  const GeoCandidate({
    required this.label,
    required this.latitude,
    required this.longitude,
  });
  final String label;
  final double latitude, longitude;
}

class MapLocationService {
  MapLocationService(this.config, {Dio? client, LocationAccess? location})
    : _location = location ?? const ForegroundLocationAccess(),
      _client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              followRedirects: false,
              validateStatus: (_) => true,
              headers: const {'Accept': 'application/json'},
            ),
          ) {
    _client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      followRedirects: false,
      validateStatus: (_) => true,
      headers: const {'Accept': 'application/json'},
    );
  }
  final AppConfig config;
  final Dio _client;
  final LocationAccess _location;

  Future<List<GeoCandidate>> geocode(String confirmedAddress) async {
    if (!config.mapsEnabled) return const [];
    final response = await _client.get<dynamic>(
      'https://api.geoapify.com/v1/geocode/search',
      queryParameters: {
        'text': confirmedAddress,
        'filter': 'countrycode:ph',
        'format': 'json',
        'limit': 1,
        'apiKey': config.geoapifyPublicApiKey,
      },
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw const MapProviderFailure();
    }
    final providerRows = (response.data as Map)['results'];
    if (providerRows is! List) throw const MapProviderFailure();
    final candidates = <GeoCandidate>[];
    for (final item in providerRows) {
      if (item is! Map) continue;
      final longitude = _finiteNumber(item['lon']);
      final latitude = _finiteNumber(item['lat']);
      final countryCode = item['country_code'];
      final label = item['formatted'];
      if (latitude == null ||
          longitude == null ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180 ||
          countryCode is String && countryCode.toLowerCase() != 'ph') {
        continue;
      }
      candidates.add(
        GeoCandidate(
          label: label is String && label.isNotEmpty
              ? label
              : 'Suggested location in the Philippines',
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }
    return List.unmodifiable(candidates);
  }

  Future<GeoCandidate> currentLocation() async {
    if (!config.mapsEnabled) throw const MapProviderFailure();
    if (!await _location.serviceEnabled()) {
      throw const LocationChoiceFailure('Location services are turned off.');
    }
    var permission = await _location.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _location.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationChoiceFailure(
        'Location permission was denied. You can still enter the address manually.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationChoiceFailure(
        'Location permission is blocked. Change it in device settings or enter the address manually.',
      );
    }
    try {
      final position = await _location.position();
      return GeoCandidate(
        label: 'Current device location',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      throw const LocationChoiceFailure(
        'Current location is unavailable. You can still enter the address manually.',
      );
    }
  }

  static double? _finiteNumber(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) {
      final number = double.tryParse(value);
      if (number != null && number.isFinite) return number;
    }
    return null;
  }
}

abstract interface class LocationAccess {
  Future<bool> serviceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> position();
}

class ForegroundLocationAccess implements LocationAccess {
  const ForegroundLocationAccess();
  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Future<Position> position() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 10),
    ),
  );
}

class MapProviderFailure implements Exception {
  const MapProviderFailure();
  @override
  String toString() => 'Address lookup is unavailable.';
}

class LocationChoiceFailure implements Exception {
  const LocationChoiceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
