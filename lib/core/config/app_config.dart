import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig({
    required String apiBaseUrl,
    required String storefrontOrigin,
    this.allowLocalHttp = false,
    this.mapsRequested = false,
    this.geoapifyPublicApiKey = '',
  }) : apiBase = _normalizeApiBase(apiBaseUrl),
       storefront = Uri.parse(storefrontOrigin) {
    if (!_validOrigin(apiBase) ||
        apiBase.path != '/api/v1' ||
        !_validOrigin(storefront) ||
        (storefront.path.isNotEmpty && storefront.path != '/')) {
      throw const FormatException(
        'Provide trusted API and storefront origins.',
      );
    }
  }

  static Uri _normalizeApiBase(String value) {
    final uri = Uri.parse(value);
    if (uri.path.isEmpty || uri.path == '/' || uri.path == '/api/v1/') {
      return uri.replace(path: '/api/v1');
    }
    return uri;
  }

  factory AppConfig.environment() {
    final emulator = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return AppConfig(
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL').isEmpty
          ? (kDebugMode
                ? 'http://${emulator ? '10.0.2.2' : 'localhost'}:8000/api/v1'
                : '')
          : const String.fromEnvironment('API_BASE_URL'),
      storefrontOrigin:
          const String.fromEnvironment('STOREFRONT_ORIGIN').isEmpty
          ? (kDebugMode
                ? 'http://${emulator ? '10.0.2.2' : 'localhost'}:3000'
                : '')
          : const String.fromEnvironment('STOREFRONT_ORIGIN'),
      allowLocalHttp: kDebugMode,
      mapsRequested: const bool.fromEnvironment('MAPS_ENABLED'),
      geoapifyPublicApiKey: const String.fromEnvironment(
        'GEOAPIFY_PUBLIC_API_KEY',
      ),
    );
  }

  final Uri apiBase;
  final Uri storefront;
  final bool allowLocalHttp;
  final bool mapsRequested;
  final String geoapifyPublicApiKey;

  bool get mapsEnabled =>
      mapsRequested && geoapifyPublicApiKey.trim().isNotEmpty;

  bool _validOrigin(Uri uri) =>
      uri.hasAuthority &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      (uri.scheme == 'https' ||
          (allowLocalHttp &&
              uri.scheme == 'http' &&
              const ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)));

  bool trustsApi(Uri uri) =>
      uri.hasAuthority &&
      uri.scheme == apiBase.scheme &&
      uri.origin == apiBase.origin &&
      uri.userInfo.isEmpty &&
      uri.path.startsWith('/api/v1/') &&
      !uri.hasFragment;

  Uri apiUri(String path) {
    final uri = apiBase.resolve(
      path.startsWith('/api/v1/') ? path : '/api/v1/$path',
    );
    if (!trustsApi(uri) || uri.hasQuery) {
      throw const FormatException('Unsupported API destination.');
    }
    return uri;
  }

  Uri? trustedLink(String value) {
    Uri uri;
    try {
      uri = storefront.resolve(value);
    } on FormatException {
      return null;
    }
    return uri.hasAuthority &&
            const ['http', 'https'].contains(uri.scheme) &&
            uri.origin == storefront.origin &&
            uri.userInfo.isEmpty &&
            (uri.scheme == 'https' || allowLocalHttp && uri.scheme == 'http')
        ? uri
        : null;
  }
}
