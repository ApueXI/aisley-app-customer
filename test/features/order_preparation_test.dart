import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_models.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_repository.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/order_preparation_panel.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/order_detail_screen.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';

Map<String, dynamic> preparation({bool used = false, bool overdue = true}) => {
  'acceptedAt': '2026-11-01T00:00:00Z',
  'initialDeadlineAt': '2026-11-04T00:00:00Z',
  'deadlineAt': used ? '2026-11-08T00:00:00Z' : '2026-11-04T00:00:00Z',
  'extendedAt': used ? '2026-11-05T00:00:00Z' : null,
  'extensionUsed': used,
  'overdue': overdue,
  'active': true,
  'serverTime': '2026-11-05T00:00:00Z',
};

void main() {
  late CommerceHarness h;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
  });
  tearDown(() => h.dispose());
  BuyerOrder overdueOrder() {
    final data = h.orderJson['data'] as Map<String, dynamic>;
    data['status'] = 'seller_processing';
    data['preparation'] = preparation();
    data['actions'] = {
      ...data['actions'] as Map<String, dynamic>,
      'canCancel': true,
      'canExtendPreparation': true,
    };
    return BuyerOrder.parse(data);
  }

  test('older responses hide extension and server capabilities permit overdue cancellation', () {
    expect(BuyerOrder.parse(h.orderJson['data']).canExtendPreparation, false);
    final order = overdueOrder();
    expect(order.canCancel, true);
    expect(order.canCorrect, false);
    expect(order.canExtendPreparation, true);
    final data = h.orderJson['data'] as Map<String, dynamic>;
    data['actions']['canExtendPreparation'] = false;
    data['actions']['canCancel'] = false;
    expect(BuyerOrder.parse(data).canExtendPreparation, false);
    expect(BuyerOrder.parse(data).canCancel, false);
    data['preparation']['extensionUsed'] = 'true';
    expect(() => BuyerOrder.parse(data), throwsA(anything));
  });

  test('extension uses POST, an empty payload and an exact session-scoped retry key', () async {
    final order = overdueOrder();
    final requests = <RequestOptions>[];
    h.reply = (options) {
      if (!options.path.endsWith('/preparation-extension')) {
        return h.defaultReply(options);
      }
      requests.add(options);
      if (requests.length == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      }
      final value = clone(h.orderJson);
      value['data']['preparation'] = preparation(used: true, overdue: false);
      value['data']['actions'] = {
        ...value['data']['actions'] as Map<String, dynamic>,
        'canCancel': false,
        'canExtendPreparation': false,
      };
      return jsonReply(value);
    };
    expect(
      await h.commerce.mutations.extendPreparation(order, fresh: false),
      null,
    );
    expect(requests, isEmpty);
    expect(
      await h.commerce.mutations.extendPreparation(order, fresh: true),
      null,
    );
    final pending = h.commerce.mutations.pending(order.id)!;
    expect(pending.kind, OrderMutationKind.extension);
    expect(requests.single.method, 'POST');
    expect(requests.single.data, isEmpty);
    expect(await h.commerce.mutations.cancel(order, null, fresh: true), null);
    final result = await h.commerce.mutations.retry(order.id);
    expect(result!.preparation!.extensionUsed, true);
    expect(result.canCancel, false);
    expect(requests, hasLength(2));
    expect(
      requests[0].headers['Idempotency-Key'],
      requests[1].headers['Idempotency-Key'],
    );
    expect(h.commerce.mutations.pending(order.id), null);
  });

  test(
    'conflict requests refresh and identity loss clears pending extension',
    () async {
      final order = overdueOrder();
      h.reply = (options) => options.path.endsWith('/preparation-extension')
          ? jsonReply({
              'message': 'Order changed',
              'code': 'ORDER_PREPARATION_NOT_EXTENDABLE',
            }, status: 409)
          : h.defaultReply(options);
      await h.commerce.mutations.extendPreparation(order, fresh: true);
      expect(h.commerce.mutations.needsRefresh(order.id), true);
      expect(h.commerce.mutations.pending(order.id), null);
      h.commerce.mutations.refreshed(order.id);
      final response = Completer<ResponseBody>();
      h.reply = (options) => options.path.endsWith('/preparation-extension')
          ? response.future
          : h.defaultReply(options);
      final operation = h.commerce.mutations.extendPreparation(
        order,
        fresh: true,
      );
      await Future<void>.delayed(Duration.zero);
      await h.session.signOut();
      expect(h.commerce.mutations.pending(order.id), null);
      response.complete(jsonReply(h.orderJson));
      expect(await operation, null);
      expect(h.commerce.mutations.pending(order.id), null);
    },
  );

  testWidgets(
    'order detail confirms an extension and shows the committed deadline',
    (tester) async {
      final order = overdueOrder();
      var writes = 0;
      h.reply = (options) {
        if (options.path.endsWith('/preparation-extension')) {
          writes++;
          h.orderJson['data']['preparation'] = preparation(
            used: true,
            overdue: false,
          );
          h.orderJson['data']['actions']['canCancel'] = false;
          h.orderJson['data']['actions']['canExtendPreparation'] = false;
          return jsonReply(h.orderJson);
        }
        return h.defaultReply(options);
      };
      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailScreen(dependencies: h.dependencies(), id: order.id),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Extend preparation by 3 days'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Extend preparation by 3 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extend preparation by 3 days'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Confirm 3-day extension'), findsOneWidget);
      await tester.tap(find.text('Confirm 3-day extension'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Extend preparation by 3 days'), findsNothing);
      expect(find.textContaining('Extended deadline'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      testWidgets(
        'preparation panel $brightness at $width wraps and hides consumed extension',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var taps = 0;
          final value = overdueOrder().preparation!;
          Widget app(bool enabled) => MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: ListView(
                children: [
                  OrderPreparationPanel(
                    preparation: value,
                    canExtend: enabled,
                    onExtend: () => taps++,
                  ),
                ],
              ),
            ),
          );
          await tester.pumpWidget(app(true));
          expect(find.text('Seller preparation'), findsOneWidget);
          await tester.tap(find.text('Extend preparation by 3 days'));
          expect(taps, 1);
          expect(tester.takeException(), null);
          await tester.pumpWidget(app(false));
          expect(find.text('Extend preparation by 3 days'), findsNothing);
          expect(tester.takeException(), null);
        },
      );
    }
  }
}
