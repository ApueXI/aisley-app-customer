import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aisley_mobile_buyer/app/communication_state.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/account_home_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/home_screen.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_screens.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';

void main() {
  late CommerceHarness h;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    h = CommerceHarness();
    await h.initialize();
    h.reply = (r) => r.uri.path.endsWith('/home')
        ? jsonReply(fixture('customer-homepage', 'op-047'))
        : h.defaultReply(r);
  });
  tearDown(() => h.dispose());

  Future<void> check(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  for (final layout in [
    (size: const Size(320, 640), scale: 1.0),
    (size: const Size(320, 640), scale: 2.0),
    (size: const Size(1024, 768), scale: 1.0),
    (size: const Size(640, 320), scale: 2.0),
  ]) {
    for (final feature in [
      'discovery',
      'account',
      'checkout',
      'communication',
    ]) {
      testWidgets(
        '$feature accessibility at ${layout.size}, scale ${layout.scale}',
        (tester) async {
          tester.view.physicalSize = layout.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            final dependencies = h.dependencies();
            addTearDown(dependencies.discovery!.dispose);
            addTearDown(dependencies.savedStatus!.dispose);
            final communication = CommunicationState(h.session, h.api);
            addTearDown(communication.dispose);
            if (feature == 'checkout') {
              h.commerce.checkout.begin(
                CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)),
              );
            }
            final screen = switch (feature) {
              'discovery' => Scaffold(
                body: HomeScreen(dependencies: dependencies),
              ),
              'account' => Scaffold(
                body: AccountHomeScreen(session: h.session),
              ),
              'checkout' => CheckoutScreen(dependencies: dependencies),
              _ => ShopThreadScreen(
                dependencies: dependencies,
                controller: communication.shopThread(shop: otherId),
              ),
            };
            await tester.pumpWidget(
              MaterialApp(
                theme: buyerTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(layout.scale)),
                  child: child!,
                ),
                home: screen,
              ),
            );
            await tester.pumpAndSettle();
            await check(tester);
            if (feature == 'account') {
              await tester.scrollUntilVisible(find.text('Sign out'), 250);
              await tester.pumpAndSettle();
              await check(tester);
            } else if (feature == 'checkout') {
              await tester.ensureVisible(find.text('Get current quote'));
              await tester.tap(find.text('Get current quote'));
              await tester.pumpAndSettle();
              expect(h.commerce.checkout.canPlace, isTrue);
              await tester.ensureVisible(find.text('Place COD order'));
              await tester.pumpAndSettle();
              await check(tester);
              expect(
                h.adapter.requests.where((r) => r.uri.path.endsWith('/place')),
                isEmpty,
              );
            } else if (feature == 'communication') {
              await tester.ensureVisible(find.byType(TextFormField));
              await tester.tap(find.byType(TextFormField));
              await tester.enterText(
                find.byType(TextFormField),
                'Unsent synthetic draft',
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pump();
              tester.view.viewInsets = const FakeViewPadding(bottom: 120);
              addTearDown(tester.view.resetViewInsets);
              await tester.ensureVisible(find.text('Send message'));
              await tester.pumpAndSettle();
              await check(tester);
              expect(
                h.adapter.requests.where((r) => r.method == 'POST'),
                isEmpty,
              );
            }
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            h.commerce.checkout.invalidateQuote();
            semantics.dispose();
          }
        },
      );
    }
  }
}
