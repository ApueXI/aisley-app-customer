import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'env_asset.dart';

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

  static Future<AppConfig> load({AssetBundle? bundle}) async =>
      AppConfig.environment(await loadEnvAsset(bundle ?? rootBundle));

  factory AppConfig.environment(
    Map<String, String> environment, {
    bool allowLocalHttp = kDebugMode,
    bool releaseMode = kReleaseMode,
  }) {
    final nativeAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final useDeployedApi = releaseMode && nativeAndroid;
    final localHttpAllowed = allowLocalHttp && !releaseMode;
    final apiBaseUrl =
        environment[useDeployedApi ? 'DEPLOYED_API_URL' : 'API_BASE_URL']
            ?.trim() ??
        '';
    final storefrontOrigin = environment['STOREFRONT_ORIGIN']?.trim() ?? '';
    return AppConfig(
      apiBaseUrl: apiBaseUrl.isEmpty
          ? (localHttpAllowed
                ? 'http://${nativeAndroid ? '10.0.2.2' : 'localhost'}:8000/api/v1'
                : '')
          : apiBaseUrl,
      storefrontOrigin: storefrontOrigin.isEmpty
          ? (localHttpAllowed
                ? 'http://${nativeAndroid ? '10.0.2.2' : 'localhost'}:3000'
                : '')
          : storefrontOrigin,
      allowLocalHttp: localHttpAllowed,
      mapsRequested:
          environment['MAPS_ENABLED']?.trim().toLowerCase() == 'true',
      geoapifyPublicApiKey: environment['GEOAPIFY_API_KEY']?.trim() ?? '',
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
