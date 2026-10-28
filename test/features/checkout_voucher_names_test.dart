import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/voucher_models.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/batch_result_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/quote_review.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/voucher_savings_summary.dart';

import '../support/checkout_voucher_harness.dart';
import '../support/fakes.dart';

Map<String, dynamic> appliedJson() => {
  ...checkoutVoucher(appDiscountA, 'app', 'discount'),
  'qualifyingBasis': '100.00',
  'discountAmount': '10.00',
};

void main() {
  test(
    'applied and Batch projections retain server names and exact savings',
    () {
      final json = appliedJson()..['name'] = 'Reviewed benefit';
      final applied = AppliedVoucher.parse(json);
      final batch = SnapshotVoucher.parse(json, batch: true);
      expect(applied.name, 'Reviewed benefit');
      expect(batch.name, 'Reviewed benefit');
      expect(applied.code, json['code']);
      expect(batch.code, json['code']);
      expect(applied.discount.minorUnits, 1000);
      expect(batch.qualifyingBasis!.minorUnits, 10000);
    },
  );

  for (final omit in [true, false]) {
    test(
      'historical missing/null name falls back to code (omitted: $omit)',
      () {
        final json = appliedJson();
        if (omit) {
          json.remove('name');
        } else {
          json['name'] = null;
        }
        expect(CheckoutVoucher.parse(json).name, json['code']);
        expect(AppliedVoucher.parse(json).name, json['code']);
        expect(SnapshotVoucher.parse(json, batch: true).name, json['code']);
      },
    );
  }

  test(
    'Order snapshots still consume code and currency without a name field',
    () {
      final json = appliedJson()
        ..remove('name')
        ..remove('qualifyingBasis')
        ..['currency'] = 'PHP';
      final order = SnapshotVoucher.parse(json);
      expect(order.name, json['code']);
      expect(order.currency, 'PHP');
      expect(order.qualifyingBasis, isNull);
    },
  );

  test(
    'malformed applied/Batch names fail decoding rather than hiding damage',
    () {
      for (final invalid in [7, false, <String>[], <String, dynamic>{}]) {
        final json = appliedJson()..['name'] = invalid;
        expect(() => AppliedVoucher.parse(json), throwsA(isA<ApiFailure>()));
        expect(
          () => SnapshotVoucher.parse(json, batch: true),
          throwsA(isA<ApiFailure>()),
        );
      }
    },
  );

  for (final layout in [
    (size: const Size(320, 720), scale: 2.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(600, 900), scale: 1.0),
    (size: const Size(800, 900), scale: 1.0),
    (size: const Size(1024, 900), scale: 1.0),
    (size: const Size(1440, 900), scale: 1.0),
    (size: const Size(800, 390), scale: 2.0),
  ]) {
    for (final result in [false, true]) {
      testWidgets(
        'voucher names and savings wrap in ${result ? 'Batch' : 'review'} at $layout',
        (tester) async {
          final h = CheckoutVoucherHarness();
          final name = List.filled(6, 'Frozen merchandise benefit').join(' ');
          h.candidates[shopA]!.firstWhere(
            (v) => v['id'] == appDiscountA,
          )['name'] = name;
          h.candidates[shopA]!.firstWhere(
            (v) => v['id'] == shopShippingA,
          )['name'] = 'Shipping benefit';
          await tester.runAsync(() async {
            await h.initialize();
            await h.begin();
            await h.select(shopA, appDiscountA);
            await h.select(shopA, shopShippingA);
            if (result) {
              expect(await h.checkout.place(), isNotNull);
              // Current definitions change after commit. Batch must use frozen data.
              h.candidates[shopA]!.firstWhere(
                (v) => v['id'] == appDiscountA,
              )['name'] = 'Changed current definition';
            }
          });
          final dependencies = h.dependencies();
          addTearDown(dependencies.dispose);
          tester.view.physicalSize = layout.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final router = GoRouter(
            initialLocation: result
                ? '/checkout/result/$customerId'
                : '/review',
            routes: [
              GoRoute(
                path: '/review',
                builder: (_, _) => Scaffold(
                  body: SingleChildScrollView(
                    child: QuoteReview(
                      quote: h.checkout.quote!,
                      controller: h.checkout,
                      discovery: dependencies.discovery!,
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/checkout/result/:id',
                builder: (_, _) => BatchResultScreen(
                  dependencies: dependencies,
                  id: customerId,
                ),
              ),
              GoRoute(path: '/orders', builder: (_, _) => const Text('Orders')),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              theme: buyerTheme(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(layout.scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final summary = find.byType(VoucherSavingsSummary);
          expect(summary, findsNWidgets(2));
          expect(find.text('Applied $name'), findsOneWidget);
          expect(find.text('Applied Shipping benefit'), findsOneWidget);
          expect(find.text('Code: CODE-00000001'), findsOneWidget);
          expect(find.text('Merchandise savings: PHP 10.00'), findsOneWidget);
          expect(find.text('Shipping savings: PHP 10.00'), findsOneWidget);
          expect(
            find.textContaining('Changed current definition'),
            findsNothing,
          );
          await tester.ensureVisible(find.text('Applied $name'));
          await tester.pumpAndSettle();
          final card = tester.getRect(summary.first);
          expect(card.left, greaterThanOrEqualTo(0));
          expect(card.right, lessThanOrEqualTo(layout.size.width));
          expect(tester.takeException(), isNull);
          if (result) {
            final before = h.adapter.requests.length;
            await tester.ensureVisible(find.text('Refresh result'));
            await tester.tap(find.text('Refresh result'));
            await tester.pumpAndSettle();
            expect(find.text('Applied $name'), findsOneWidget);
            expect(
              h.adapter.requests
                  .skip(before)
                  .every(
                    (r) =>
                        r.method == 'GET' && r.uri.path.contains('/checkout/'),
                  ),
              isTrue,
            );
          }
          h.checkout.invalidateQuote();
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'tapping a replacement unchecks the old voucher after reviewed refresh',
    (tester) async {
      final h = CheckoutVoucherHarness();
      await tester.runAsync(() async {
        await h.initialize();
        await h.begin();
        await h.select(shopA, appDiscountA);
      });
      final dependencies = h.dependencies();
      addTearDown(dependencies.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => CheckoutScreen(dependencies: dependencies),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: buyerTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review order'));
      await tester.tap(find.text('Review order'));
      await tester.pumpAndSettle();
      final replacement = find
          .widgetWithText(CheckboxListTile, 'Voucher $appDiscountB')
          .first;
      await tester.ensureVisible(replacement);
      final semantics = tester.ensureSemantics();
      try {
        final replacementLabel = tester
            .getSemantics(replacement)
            .getSemanticsData()
            .label;
        expect(replacementLabel, contains('Voucher $appDiscountB'));
        expect(replacementLabel, contains('Merchandise discount'));
      } finally {
        semantics.dispose();
      }
      await tester.tap(replacement);
      await tester.pumpAndSettle();
      expect(h.checkout.quote, isNull);
      expect(h.checkout.canPlace, isFalse);
      await tester.ensureVisible(find.text('Review order'));
      await tester.tap(find.text('Review order'));
      await tester.pumpAndSettle();
      final old = find
          .widgetWithText(CheckboxListTile, 'Voucher $appDiscountA')
          .first;
      final current = find
          .widgetWithText(CheckboxListTile, 'Voucher $appDiscountB')
          .first;
      expect(tester.widget<CheckboxListTile>(old).value, isFalse);
      expect(tester.widget<CheckboxListTile>(current).value, isTrue);
      expect(h.checkout.canPlace, isTrue);
      expect(h.keys, 0);
      expect(tester.takeException(), isNull);
      h.checkout.invalidateQuote();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
