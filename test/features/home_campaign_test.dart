import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/home_models.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/home_campaign_banner.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/home_screen.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

Map<String, dynamic> campaignJson({
  String? title,
  String? altText,
  String? destinationUrl,
  bool image = true,
}) => {
  'id': 'default-primary',
  'title': title,
  'description': null,
  'slot': 'primary',
  'position': 0,
  'imageDesktopUrl': image
      ? '/api/v1/homepage-advertisement-images/default-primary/desktop'
      : null,
  'imageMobileUrl': null,
  'altText': altText,
  'destinationUrl': destinationUrl,
  'isActive': true,
};

class RecordingLauncher extends TrustedLauncher {
  RecordingLauncher() : super(testConfig);
  final opened = <String>[];

  @override
  Future<bool> open(String value) async {
    opened.add(value);
    return true;
  }
}

void main() {
  test('image-only campaigns parse in advertisement and legacy groups', () {
    final body = fixture('customer-homepage', 'op-047');
    body['advertisementLayer'] = {
      'layout': 'primary',
      'rotationIntervalSeconds': 6,
      'primary': [campaignJson()],
      'secondaryTop': campaignJson(),
      'secondaryBottom': null,
    };
    body['campaigns'] = {
      'hero': [campaignJson()],
      'side': [campaignJson()],
    };
    final home = BuyerHome.parse(body);

    for (final campaign in [
      ...home.advertisementLayer!.primary,
      home.advertisementLayer!.secondaryTop!,
      ...home.campaigns.hero,
      ...home.campaigns.side,
    ]) {
      expect(campaign.id, 'default-primary');
      expect(campaign.title, isNull);
      expect(campaign.altText, isNull);
      expect(campaign.destinationUrl, isNull);
    }
    expect(home.recommendations.items, isNotEmpty);
  });

  test('nullable campaign fields remain required and reject wrong types', () {
    for (final key in ['title', 'altText', 'destinationUrl']) {
      expect(
        () => HomeCampaign.parse(campaignJson()..remove(key)),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () => HomeCampaign.parse(campaignJson()..[key] = 42),
        throwsA(isA<ApiFailure>()),
      );
    }
  });

  test('text and link metadata is retained when supplied', () {
    final campaign = HomeCampaign.parse(
      campaignJson(
        title: 'Seasonal offers',
        altText: 'Seasonal artwork',
        destinationUrl: '/offers',
      ),
    );
    expect(campaign.title, 'Seasonal offers');
    expect(campaign.altText, 'Seasonal artwork');
    expect(campaign.destinationUrl, '/offers');
  });

  group('Home promotion rendering', () {
    late SessionController session;
    late ApiClient api;
    late AppDependencies dependencies;
    late Map<String, dynamic> body;
    late RecordingLauncher launcher;

    setUp(() async {
      final auth = FakeAuth(), policies = FakePolicies();
      session = SessionController(
        auth,
        policies,
        MemoryTokenStore()..token = 'synthetic-token',
      );
      await session.bootstrap();
      body = fixture('customer-homepage', 'op-047');
      final adapter = FakeAdapter(
        (request) => request.uri.path.endsWith('/home')
            ? jsonReply(body)
            : jsonReply({}, status: 404),
      );
      api = ApiClient(
        testConfig,
        publicClient: Dio()..httpClientAdapter = adapter,
        privateClient: Dio()..httpClientAdapter = adapter,
      );
      launcher = RecordingLauncher();
      dependencies = AppDependencies(
        config: testConfig,
        auth: auth,
        policies: policies,
        session: session,
        launcher: launcher,
        discovery: DiscoveryRepository(api: api, session: session),
        recentlyViewed: RecentlyViewedRepository(api),
      );
    });
    tearDown(() {
      dependencies.discovery!.dispose();
      session.dispose();
      api.close();
    });

    void setCampaigns(List<Map<String, dynamic>> campaigns) {
      body['advertisementLayer'] = {
        'layout': 'primary',
        'rotationIntervalSeconds': 6,
        'primary': campaigns,
        'secondaryTop': null,
        'secondaryBottom': null,
      };
    }

    Future<void> show(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: Scaffold(body: HomeScreen(dependencies: dependencies)),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final width in [320.0, 1440.0]) {
      testWidgets('image-only promotion keeps Home readable at $width pixels', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        setCampaigns([campaignJson()]);
        await show(tester);

        expect(find.text('Home content is unavailable.'), findsNothing);
        expect(find.text('Popular right now'), findsOneWidget);
        final banner = find.byType(HomeCampaignBanner);
        expect(banner, findsOneWidget);
        final link = tester.widget<InkWell>(
          find.descendant(of: banner, matching: find.byType(InkWell)),
        );
        expect(link.onTap, isNull);
        expect(
          find.descendant(
            of: banner,
            matching: find.bySemanticsLabel('Promotion'),
          ),
          findsOneWidget,
        );
        await tester.tap(banner);
        expect(launcher.opened, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      });
    }

    testWidgets('linked title preserves the deliberate storefront action', (
      tester,
    ) async {
      setCampaigns([
        campaignJson(
          title: 'Seasonal offers',
          altText: 'Seasonal artwork',
          destinationUrl: '/offers',
        ),
      ]);
      await show(tester);
      await tester.tap(find.text('Seasonal offers'));
      await tester.pumpAndSettle();
      expect(launcher.opened, ['/offers']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'empty promotions are skipped before the next visible campaign',
      (tester) async {
        setCampaigns([
          campaignJson(image: false),
          campaignJson(title: 'Visible promotion', image: false),
        ]);
        await show(tester);
        expect(find.byType(HomeCampaignBanner), findsOneWidget);
        expect(find.text('Visible promotion'), findsOneWidget);
        expect(find.text('Home content is unavailable.'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
