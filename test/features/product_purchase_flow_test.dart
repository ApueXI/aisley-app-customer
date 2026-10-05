import 'dart:async';

import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/product_detail_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/product_purchase_flow.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/search_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';

const _variantId = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> _variantProduct() {
  final product =
      fixture('view-product', 'op-024')['data'] as Map<String, dynamic>;
  product['availability'] = {
    'inStock': true,
    'stockQuantity': null,
    'requiresVariantSelection': true,
  };
  product['optionGroups'] = [
    {
      'id': otherId,
      'name': 'Color',
      'position': 1,
      'values': [
        {
          'id': customerId,
          'value': 'Blue',
          'position': 1,
          'swatch': {'color': null, 'imageUrl': null},
        },
      ],
    },
  ];
  product['variants'] = [
    {
      'id': _variantId,
      'sku': null,
      'optionValueIds': [customerId],
      'price': 123,
      'originalPrice': null,
      'discountPercent': null,
      'stockQuantity': 2,
      'inStock': true,
      'primaryMediaId': null,
    },
  ];
  return product;
}

Map<String, dynamic> _simpleProduct({int stock = 5}) {
  final product =
      fixture('view-product', 'op-024')['data'] as Map<String, dynamic>;
  product['availability']['stockQuantity'] = stock;
  return product;
}

void main() {
  late CommerceHarness harness;
  late AppDependencies dependencies;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    harness = CommerceHarness();
    await harness.initialize();
    dependencies = harness.dependencies();
  });

  tearDown(() => dependencies.dispose());

  Future<void> showFlow(
    WidgetTester tester, {
    required Map<String, dynamic> product,
    bool doubleTap = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness.reply = (request) {
      if (request.uri.path == '/api/v1/products/$customerId') {
        return jsonReply({'data': product});
      }
      return harness.defaultReply(request);
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () {
                  unawaited(
                    beginProductPurchase(
                      context: context,
                      dependencies: dependencies,
                      productId: customerId,
                      action: ProductPurchaseAction.addToCart,
                    ),
                  );
                  if (doubleTap) {
                    unawaited(
                      beginProductPurchase(
                        context: context,
                        dependencies: dependencies,
                        productId: customerId,
                        action: ProductPurchaseAction.addToCart,
                      ),
                    );
                  }
                },
                child: const Text('Add from listing'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void serveProduct(Map<String, dynamic> product) {
    harness.reply = (request) {
      if (request.uri.path == '/api/v1/products/$customerId') {
        return jsonReply({'data': product});
      }
      return harness.defaultReply(request);
    };
  }

  testWidgets('variant purchase cancellation makes no Cart write', (
    tester,
  ) async {
    await showFlow(tester, product: _variantProduct());
    await tester.tap(find.text('Add from listing'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Product options'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      harness.adapter.requests.where(
        (request) =>
            request.method == 'POST' &&
            request.uri.path == '/api/v1/customer/cart/items',
      ),
      isEmpty,
    );
  });

  testWidgets('detail purchase keeps its chosen quantity after a fresh read', (
    tester,
  ) async {
    serveProduct(_simpleProduct());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        home: ProductDetailScreen(
          dependencies: dependencies,
          productId: customerId,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();

    final writes = harness.adapter.requests.where(
      (request) =>
          request.method == 'POST' &&
          request.uri.path == '/api/v1/customer/cart/items',
    );
    expect(writes, hasLength(1));
    expect(writes.single.data, {
      'product_id': customerId,
      'variant_id': null,
      'quantity': 2,
    });
  });

  testWidgets('simple listing purchase adds one unit with a null variant', (
    tester,
  ) async {
    final product = _simpleProduct();
    harness.reply = (request) {
      if (request.uri.path.endsWith('/customer/products/search')) {
        return jsonReply(fixture('search', 'op-019'));
      }
      if (request.uri.path == '/api/v1/products/$customerId') {
        return jsonReply({'data': product});
      }
      return harness.defaultReply(request);
    };
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        home: SearchScreen(
          dependencies: dependencies,
          mode: SearchMode.products,
          query: 'synthetic',
          page: 1,
          validRoute: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final addButton = find.text('Add to Cart');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    final writes = harness.adapter.requests.where(
      (request) =>
          request.method == 'POST' &&
          request.uri.path == '/api/v1/customer/cart/items',
    );
    expect(writes, hasLength(1));
    expect(writes.single.data, {
      'product_id': customerId,
      'variant_id': null,
      'quantity': 1,
    });
  });

  testWidgets('variant picker validates stock and deduplicates listing taps', (
    tester,
  ) async {
    await showFlow(tester, product: _variantProduct(), doubleTap: true);
    await tester.tap(find.text('Add from listing'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Product options'), findsOneWidget);
    expect(
      harness.adapter.requests.where(
        (request) => request.uri.path == '/api/v1/products/$customerId',
      ),
      hasLength(1),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();

    final writes = harness.adapter.requests.where(
      (request) =>
          request.method == 'POST' &&
          request.uri.path == '/api/v1/customer/cart/items',
    );
    expect(writes, hasLength(1));
    expect(writes.single.data, {
      'product_id': customerId,
      'variant_id': _variantId,
      'quantity': 2,
    });
  });
}
