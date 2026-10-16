import 'dart:convert';

import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads public settings from the .env asset before use', () async {
    final bundle = _EnvBundle('''
MAPS_ENABLED=true
GEOAPIFY_API_KEY=synthetic-public-key
API_BASE_URL=https://api.example.invalid/
DEPLOYED_API_URL=https://deployed.example.invalid/
STOREFRONT_ORIGIN=https://shop.example.invalid
''');
    final config = await AppConfig.load(bundle: bundle);

    expect(bundle.loadedKey, '.env');
    expect(config.apiBase.toString(), 'https://api.example.invalid/api/v1');
    expect(config.storefront.origin, 'https://shop.example.invalid');
    expect(config.mapsEnabled, isTrue);
    expect(config.geoapifyPublicApiKey, 'synthetic-public-key');
    expect(
      config.trustedLink('/reset-password')?.origin,
      'https://shop.example.invalid',
    );
    expect(
      config.trustedLink('https://foreign.invalid/reset-password'),
      isNull,
    );
    expect(
      config.trustsApi(Uri.parse('https://foreign.invalid/api/v1/customer/me')),
      isFalse,
    );
  });

  test(
    'supports CRLF, comments, whitespace, quotes and equals in values',
    () async {
      final config = await AppConfig.load(
        bundle: _EnvBundle(
          '# Public configuration\r\n'
          '\r\n'
          '  export API_BASE_URL = "https://api.example.invalid/api/v1/" # API\r\n'
          "STOREFRONT_ORIGIN = 'https://shop.example.invalid'\r\n"
          'MAPS_ENABLED = TRUE # optional maps\r\n'
          'GEOAPIFY_API_KEY = "synthetic=public#key" # map key\r\n',
        ),
      );

      expect(config.apiBase.path, '/api/v1');
      expect(config.mapsEnabled, isTrue);
      expect(config.geoapifyPublicApiKey, 'synthetic=public#key');
    },
  );

  test('blank web or desktop settings retain local debug defaults', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final config = await AppConfig.load(
      bundle: _EnvBundle('''
MAPS_ENABLED= # disabled
GEOAPIFY_API_KEY=
API_BASE_URL=
STOREFRONT_ORIGIN=
'''),
    );

    expect(config.apiBase.origin, 'http://localhost:8000');
    expect(config.storefront.origin, 'http://localhost:3000');
    expect(config.mapsEnabled, isFalse);
  });

  test('Android uses emulator debug defaults only on native', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final config = AppConfig.environment({});

    expect(
      config.apiBase.origin,
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000',
    );
    expect(
      config.storefront.origin,
      kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000',
    );
  });

  group('API selection by build mode', () {
    const environment = {
      'API_BASE_URL': 'http://localhost:8000/api/v1',
      'DEPLOYED_API_URL': 'https://deployed.example.invalid/api/v1',
      'STOREFRONT_ORIGIN': 'https://shop.example.invalid',
    };

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('debug Android and local web use API_BASE_URL', () {
      final config = AppConfig.environment(environment, releaseMode: false);

      expect(config.apiBase.toString(), environment['API_BASE_URL']);
      expect(config.allowLocalHttp, isTrue);
    });

    test('deployed URL does not replace blank or missing debug defaults', () {
      for (final local in [null, '', '   ']) {
        final values = {...environment}..remove('API_BASE_URL');
        if (local != null) values['API_BASE_URL'] = local;
        final config = AppConfig.environment(values);

        expect(
          config.apiBase.origin,
          kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000',
        );
      }
    });

    test(
      'release Android selects deployed URL; release web keeps API base',
      () {
        final config = AppConfig.environment({
          ...environment,
          'API_BASE_URL': 'https://web.example.invalid/api/v1',
        }, releaseMode: true);

        expect(
          config.apiBase.origin,
          kIsWeb
              ? 'https://web.example.invalid'
              : 'https://deployed.example.invalid',
        );
        expect(config.storefront.origin, environment['STOREFRONT_ORIGIN']);
        expect(config.allowLocalHttp, isFalse);
      },
    );

    test('native release ignores local URL and normalizes deployed URL', () {
      for (final deployed in [
        '  https://deployed.example.invalid  ',
        'https://deployed.example.invalid/',
        'https://deployed.example.invalid/api/v1',
        'https://deployed.example.invalid/api/v1/',
      ]) {
        final config = AppConfig.environment({
          ...environment,
          'API_BASE_URL': 'invalid local setting',
          'DEPLOYED_API_URL': deployed,
        }, releaseMode: true);

        expect(config.apiBase.toString(), environment['DEPLOYED_API_URL']);
        expect(
          config.apiUri('customer/auth/me').toString(),
          'https://deployed.example.invalid/api/v1/customer/auth/me',
        );
        expect(
          config.trustsApi(
            Uri.parse('http://localhost:8000/api/v1/customer/me'),
          ),
          isFalse,
        );
        expect(
          config.trustsApi(
            Uri.parse('https://foreign.invalid/api/v1/customer/me'),
          ),
          isFalse,
        );
      }
    }, skip: kIsWeb);

    test('native release rejects missing or invalid deployed URL', () {
      for (final deployed in [
        null,
        '',
        '   ',
        '/api/v1',
        'http://localhost:8000/api/v1',
        'http://10.0.2.2:8000/api/v1',
        'http://deployed.example.invalid',
        'https://user:password@deployed.example.invalid',
        'https://deployed.example.invalid/api/v2',
        'https://deployed.example.invalid?query=value',
        'https://deployed.example.invalid/#fragment',
      ]) {
        final values = {
          ...environment,
          'API_BASE_URL': 'https://local.example.invalid/api/v1',
        };
        if (deployed == null) {
          values.remove('DEPLOYED_API_URL');
        } else {
          values['DEPLOYED_API_URL'] = deployed;
        }

        expect(
          () => AppConfig.environment(values, releaseMode: true),
          throwsFormatException,
        );
      }
    }, skip: kIsWeb);

    test('release still requires an explicit HTTPS storefront', () {
      for (final storefront in ['', 'http://localhost:3000']) {
        expect(
          () => AppConfig.environment({
            ...environment,
            'API_BASE_URL': 'https://web.example.invalid',
            'STOREFRONT_ORIGIN': storefront,
          }, releaseMode: true),
          throwsFormatException,
        );
      }
    });

    test('profile Android keeps API_BASE_URL with HTTPS validation', () {
      final config = AppConfig.environment(
        {...environment, 'API_BASE_URL': 'https://profile.example.invalid'},
        releaseMode: false,
        allowLocalHttp: false,
      );

      expect(config.apiBase.origin, 'https://profile.example.invalid');
      expect(config.allowLocalHttp, isFalse);
    });

    test('release desktop keeps API_BASE_URL', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final config = AppConfig.environment({
        ...environment,
        'API_BASE_URL': 'https://desktop.example.invalid',
      }, releaseMode: true);

      expect(config.apiBase.origin, 'https://desktop.example.invalid');
    });
  });

  test('maps require an explicit true flag and the new public-key name', () {
    for (final flag in ['', 'false', 'yes', '1']) {
      expect(
        AppConfig.environment({
          'MAPS_ENABLED': flag,
          'GEOAPIFY_API_KEY': 'synthetic-public-key',
        }).mapsEnabled,
        isFalse,
      );
    }
    for (final values in [
      {'MAPS_ENABLED': 'true'},
      {'MAPS_ENABLED': 'true', 'GEOAPIFY_API_KEY': '   '},
      {'MAPS_ENABLED': 'true', 'GEOAPIFY_PUBLIC_API_KEY': 'legacy-key'},
    ]) {
      expect(AppConfig.environment(values).mapsEnabled, isFalse);
    }
  });

  test('release configuration requires explicit HTTPS API and storefront', () {
    for (final values in [
      <String, String>{},
      {'API_BASE_URL': 'https://api.example.invalid'},
      {'STOREFRONT_ORIGIN': 'https://shop.example.invalid'},
      {
        'API_BASE_URL': 'http://localhost:8000',
        'STOREFRONT_ORIGIN': 'https://shop.example.invalid',
      },
      {
        'API_BASE_URL': 'https://api.example.invalid',
        'STOREFRONT_ORIGIN': 'http://localhost:3000',
      },
    ]) {
      expect(
        () => AppConfig.environment(values, allowLocalHttp: false),
        throwsFormatException,
      );
    }
    final config = AppConfig.environment({
      'API_BASE_URL': 'https://api.example.invalid',
      'STOREFRONT_ORIGIN': 'https://shop.example.invalid',
    }, allowLocalHttp: false);
    expect(config.apiBase.scheme, 'https');
    expect(config.allowLocalHttp, isFalse);
  });

  test('invalid origins in the asset keep the existing validation', () async {
    for (final url in [
      'http://foreign.invalid',
      'https://user:password@api.example.invalid',
      'https://api.example.invalid/api/v2',
      'https://api.example.invalid?query=value',
    ]) {
      await expectLater(
        AppConfig.load(
          bundle: _EnvBundle('''
API_BASE_URL=$url
STOREFRONT_ORIGIN=https://shop.example.invalid
'''),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'missing and malformed assets fail without including file contents',
    () async {
      final redactedFailure = throwsA(
        isA<FormatException>().having(
          (error) => error.toString(),
          'redacted message',
          isNot(contains('SYNTHETIC_PRIVATE_VALUE')),
        ),
      );
      await expectLater(
        AppConfig.load(bundle: _EnvBundle(null)),
        redactedFailure,
      );
      for (final source in [
        'SYNTHETIC_PRIVATE_VALUE',
        '=SYNTHETIC_PRIVATE_VALUE',
        'BAD KEY=SYNTHETIC_PRIVATE_VALUE',
        'GEOAPIFY_API_KEY="SYNTHETIC_PRIVATE_VALUE',
        'GEOAPIFY_API_KEY="SYNTHETIC_PRIVATE_VALUE" trailing',
      ]) {
        await expectLater(
          AppConfig.load(bundle: _EnvBundle(source)),
          redactedFailure,
        );
      }
    },
  );
}

class _EnvBundle extends CachingAssetBundle {
  _EnvBundle(this.source);

  final String? source;
  String? loadedKey;

  @override
  Future<ByteData> load(String key) async {
    loadedKey = key;
    final value = source;
    if (value == null) throw FlutterError('SYNTHETIC_PRIVATE_VALUE');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
