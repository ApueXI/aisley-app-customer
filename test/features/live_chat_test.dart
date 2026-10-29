import 'dart:async';

import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_screens.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';

void main() {
  late CommunicationHarness h;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize(deadline: const Duration(seconds: 10));
  });
  tearDown(() => h.dispose());

  for (final channel in ['shop', 'logistics', 'courier']) {
    final shop = channel == 'shop';
    final feature = shop ? 'chat-messaging' : '$channel-messaging';
    final detailOp = shop
        ? 'op-059'
        : channel == 'logistics'
        ? 'op-066'
        : 'op-072';
    final historyOp = shop
        ? 'op-060'
        : channel == 'logistics'
        ? 'op-067'
        : 'op-073';
    test(
      '$channel background refresh preserves composer and action errors',
      () async {
        final dynamic c = switch (channel) {
          'shop' => h.state.shopThread(id: customerId),
          'logistics' => h.state.logisticsThread(id: customerId),
          _ => h.state.courierThread(id: customerId),
        };
        h.reply = (r) {
          final body = fixture(
            feature,
            r.uri.path.endsWith('/messages') ? historyOp : detailOp,
          );
          if (!r.uri.path.endsWith('/messages')) {
            body['data']['send_allowed'] = true;
          }
          return jsonReply(body);
        };
        await c.load();
        c.draft = 'Safe synthetic draft';
        c.error = 'Deliberate send error';
        c.fieldErrors = <String, String>{'body': 'Review this message'};
        final delayed = Completer<ResponseBody>();
        h.reply = (_) => delayed.future;
        final Future<void> refresh = c.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(c.refreshing, isTrue);
        expect(c.loading, isFalse);
        expect(c.draft, 'Safe synthetic draft');
        expect(c.error, 'Deliberate send error');
        expect(c.fieldErrors, {'body': 'Review this message'});
        final count = h.adapter.requests.length;
        final Future<void> duplicate = c.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(h.adapter.requests, hasLength(count));
        final detail = fixture(feature, detailOp);
        detail['data']['send_allowed'] = true;
        h.reply = (_) => jsonReply(fixture(feature, historyOp));
        delayed.complete(jsonReply(detail));
        await Future.wait([refresh, duplicate]);
        expect(c.refreshing, isFalse);
        expect(c.loading, isFalse);
        expect(c.error, 'Deliberate send error');
        expect(c.fieldErrors, {'body': 'Review this message'});
        expect(c.draft, 'Safe synthetic draft');
      },
    );

    test(
      '$channel sign-out during background refresh cancels queued send',
      () async {
        final dynamic c = switch (channel) {
          'shop' => h.state.shopThread(id: customerId),
          'logistics' => h.state.logisticsThread(id: customerId),
          _ => h.state.courierThread(id: customerId),
        };
        h.reply = (r) {
          final body = fixture(
            feature,
            r.uri.path.endsWith('/messages') ? historyOp : detailOp,
          );
          if (!r.uri.path.endsWith('/messages')) {
            body['data']['send_allowed'] = true;
          }
          return jsonReply(body);
        };
        await c.load();
        c.draft = 'Synthetic outgoing message';
        final delayed = Completer<ResponseBody>();
        h.reply = (_) => delayed.future;
        final Future<void> refresh = c.refresh();
        await Future<void>.delayed(Duration.zero);
        final Future<void> send = c.send();
        await h.session.signOut();
        delayed.complete(jsonReply(fixture(feature, detailOp)));
        await Future.wait([refresh, send]);
        expect(c.messages, isEmpty);
        expect(c.draft, isEmpty);
        expect(c.refreshing, isFalse);
        expect(h.adapter.requests.where((r) => r.method == 'POST'), isEmpty);
      },
    );
  }

  testWidgets(
    'visible thread receives replies without refresh and keeps draft and focus',
    (tester) async {
      var count = 1;
      h.reply = (r) {
        if (r.uri.path.endsWith('/messages')) {
          final body = fixture('chat-messaging', 'op-060');
          final row = (body['items'] as List).single as Map<String, dynamic>;
          body['items'] = [
            for (var i = 1; i <= count; i++)
              {
                ...row,
                'id':
                    '${i.toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
                'sequence': i,
                'body': 'Incoming synthetic reply $i',
                'mine': false,
              },
          ];
          return jsonReply(body);
        }
        final body = fixture(
          'chat-messaging',
          r.uri.path.endsWith('/read') ? 'op-062' : 'op-059',
        );
        body['data']['send_allowed'] = true;
        body['data']['last_sequence'] = count;
        body['data']['last_read_sequence'] = count;
        return jsonReply(body);
      };
      final c = h.state.shopThread(id: customerId);
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: ShopThreadScreen(dependencies: h.dependencies(), controller: c),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Retain draft');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
      count = 2;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(c.messages, hasLength(2));
      expect(find.text('Incoming synthetic reply 2'), findsOneWidget);
      expect(c.draft, 'Retain draft');
      expect(field.focusNode!.hasFocus, isTrue);
      expect(
        h.adapter.requests.where(
          (r) => r.method == 'POST' && !r.uri.path.endsWith('/read'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'offline thread reconnects automatically after bounded read probe',
    (tester) async {
      var offline = true;
      h.reply = (r) {
        if (offline) {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
          );
        }
        return h.defaultReply(r);
      };
      final c = h.state.shopThread(id: customerId);
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: ShopThreadScreen(dependencies: h.dependencies(), controller: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.offline, isTrue);
      // The initial timer was scheduled before the first read discovered offline.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final before = h.adapter.requests
          .where(
            (r) => r.uri.path == '/api/v1/customer/conversations/$customerId',
          )
          .length;
      offline = false;
      await tester.pump(const Duration(seconds: 25));
      expect(
        h.adapter.requests.where(
          (r) => r.uri.path == '/api/v1/customer/conversations/$customerId',
        ),
        hasLength(before),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(c.offline, isFalse);
      expect(c.messages, isNotEmpty);
      expect(
        h.adapter.requests.where(
          (r) => r.method == 'POST' && !r.uri.path.endsWith('/read'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
