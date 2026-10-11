import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/router.dart';
import 'package:aisley_mobile_buyer/app/router_guard.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_controller.dart';
import 'package:aisley_mobile_buyer/features/vouchers/data/voucher_repository.dart';
import 'package:aisley_mobile_buyer/features/vouchers/presentation/voucher_screens.dart';
import 'package:aisley_mobile_buyer/features/vouchers/presentation/shop_vouchers_section.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';
import '../support/voucher_fixtures.dart';

void main() {
  late CommerceHarness h;
  late AppDependencies d;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
    d = AppDependencies(
      config: testConfig,
      auth: h.auth,
      policies: h.policies,
      session: h.session,
      launcher: h.dependencies().launcher,
      client: h.api,
      commerce: h.commerce,
      addresses: h.dependencies().addresses,
      vouchers: VoucherRepository(h.api),
    );
  });
  tearDown(() {
    d.voucherCollection?.dispose();
    d.vouchers?.dispose();
    h.dispose();
  });
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  test(
    'new read destinations resume login/consent without accepting mutations',
    () {
      expect(safeReturn('/vouchers'), '/vouchers');
      expect(safeReturn('/vouchers/$otherId'), '/vouchers/$otherId');
      expect(safeReturn('/account/vouchers'), '/account/vouchers');
      expect(safeReturn('/vouchers/$otherId?claim=true'), '/');
      expect(safeReturn('https://evil.test/vouchers/$otherId'), '/');
    },
  );
  for (final width in [320.0, 390.0, 600.0, 800.0, 1024.0, 1440.0]) {
    testWidgets(
      'discovery and detail fit width $width with doubled text and accessible actions',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        h.reply = (r) => jsonReply(
          r.uri.path.endsWith('voucher-statuses')
              ? {
                  'items': [
                    voucherJson()..['name'] = 'Long Shop voucher with readable conditions and savings',
                  ],
                }
              : voucherPage([voucherJson(private: false)]),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buyerTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: VoucherListScreen(dependencies: d),
          ),
        );
        await settle(tester);
        final button = find.widgetWithText(FilledButton, 'Collect voucher');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final size = tester.getSize(button);
        expect(size.height, greaterThanOrEqualTo(48));
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        final semantics = tester.ensureSemantics();
        expect(find.text('All issuers'), findsOneWidget);
        semantics.dispose();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'Shop voucher page is independent and failed personalized status cannot collect',
    (tester) async {
      h.reply = (r) => r.uri.path.endsWith('voucher-statuses')
          ? jsonReply({}, status: 503)
          : jsonReply(voucherPage([voucherJson(private: false)], lastPage: 2));
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShopVouchersSection(dependencies: d, slug: 'demo-shop'),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(
        find.textContaining('availability could not be checked'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Collect voucher'),
            )
            .onPressed,
        isNull,
      );
      expect(
        h.adapter.requests.any(
          (r) => r.uri.path == '/api/v1/customer/shops/demo-shop/vouchers',
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'wallet empty, paused, partial use, history and denied detail remain distinct',
    (tester) async {
      h.reply = (r) => jsonReply(
        voucherPage([
          voucherJson(collected: true, reason: 'VOUCHER_INACTIVE')
            ..['remainingPersonalUses'] = 1,
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: VoucherListScreen(dependencies: d, wallet: true),
        ),
      );
      await settle(tester);
      expect(find.text('This voucher is paused.'), findsOneWidget);
      expect(find.text('1 personal uses remaining'), findsOneWidget);
      h.reply = (_) => jsonReply(voucherPage([]));
      await tester.tap(find.widgetWithText(ChoiceChip, 'History'));
      await settle(tester);
      expect(find.textContaining('No vouchers in this tab'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      h.reply = (_) => jsonReply({}, status: 404);
      final router = buyerRouter(d);
      addTearDown(router.dispose);
      router.go('/vouchers/$otherId');
      await tester.pumpWidget(
        MaterialApp.router(theme: buyerTheme(), routerConfig: router),
      );
      await settle(tester);
      expect(find.text('This resource is unavailable.'), findsOneWidget);
      expect(find.text('Collect voucher'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Checkout collection requires explicit requote and selection before reviewed savings',
    (tester) async {
      var claimed = false;
      h.reply = (r) {
        if (r.uri.path.endsWith('/claim')) {
          claimed = true;
          return jsonReply({'data': voucherJson(collected: true)});
        }
        if (r.uri.path.endsWith('/voucher-statuses')) {
          return jsonReply({
            'items': [voucherJson(collected: claimed)],
          });
        }
        if (r.uri.path.endsWith('/quote')) {
          final q = h.quoteFor(r.data as Map<String, dynamic>);
          final group = q['data']['groups'][0];
          group['availableVouchers'] = [checkoutVoucherJson(claimed: claimed)];
          if ((r.data['vouchers'] as List?)?.isNotEmpty == true) {
            group['appliedVouchers'] = [
              {
                'id': otherId,
                'code': 'DEMO',
                'issuerType': 'shop',
                'benefitType': 'discount',
                'qualifyingBasis': '100.00',
                'discountAmount': '10.00',
              },
            ];
            group['totals']['discount'] = '10.00';
            group['totals']['payable'] =
                (double.parse(group['totals']['payable'] as String) - 10)
                    .toStringAsFixed(2);
            q['data']['summary']['payable'] =
                (double.parse(q['data']['summary']['payable'] as String) - 10)
                    .toStringAsFixed(2);
            q['data']['summary']['discount'] = '10.00';
          }
          return jsonReply(q);
        }
        return h.defaultReply(r);
      };
      final c = h.commerce.checkout;
      c.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
      final router = buyerRouter(d);
      addTearDown(router.dispose);
      router.go('/checkout');
      await tester.pumpWidget(
        MaterialApp.router(theme: buyerTheme(), routerConfig: router),
      );
      await settle(tester);
      await tester.runAsync(c.getQuote);
      await settle(tester);
      final collect = find.widgetWithText(TextButton, 'Collect voucher');
      await tester.ensureVisible(collect);
      await tester.tap(collect);
      await settle(tester);
      expect(c.canPlace, false);
      expect(c.quote, isNull);
      final claim = find.widgetWithText(FilledButton, 'Collect voucher');
      await tester.ensureVisible(claim);
      await tester.tap(claim);
      await settle(tester);
      expect(claimed, true);
      expect(c.vouchers, isEmpty);
      expect(c.quote, isNull);
      await tester.ensureVisible(find.text('Back').last);
      await tester.tap(find.text('Back').last);
      await settle(tester);
      expect(c.canPlace, false);
      expect(find.textContaining('After collecting'), findsOneWidget);
      await tester.runAsync(c.getQuote);
      await settle(tester);
      final group = c.quote!.groups.single;
      c.chooseVoucher(group, CheckoutVoucherCandidate(otherId), true);
      await settle(tester);
      expect(c.canPlace, false);
      await tester.runAsync(c.getQuote);
      await settle(tester);
      expect(c.canPlace, true);
      expect(c.quote!.groups.single.applied.single.discount.minorUnits, 1000);
      expect(
        h.adapter.requests.where((r) => r.uri.path.endsWith('/place')),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
