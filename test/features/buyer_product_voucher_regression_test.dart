import 'dart:async';
import 'dart:convert';

import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/router.dart';
import 'package:aisley_mobile_buyer/app/router_guard.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/catalog_models.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/catalog_image.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/home_shopping_shortcuts.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/product_card_information.dart';
import 'package:aisley_mobile_buyer/features/vouchers/data/voucher_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';
import '../support/image_samples.dart';
import '../support/voucher_fixtures.dart';

void main() {
  late CommerceHarness h;
  late AppDependencies d;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
    final base = h.dependencies();
    d = AppDependencies(
      config: base.config,
      auth: h.auth,
      policies: h.policies,
      session: h.session,
      launcher: base.launcher,
      client: h.api,
      commerce: h.commerce,
      discovery: base.discovery,
      addresses: base.addresses,
      vouchers: VoucherRepository(h.api),
    );
    addTearDown(base.savedStatus!.dispose);
  });
  tearDown(() {
    d.voucherCollection!.dispose();
    d.vouchers!.dispose();
    d.discovery!.dispose();
    h.dispose();
  });

  testWidgets('discounted cards retain struck-through amount without Was', (
    tester,
  ) async {
    final home = fixture('customer-homepage', 'op-047');
    final row = Map<String, dynamic>.from(
      (home['topProducts'] as List).first as Map,
    );
    row['price'] = 229;
    row['originalPrice'] = 299;
    row['minPrice'] = null;
    row['maxPrice'] = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        home: Scaffold(
          body: ProductCardInformation(product: ProductCard.parse(row)),
        ),
      ),
    );
    expect(find.text('₱229.00'), findsOneWidget);
    expect(find.text('₱299.00'), findsOneWidget);
    expect(find.textContaining('Was'), findsNothing);
    expect(
      tester.widget<Text>(find.text('₱299.00')).style!.decoration,
      TextDecoration.lineThrough,
    );
    row['originalPrice'] = 229;
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        home: Scaffold(
          body: ProductCardInformation(product: ProductCard.parse(row)),
        ),
      ),
    );
    expect(find.text('₱229.00'), findsOneWidget);
    expect(find.text('₱299.00'), findsNothing);
  });

  testWidgets('Home Vouchers and Recent shortcuts retain their destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(body: HomeShoppingShortcuts(dependencies: d)),
        ),
        GoRoute(
          path: '/vouchers',
          builder: (_, _) => const Scaffold(body: Text('Opened vouchers')),
        ),
        GoRoute(
          path: '/account/recently-viewed',
          builder: (_, _) =>
              const Scaffold(body: Text('Opened recent history')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: buyerTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
    await tester.tap(find.text('Vouchers'));
    await tester.pumpAndSettle();
    expect(find.text('Opened vouchers'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    expect(find.text('Opened recent history'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('catalog image fills its bounded card area without credentials', (
    tester,
  ) async {
    const path = '/api/v1/product-media/$otherId';
    h.reply = (_) => ResponseBody.fromBytes(
      base64Decode(buyerImageSamples.first['bytes']!),
      200,
      headers: {
        Headers.contentTypeHeader: ['image/jpeg'],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: CatalogImage(
                url: path,
                discovery: d.discovery!,
                label: 'Product photo',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(180, 180));
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    final request = h.adapter.requests.singleWhere((r) => r.uri.path == path);
    expect(
      request.headers.keys.map((key) => key.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changed product image cannot retain obsolete decoded pixels', (
    tester,
  ) async {
    final delayed = Completer<ResponseBody>();
    const firstPath = '/api/v1/product-media/$customerId';
    const nextPath = '/api/v1/product-media/$otherId';
    h.reply = (r) => r.uri.path == firstPath
        ? delayed.future
        : ResponseBody.fromBytes(
            base64Decode(buyerImageSamples.first['bytes']!),
            200,
            headers: {
              Headers.contentTypeHeader: ['image/jpeg'],
            },
          );
    Widget app(String? path) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: CatalogImage(
            key: const ValueKey('image'),
            url: path,
            discovery: d.discovery!,
            width: 180,
            height: 180,
            label: 'Product photo',
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(firstPath));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(app(nextPath));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    final currentImage = tester.widget<Image>(find.byType(Image)).image;
    delayed.complete(ResponseBody.fromBytes([1, 2, 3], 200));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, currentImage);
    await tester.pumpWidget(app(null));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Shop loads vouchers only after dedicated page entry and preserves Back',
    (tester) async {
      h.reply = (r) {
        if (r.uri.path.endsWith('/voucher-statuses')) {
          return jsonReply({
            'items': [voucherJson()],
          });
        }
        if (r.uri.path.endsWith('/sample-shop/vouchers')) {
          return jsonReply(voucherPage([voucherJson(private: false)]));
        }
        if (r.uri.path.endsWith('/sample-shop/products')) {
          return jsonReply(fixture('browse-shop', 'op-022'));
        }
        if (r.uri.path.endsWith('/sample-shop')) {
          return jsonReply(fixture('browse-shop', 'op-023'));
        }
        return h.defaultReply(r);
      };
      final router = buyerRouter(d);
      addTearDown(router.dispose);
      router.go('/shops/sample-shop?q=mug');
      await tester.pumpWidget(
        MaterialApp.router(theme: buyerTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(
        h.adapter.requests.where(
          (r) =>
              r.uri.path.endsWith('/vouchers') ||
              r.uri.path.endsWith('/voucher-statuses'),
        ),
        isEmpty,
      );
      expect(find.text('Collect voucher'), findsNothing);
      final entry = find.text('View Shop vouchers');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/shops/sample-shop/vouchers',
      );
      expect(
        h.adapter.requests.where(
          (r) => r.uri.path.endsWith('/sample-shop/vouchers'),
        ),
        hasLength(1),
      );
      expect(find.text('Collect voucher'), findsOneWidget);
      expect(h.adapter.requests.where((r) => r.method == 'POST'), isEmpty);
      router.pop();
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/shops/sample-shop?q=mug',
      );
      expect(find.text('Collect voucher'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Shop vouchers are a resumable read destination with no automatic claim',
    () {
      expect(
        safeReturn('/shops/sample-shop/vouchers'),
        '/shops/sample-shop/vouchers',
      );
      expect(safeReturn('/shops/sample-shop/vouchers?claim=true'), '/');
      expect(
        safeReturn('https://foreign.invalid/shops/sample-shop/vouchers'),
        '/',
      );
    },
  );
}
