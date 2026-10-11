import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/batch_models.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_models.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/order_detail_screen.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/order_item_row.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/orders_screen.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';
import '../support/image_samples.dart';

import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

const imagePath = '/api/v1/product-media/$otherId';
final imageBytes = base64Decode(buyerImageSamples.first['bytes']!);
ResponseBody imageReply() => ResponseBody.fromBytes(
  imageBytes,
  200,
  headers: {
    Headers.contentTypeHeader: ['image/jpeg'],
  },
);

void main() {
  late CommerceHarness h;
  late AppDependencies dependencies;
  late Map<String, dynamic> summary;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
    dependencies = h.dependencies();
    summary = fixture('order-status', 'op-032');
    summary['data'][0]['itemPreview'] = {
      'productId': customerId,
      'productName': 'Purchased Product',
      'variantName': 'Color: Purple',
      'quantity': 1,
      'imageUrl': imagePath,
    };
    h.orderJson['data']['items'][0]['imageUrl'] = imagePath;
    h.reply = (r) {
      if (r.uri.path == imagePath) return imageReply();
      if (r.uri.path.endsWith('/orders')) return jsonReply(summary);
      return h.defaultReply(r);
    };
  });
  tearDown(() => dependencies.dispose());

  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool settle = true,
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
        home: screen,
      ),
    );
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
    'imageUrl parses as optional nullable string in preview/detail/batch items',
    () {
      final preview = clone(summary['data'][0]['itemPreview']);
      final item = clone(h.orderJson['data']['items'][0]);
      final batch = fixture('checkout-order', 'op-030');
      for (final value in [imagePath, null, '']) {
        preview['imageUrl'] = value;
        item['imageUrl'] = value;
        batch['data']['orders'][0]['items'][0]['imageUrl'] = value;
        expect(ItemPreview.parse(preview).imageUrl, value);
        expect(SnapshotItem.parse(item, reviewable: true).imageUrl, value);
        expect(
          CheckoutBatch.parse(batch['data']).orders.first.items.first.imageUrl,
          value,
        );
      }
      preview.remove('imageUrl');
      item.remove('imageUrl');
      expect(ItemPreview.parse(preview).imageUrl, isNull);
      expect(SnapshotItem.parse(item, reviewable: true).imageUrl, isNull);
      for (final value in [3, false, <String, dynamic>{}, <dynamic>[]]) {
        preview['imageUrl'] = value;
        item['imageUrl'] = value;
        expect(() => ItemPreview.parse(preview), throwsA(isA<ApiFailure>()));
        expect(() => SnapshotItem.parse(item), throwsA(isA<ApiFailure>()));
      }
    },
  );

  for (final detail in [false, true]) {
    testWidgets(
      '${detail ? 'Detail' : 'History'} shows decoded thumbnail and sends no credentials for public media',
      (tester) async {
        await show(
          tester,
          detail
              ? OrderDetailScreen(dependencies: dependencies, id: customerId)
              : OrdersScreen(dependencies: dependencies),
        );
        expect(find.byType(OrderItemRow), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(
          tester.widget<Image>(find.byType(Image)).semanticLabel,
          startsWith('Product image:'),
        );
        final requests = h.adapter.requests
            .where((r) => r.uri.path == imagePath)
            .toList();
        expect(requests, hasLength(1));
        expect(
          requests.single.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(
          requests.single.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('cookie')),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final kind in [
    'null',
    'empty',
    'missing',
    'foreign',
    'unsafe_path',
    'offline',
    'corrupt',
  ]) {
    testWidgets(
      '$kind image falls back while Order facts and actions remain available',
      (tester) async {
        final item = h.orderJson['data']['items'][0] as Map<String, dynamic>;
        item['imageUrl'] = switch (kind) {
          'null' => null,
          'empty' => '',
          'foreign' =>
            'https://untrusted.example/api/v1/product-media/$otherId',
          'unsafe_path' => '/api/v1/customer/account/photo',
          _ => imagePath,
        };
        if (kind == 'missing') item.remove('imageUrl');
        h.reply = (r) {
          if (r.uri.path == imagePath) {
            if (kind == 'offline') return jsonReply({}, status: 404);
            if (kind == 'corrupt') {
              return ResponseBody.fromBytes([1, 2, 3], 200);
            }
            return imageReply();
          }
          return h.defaultReply(r);
        };
        await show(
          tester,
          OrderDetailScreen(dependencies: dependencies, id: customerId),
        );
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);
        expect(find.byType(OrderItemRow), findsOneWidget);
        expect(find.textContaining('Purchased items'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Cancel Order'), 200);
        expect(find.text('Cancel Order'), findsOneWidget);
        if ([
          'null',
          'empty',
          'missing',
          'foreign',
          'unsafe_path',
        ].contains(kind)) {
          expect(
            h.adapter.requests.where((r) => r.uri.path == imagePath),
            isEmpty,
          );
        }
        expect(
          h.adapter.requests.every((r) => r.uri.host == 'localhost'),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('null item preview shows safe summary with placeholder', (
    tester,
  ) async {
    summary['data'][0]['itemPreview'] = null;
    await show(tester, OrdersScreen(dependencies: dependencies));
    expect(find.byType(OrderItemRow), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final detail in [false, true]) {
      testWidgets(
        '${detail ? 'Detail' : 'History'} wraps long names at $width px and doubled text',
        (tester) async {
          final name = List.filled(5, 'Long purchased Product name').join(' ');
          summary['data'][0]['itemPreview']['productName'] = name;
          h.orderJson['data']['items'][0]['productName'] = name;
          await show(
            tester,
            detail
                ? OrderDetailScreen(dependencies: dependencies, id: customerId)
                : OrdersScreen(dependencies: dependencies),
            size: Size(width, 844),
            scale: 2,
          );
          expect(find.byType(OrderItemRow), findsOneWidget);
          expect(tester.getSize(find.byType(Image)), const Size(64, 64));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final loss in ['logout', 'account_switch', 'consent', 'navigation']) {
    testWidgets('late image after $loss cannot restore Order thumbnail', (
      tester,
    ) async {
      final delayed = Completer<ResponseBody>();
      h.reply = (r) =>
          r.uri.path == imagePath ? delayed.future : h.defaultReply(r);
      await show(
        tester,
        OrderDetailScreen(dependencies: dependencies, id: customerId),
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      if (loss == 'logout' || loss == 'account_switch') {
        await h.session.signOut();
        if (loss == 'account_switch') {
          h.auth.identity = CustomerIdentity.parse(identityJson(id: otherId));
          h.auth.onLogin = () async => LoginResult.parse({
            'message': 'OK',
            'customer': identityJson(id: otherId),
            'token': 'synthetic-b-token',
          });
          await h.session.signIn(
            'buyer-b@example.invalid',
            'synthetic-password',
          );
        }
      } else if (loss == 'consent') {
        h.policies.consent = ConsentStatus.parse(consentJson(required: true));
        await h.session.refreshConsent();
      } else {
        await tester.pumpWidget(const MaterialApp(home: Text('Other route')));
      }
      await tester.pump();
      delayed.complete(imageReply());
      await tester.pumpAndSettle();
      expect(find.byType(OrderItemRow), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
