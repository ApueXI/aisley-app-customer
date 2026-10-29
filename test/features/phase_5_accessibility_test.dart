import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';

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
import '../support/shop_context_fixtures.dart';

void main() {
  late CommerceHarness h;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    h = CommerceHarness();
    await h.initialize();
    h.reply = (r) {
      if (r.uri.path.contains('/conversations/shops/')) {
        return jsonReply({'data': shopContext()});
      }
      if (r.uri.path.endsWith('/home')) {
        return jsonReply(fixture('customer-homepage', 'op-047'));
      }
      if (r.uri.path.endsWith('/checkout/quote')) {
        return jsonReply(h.quoteFor(r.data as Map<String, dynamic>));
      }
      return h.defaultReply(r);
    };
  });
  tearDown(() => h.dispose());

  Future<void> check(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await Scrollable.ensureVisible(
      tester.element(target),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    await tester.pumpAndSettle();
  }

  Future<void> checkAction(WidgetTester tester, String label) async {
    final button = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    await reveal(tester, button);
    expect(button.hitTestable(), findsOneWidget);
    final rect = tester.getRect(button);
    final scroll = Scrollable.of(tester.element(button));
    final visible = rect.intersect(
      tester.getRect(find.byWidget(scroll.widget)),
    );
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(visible.size, rect.size);
  }

  Future<void> checkAddress(
    WidgetTester tester,
    Finder tile, {
    required String title,
    required bool checked,
  }) async {
    final radio = find.descendant(
      of: tile,
      matching: find.byType(Radio<String>),
    );
    // A long, scaled address can exceed the viewport. Reveal its actual control
    // before measuring instead of treating a scrolled-off fragment as a target.
    await Scrollable.ensureVisible(tester.element(radio), alignment: .5);
    await tester.pumpAndSettle();
    final control = tester.getRect(radio);
    expect(control.width, greaterThanOrEqualTo(48));
    expect(control.height, greaterThanOrEqualTo(48));
    final node = tester.getSemantics(tile);
    expect(node.rect.width, greaterThanOrEqualTo(48));
    expect(node.rect.height, greaterThanOrEqualTo(48));
    final data = node.getSemanticsData();
    expect(data.label, contains(title));
    expect(data.label, contains('Synthetic example'));
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(
      data.flagsCollection.isChecked,
      checked ? ui.CheckedState.isTrue : ui.CheckedState.isFalse,
    );
    await check(tester);
  }

  for (final layout in [
    (size: const Size(320, 640), scale: 1.0),
    (size: const Size(320, 640), scale: 2.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(600, 960), scale: 2.0),
    (size: const Size(800, 1280), scale: 1.0),
    (size: const Size(1024, 768), scale: 1.0),
    (size: const Size(1440, 900), scale: 1.0),
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
              await checkAddress(
                tester,
                find.byType(RadioListTile<String>),
                title: 'Synthetic example',
                checked: true,
              );
              await reveal(tester, find.text('Review order'));
              await tester.tap(find.text('Review order'));
              await tester.pumpAndSettle();
              expect(h.commerce.checkout.canPlace, isTrue);
              // Do not scroll an already-visible desktop action to the top:
              // that clips the address group's semantics to a viewport sliver.
              await reveal(tester, find.text('Place COD order'));
              await check(tester);
              expect(
                h.adapter.requests.where((r) => r.uri.path.endsWith('/place')),
                isEmpty,
              );
            } else if (feature == 'communication') {
              await tester.ensureVisible(find.byType(TextFormField));
              await tester.pumpAndSettle();
              final composerInput = find.descendant(
                of: find.byType(TextFormField),
                matching: find.byType(EditableText),
              );
              await Scrollable.ensureVisible(
                tester.element(composerInput),
                alignment: .5,
              );
              await tester.pumpAndSettle();
              await tester.tap(composerInput);
              await tester.enterText(
                find.byType(TextFormField),
                'Unsent synthetic draft',
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pump();
              tester.view.viewInsets = const FakeViewPadding(bottom: 120);
              addTearDown(tester.view.resetViewInsets);
              await tester.ensureVisible(find.text('Send'));
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

  for (final layout in [
    (size: const Size(320, 640), scale: 2.0, inset: 200.0),
    (size: const Size(390, 844), scale: 1.0, inset: 300.0),
    (size: const Size(640, 320), scale: 2.0, inset: 120.0),
    (size: const Size(1440, 900), scale: 1.0, inset: 300.0),
    (size: const Size(1440, 900), scale: 2.0, inset: 300.0),
  ]) {
    testWidgets(
      'checkout address selection, focus and keyboard at ${layout.size}, scale ${layout.scale}',
      (tester) async {
        tester.view.physicalSize = layout.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final semantics = tester.ensureSemantics();
        final c = h.commerce.checkout;
        try {
          final addresses = fixture('address-book', 'op-015');
          final first = addresses['data'][0] as Map<String, dynamic>;
          first['label'] = 'Home with a long synthetic address label';
          first['addressLine1'] =
              'Unit 12, Synthetic apartment building, Example access road';
          final second = clone(first)
            ..['id'] = otherId
            ..['label'] = null
            ..['recipientName'] = 'Synthetic recipient B'
            ..['isDefault'] = false;
          addresses['data'] = [first, second];
          final reply = h.reply!;
          h.reply = (r) => r.uri.path.endsWith('/addresses')
              ? jsonReply(addresses)
              : reply(r);
          final dependencies = h.dependencies();
          addTearDown(dependencies.discovery!.dispose);
          addTearDown(dependencies.savedStatus!.dispose);
          c.begin(CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)));
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
          final tiles = find.byType(RadioListTile<String>);
          expect(tiles, findsNWidgets(2));
          await checkAddress(
            tester,
            tiles.at(0),
            title: first['label'] as String,
            checked: true,
          );
          await checkAddress(
            tester,
            tiles.at(1),
            title: second['recipientName'] as String,
            checked: false,
          );
          await reveal(tester, find.text('Review order'));
          await tester.tap(find.text('Review order'));
          await tester.pumpAndSettle();
          expect(c.canPlace, isTrue);

          // Native RadioGroup traversal has one Tab stop, then arrow selection.
          FocusManager.instance.primaryFocus?.unfocus();
          for (var attempt = 0; attempt < 8; attempt++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
            if (tester.getSemantics(tiles.at(0)).flagsCollection.isFocused ==
                ui.Tristate.isTrue) {
              break;
            }
          }
          expect(
            tester.getSemantics(tiles.at(0)).flagsCollection.isFocused,
            ui.Tristate.isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(c.addressId, otherId);
          expect(c.quote, isNull);
          expect(c.canPlace, isFalse);
          await checkAddress(
            tester,
            tiles.at(1),
            title: second['recipientName'] as String,
            checked: true,
          );
          expect(
            tester.getSemantics(tiles.at(1)).flagsCollection.isFocused,
            ui.Tristate.isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(
            tester.getSemantics(tiles.at(0)).flagsCollection.isFocused,
            isNot(ui.Tristate.isTrue),
          );
          expect(
            tester.getSemantics(tiles.at(1)).flagsCollection.isFocused,
            isNot(ui.Tristate.isTrue),
          );
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pumpAndSettle();
          expect(
            tester.getSemantics(tiles.at(1)).flagsCollection.isFocused,
            ui.Tristate.isTrue,
          );

          tester.view.viewInsets = FakeViewPadding(bottom: layout.inset);
          await tester.pumpAndSettle();
          expect(c.addressId, otherId);
          await checkAddress(
            tester,
            tiles.at(1),
            title: second['recipientName'] as String,
            checked: true,
          );
          expect(
            tester.getSemantics(tiles.at(1)).flagsCollection.isFocused,
            ui.Tristate.isTrue,
          );
          await checkAction(tester, 'Review order');

          // A pending quote disables selection, preserving its frozen address.
          final gate = Completer<ResponseBody>();
          ResponseBody? quotedResponse;
          h.reply = (r) {
            if (!r.uri.path.endsWith('/checkout/quote')) return reply(r);
            quotedResponse = reply(r) as ResponseBody;
            return gate.future;
          };
          final flight = c.getQuote();
          for (
            var attempt = 0;
            attempt < 10 && quotedResponse == null;
            attempt++
          ) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          expect(quotedResponse, isNotNull);
          expect(
            tester.widget<RadioListTile<String>>(tiles.at(0)).enabled,
            false,
          );
          expect(
            tester.getSemantics(tiles.at(0)).flagsCollection.isEnabled,
            ui.Tristate.isFalse,
          );
          expect(h.adapter.requests.last.data['address_id'], otherId);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          expect(c.addressId, otherId);
          gate.complete(quotedResponse);
          await tester.pumpAndSettle();
          await flight;
          expect(c.error, isNull);
          expect(c.canPlace, isTrue);
          await checkAction(tester, 'Place COD order');
          await check(tester);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          expect(c.addressId, otherId);
          expect(c.canPlace, isTrue);
          await checkAction(tester, 'Place COD order');
          expect(
            h.adapter.requests.where((r) => r.uri.path.endsWith('/quote')),
            hasLength(2),
          );
          expect(
            h.adapter.requests.where((r) => r.uri.path.endsWith('/place')),
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          c.invalidateQuote();
          semantics.dispose();
        }
      },
    );
  }
}
