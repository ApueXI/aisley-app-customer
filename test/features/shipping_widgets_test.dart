import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/shipping_details.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';
import '../support/shipping_scenarios.dart';

void main() {
  for (final layout in [
    (size: const Size(320, 640), scale: 2.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(640, 320), scale: 2.0),
    (size: const Size(1440, 900), scale: 1.0),
  ]) {
    testWidgets(
      'shipping choices are accessible and require review at $layout',
      (tester) async {
        final h = CommerceHarness();
        await tester.runAsync(h.initialize);
        addTearDown(h.dispose);
        h.reply = (r) => r.uri.path.endsWith('/logistics-options')
            ? jsonReply(
                shippingScenario(
                      'multiple-provider-options',
                    )['expected']['body']
                    as Map<String, dynamic>,
              )
            : h.defaultReply(r);
        final c = h.commerce.checkout;
        c.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
        tester.view.physicalSize = layout.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final dependencies = h.dependencies();
          addTearDown(dependencies.discovery!.dispose);
          addTearDown(dependencies.savedStatus!.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: buyerTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(layout.scale)),
                child: child!,
              ),
              home: CheckoutScreen(dependencies: dependencies),
            ),
          );
          await tester.pumpAndSettle();
          expect(c.canQuote, false);
          final tile = find.byWidgetPredicate(
            (w) => w is RadioListTile<String> && w.value == otherId,
          );
          final radio = find.descendant(
            of: tile,
            matching: find.byType(Radio<String>),
          );
          await Scrollable.ensureVisible(tester.element(radio), alignment: .5);
          await tester.pumpAndSettle();
          final rect = tester.getRect(radio);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          final node = tester.getSemantics(tile);
          expect(
            node.getSemanticsData().label,
            contains('Synthetic Logistics'),
          );
          expect(node.getSemanticsData().label, contains('PHP 100.00'));
          expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            true,
          );
          await tester.tap(radio);
          await tester.pumpAndSettle();
          expect(c.shipping.selections.single.organizationId, otherId);
          expect(c.canQuote, true);
          expect(c.canPlace, false);
          // Measure the provider itself: unrelated rows can be partially outside
          // the viewport after scrolling to the provider controls.
          expect(node.rect.width, greaterThanOrEqualTo(48));
          expect(node.rect.height, greaterThanOrEqualTo(48));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await Scrollable.ensureVisible(
            tester.element(find.text('Review order')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Review order'));
          await tester.pumpAndSettle();
          expect(c.canPlace, true);
          expect(
            find.text('Shipping provider: Synthetic Logistics'),
            findsOneWidget,
          );
          // Select by keyboard through the native RadioGroup, invalidating review.
          await Scrollable.ensureVisible(tester.element(radio), alignment: .5);
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          for (var attempt = 0; attempt < 16; attempt++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
            if (tester.getSemantics(tile).flagsCollection.isFocused ==
                ui.Tristate.isTrue) {
              break;
            }
          }
          expect(
            tester.getSemantics(tile).flagsCollection.isFocused,
            ui.Tristate.isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expect(
            c.shipping.selections.single.organizationId,
            '33333333-3333-4333-8333-333333333333',
          );
          expect(c.canPlace, false);
          expect(c.quote, isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'unplanned and legacy shipping displays make no route or ETA promise',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShippingDetails(
              businessName: null,
              fee: 'PHP 5.00',
              routeStatus: 'unplanned',
            ),
          ),
        ),
      );
      expect(find.text('Shipping provider unavailable'), findsOneWidget);
      expect(find.text('Shipping fee: PHP 5.00'), findsOneWidget);
      expect(
        find.text(
          'Shipping is quoted. The delivery route is not confirmed; no delivery time is available.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShippingDetails(
              businessName: 'Provider',
              fee: 'PHP 5.00',
              routeStatus: 'future',
            ),
          ),
        ),
      );
      expect(
        find.text('Shipping route information is unavailable.'),
        findsOneWidget,
      );
    },
  );
}
