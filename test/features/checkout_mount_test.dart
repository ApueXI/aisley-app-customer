import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_screen.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';

void main() {
  testWidgets('checkout can mount and reopen beside an existing listener', (
    tester,
  ) async {
    final h = CommerceHarness();
    await tester.runAsync(h.initialize);
    addTearDown(h.dispose);
    final checkout = h.commerce.checkout;
    checkout.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);
    final dependencies = h.dependencies();
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ListenableBuilder(
              listenable: checkout,
              builder: (_, _) =>
                  Text(checkout.loadingAddresses ? 'Loading' : 'Ready'),
            ),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (_, show, _) => show
                    ? CheckoutScreen(dependencies: dependencies)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
    for (var visit = 0; visit < 2; visit++) {
      visible.value = true;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(checkout.addressesFresh, isTrue);
      expect(checkout.canPlace, isFalse);
      visible.value = false;
      await tester.pumpAndSettle();
    }
    expect(
      h.adapter.requests.where((r) => r.uri.path.endsWith('/addresses')),
      hasLength(2),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
