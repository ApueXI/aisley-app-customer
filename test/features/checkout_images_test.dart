import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/quote_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/batch_result_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/quote_review.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/product_item_row.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';
import '../support/image_samples.dart';

const imagePath = '/api/v1/product-media/$otherId';
ResponseBody imageReply() => ResponseBody.fromBytes(
  base64Decode(buyerImageSamples.first['bytes']!),
  200,
  headers: {
    Headers.contentTypeHeader: ['image/jpeg'],
  },
);

void main() {
  late CommerceHarness h;
  late AppDependencies dependencies;
  late Map<String, dynamic> quote, batch;
  late Map<String, dynamic> quoteItem, batchItem;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
    dependencies = h.dependencies();
    quote = h.quoteFor({
      'mode': 'buy_now',
      'address_id': customerId,
      'buy_now': {'product_id': customerId, 'variant_id': null, 'quantity': 1},
    });
    batch = fixture('checkout-order', 'op-030');
    quote['data']['groups'][0]['availableVouchers'] = [];
    quoteItem = quote['data']['groups'][0]['items'][0];
    batchItem = batch['data']['orders'][0]['items'][0];
    for (final item in [quoteItem, batchItem]) {
      item['productName'] = 'Reviewed Product';
      item['imageUrl'] = imagePath;
    }
    h.reply = (r) {
      if (r.uri.path == imagePath) return imageReply();
      if (r.uri.path.endsWith('/checkout/quote')) return jsonReply(quote);
      if (r.uri.path.endsWith('/checkout/place') ||
          r.uri.path.endsWith('/checkout/$customerId')) {
        return jsonReply(batch);
      }
      return h.defaultReply(r);
    };
  });
  tearDown(() => dependencies.dispose());

  Future<void> show(
    WidgetTester tester,
    bool result, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (!result) {
      h.commerce.checkout.begin(
        CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)),
      );
    }
    final router = GoRouter(
      initialLocation: result ? '/checkout/result/$customerId' : '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (_, _) => CheckoutScreen(dependencies: dependencies),
        ),
        GoRoute(
          path: '/checkout/result/:id',
          builder: (_, state) => BatchResultScreen(
            dependencies: dependencies,
            id: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/orders',
          builder: (_, _) => const Text('Orders opened'),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (_, _) => const Text('Order detail opened'),
        ),
      ],
    );
    addTearDown(router.dispose);
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
    if (!result) {
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review order'));
      await tester.tap(find.text('Review order'));
    }
    if (settle) {
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
    }
  }

  test(
    'quote image is an optional nullable string; wrong types fail decoding',
    () {
      for (final value in [imagePath, null, '']) {
        quoteItem['imageUrl'] = value;
        expect(QuoteItem.parse(quoteItem).imageUrl, value);
      }
      quoteItem.remove('imageUrl');
      expect(
        CheckoutQuote.parse(quote['data']).groups.first.items.first.imageUrl,
        isNull,
      );
      for (final value in [3, false, <String, dynamic>{}, <dynamic>[]]) {
        quoteItem['imageUrl'] = value;
        expect(() => QuoteItem.parse(quoteItem), throwsA(isA<ApiFailure>()));
      }
    },
  );

  void imageTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await body(tester);
      } finally {
        semantics.dispose();
        h.commerce.checkout.invalidateQuote();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  for (final result in [false, true]) {
    final screen = result ? 'Result' : 'Review';
    imageTest('$screen shows thumbnail without public media credentials', (
      tester,
    ) async {
      await show(tester, result);
      expect(find.byType(ProductItemRow), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(
        find.bySemanticsLabel('Product image: Reviewed Product'),
        findsOneWidget,
      );
      final request = h.adapter.requests.singleWhere(
        (r) => r.uri.path == imagePath,
      );
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(anyOf(contains('authorization'), contains('cookie'))),
      );
      expect(tester.takeException(), isNull);
    });

    for (final kind in [
      'missing',
      'null',
      'empty',
      'foreign',
      'unsafe',
      'unavailable',
      'corrupt',
    ]) {
      imageTest('$screen $kind image preserves facts and next action', (
        tester,
      ) async {
        final item = result ? batchItem : quoteItem;
        item['imageUrl'] = switch (kind) {
          'null' => null,
          'empty' => '',
          'foreign' =>
            'https://untrusted.example/api/v1/product-media/$otherId',
          'unsafe' => '/api/v1/customer/account/photo',
          _ => imagePath,
        };
        if (kind == 'missing') item.remove('imageUrl');
        final original = h.reply!;
        h.reply = (r) {
          if (r.uri.path == imagePath && kind == 'unavailable') {
            return jsonReply({}, status: 404);
          }
          if (r.uri.path == imagePath && kind == 'corrupt') {
            return ResponseBody.fromBytes([1, 2, 3], 200);
          }
          return original(r);
        };
        await show(tester, result);
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);
        expect(find.text('Reviewed Product × 1'), findsOneWidget);
        final next = find.text(result ? 'View Order' : 'Place COD order');
        await tester.ensureVisible(next);
        expect(
          tester
              .widget<ButtonStyleButton>(
                find.ancestor(
                  of: next,
                  matching: find.byType(result ? TextButton : FilledButton),
                ),
              )
              .onPressed,
          isNotNull,
        );
        if (['missing', 'null', 'empty', 'foreign', 'unsafe'].contains(kind)) {
          expect(
            h.adapter.requests.where(
              (r) =>
                  r.uri.path.contains('product-media') ||
                  r.uri.path.contains('account/photo'),
            ),
            isEmpty,
          );
        }
        expect(
          h.adapter.requests.every((r) => r.uri.host == 'localhost'),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final size in [
      const Size(320, 720),
      const Size(390, 844),
      const Size(600, 844),
      const Size(800, 844),
      const Size(1024, 900),
      const Size(1440, 900),
      const Size(640, 320),
    ]) {
      imageTest('$screen wraps long names with doubled text at $size', (
        tester,
      ) async {
        (result ? batchItem : quoteItem)['productName'] = List.filled(
          5,
          'Long reviewed Product name',
        ).join(' ');
        await show(tester, result, size: size, scale: 2);
        expect(find.byType(ProductItemRow), findsOneWidget);
        expect(tester.getSize(find.byType(Image)), const Size(64, 64));
        final next = find.text(result ? 'View Order' : 'Place COD order');
        await tester.ensureVisible(next);
        expect(tester.takeException(), isNull);
      });
    }

    imageTest('$screen loading media never blocks its next action', (
      tester,
    ) async {
      final delayed = Completer<ResponseBody>();
      final original = h.reply!;
      h.reply = (r) => r.uri.path == imagePath ? delayed.future : original(r);
      await show(tester, result, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final next = find.text(result ? 'View Order' : 'Place COD order');
      await tester.ensureVisible(next);
      await tester.tap(next);
      // Do not wait for the indefinitely animated media indicator.
      await tester.pump();
      if (result) {
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Order detail opened'), findsOneWidget);
      } else {
        expect(find.text('Place COD order?'), findsOneWidget);
        expect(
          h.adapter.requests.where((r) => r.uri.path.endsWith('/place')),
          isEmpty,
        );
      }
      delayed.complete(imageReply());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final loss in ['logout', 'consent', 'navigation']) {
      imageTest('$screen late image after $loss cannot restore checkout', (
        tester,
      ) async {
        final delayed = Completer<ResponseBody>();
        final original = h.reply!;
        h.reply = (r) => r.uri.path == imagePath ? delayed.future : original(r);
        await show(tester, result, settle: false);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        if (loss == 'logout') {
          await h.session.signOut();
        } else if (loss == 'consent') {
          h.policies.consent = ConsentStatus.parse(consentJson(required: true));
          await h.session.refreshConsent();
        } else {
          await tester.pumpWidget(const MaterialApp(home: Text('Other route')));
        }
        await tester.pump();
        delayed.complete(imageReply());
        await tester.pumpAndSettle();
        expect(find.byType(ProductItemRow), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  imageTest(
    'review and result use matching thumbnails without changing placement',
    (tester) async {
      await show(tester, false);
      await tester.ensureVisible(find.text('Place COD order'));
      await tester.tap(find.text('Place COD order'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Place order'));
      await tester.pumpAndSettle();
      expect(find.byType(BatchResultScreen), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final placement = h.adapter.requests.singleWhere(
        (r) => r.uri.path.endsWith('/place'),
      );
      expect((placement.data as Map).keys, isNot(contains('imageUrl')));
      expect(
        placement.headers.keys.map((k) => k.toLowerCase()),
        contains('idempotency-key'),
      );
      expect(
        h.adapter.requests.where((r) => r.uri.path == imagePath),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  imageTest('multiple Shop groups and result items keep their own thumbnails', (
    tester,
  ) async {
    final extraGroup = clone(quote['data']['groups'][0]);
    extraGroup['shop']['id'] = otherId;
    extraGroup['items'][0]['imageUrl'] = null;
    quote['data']['groups'].add(extraGroup);
    quote['data']['summary']['orderCount'] = 2;
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuoteReview(
              quote: CheckoutQuote.parse(quote['data']),
              controller: h.commerce.checkout,
              discovery: dependencies.discovery!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProductItemRow), findsNWidgets(2));
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    final extraOrder = clone(batch['data']['orders'][0]);
    extraOrder['id'] = otherId;
    extraOrder['shop']['id'] = otherId;
    extraOrder['items'][0]['imageUrl'] = null;
    batch['data']['orders'].add(extraOrder);
    await show(tester, true);
    expect(find.byType(ProductItemRow), findsNWidgets(2));
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
