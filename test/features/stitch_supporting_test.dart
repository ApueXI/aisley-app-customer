import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/address_book_screen.dart';
import 'package:aisley_mobile_buyer/features/notifications/presentation/notification_screens.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_screens.dart';

import '../support/commerce_harness.dart';
import '../support/communication_harness.dart';
import '../support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 3),
  );
}

void main() {
  testWidgets('embedded notifications render a shell body without an app bar', (
    tester,
  ) async {
    final h = CommunicationHarness();
    await tester.runAsync(h.initialize);
    final dependencies = h.dependencies();
    addTearDown(() {
      dependencies.discovery!.dispose();
      h.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        home: Material(
          child: NotificationInboxScreen(
            dependencies: dependencies,
            embedded: true,
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.byType(Scaffold), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Unread'), findsNWidgets(2));
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Support ticket reply'), findsOneWidget);
    expect(find.text('Promotional preferences'), findsNothing);
    expect(
      h.adapter.requests.where((request) => request.method == 'POST'),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('address cards mark verified defaults and omit map coordinates', (
    tester,
  ) async {
    final h = CommerceHarness();
    await tester.runAsync(h.initialize);
    final addressResponse = fixture('address-book', 'op-015');
    final address = (addressResponse['data'] as List).first as Map;
    address['label'] = 'Home';
    address['isDefault'] = true;
    address['latitude'] = 14.5995;
    address['longitude'] = 120.9842;
    h.reply = (request) => request.uri.path.endsWith('/addresses')
        ? jsonReply(addressResponse)
        : h.defaultReply(request);
    final dependencies = h.dependencies();
    addTearDown(() {
      dependencies.discovery!.dispose();
      dependencies.savedStatus!.dispose();
      h.dispose();
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AddressBookScreen(dependencies: dependencies),
      ),
    );
    await settle(tester);

    expect(
      find.text(
        'Address changes apply to future orders. Placed orders keep their saved address.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Home'), 160);
    await settle(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.textContaining('Pin:'), findsNothing);
    expect(find.textContaining('14.5995'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Shop thread keeps server context above a docked composer', (
    tester,
  ) async {
    final h = CommunicationHarness();
    await h.initialize();
    final dependencies = h.dependencies();
    addTearDown(() {
      dependencies.discovery!.dispose();
      h.dispose();
    });
    h.reply = (request) {
      if (request.uri.path.endsWith('/messages')) {
        final page = fixture('chat-messaging', 'op-060');
        final rows = page['items'] as List;
        (rows.first as Map<String, dynamic>)['context'] = {
          'type': 'product',
          'id': '22222222-2222-4222-8222-222222222222',
          'label': 'Synthetic product context',
          'url': null,
        };
        return jsonReply(page);
      }
      if (request.uri.path.endsWith('/conversations/$customerId')) {
        final summary = fixture('chat-messaging', 'op-059');
        summary['data']['send_allowed'] = true;
        return jsonReply(summary);
      }
      return h.defaultReply(request);
    };

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ShopThreadScreen(
          dependencies: dependencies,
          controller: h.state.shopThread(id: customerId),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('View product'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.text('Synthetic product context'),
      ),
      findsOneWidget,
    );
    final send = find.widgetWithText(FilledButton, 'Send');
    await tester.ensureVisible(send);
    await settle(tester);
    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    expect(tester.getSize(send).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
