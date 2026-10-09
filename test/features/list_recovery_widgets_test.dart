import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/router.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/ui/list_recovery.dart';
import 'package:aisley_mobile_buyer/features/messaging/presentation/inbox_view.dart';

import '../support/commerce_harness.dart';
import '../support/communication_harness.dart';

import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_screens.dart';

import '../support/fakes.dart';

void main() {
  testWidgets(
    'retained inbox warns, suppresses empty success and disables page retry while stale',
    (tester) async {
      var refreshes = 0, pages = 0;
      Future<void> show({required bool empty, required bool stale}) =>
          tester.pumpWidget(
            MaterialApp(
              theme: buyerTheme(),
              home: MessageInboxView(
                title: 'Shop messages',
                rows: empty
                    ? []
                    : const [InboxRow('one', 'Shop A', null, 0, false)],
                loading: false,
                loaded: true,
                paging: false,
                more: true,
                stale: stale,
                error: stale ? 'Could not refresh.' : null,
                pageError: 'Could not load page.',
                refresh: () => refreshes++,
                loadMore: () => pages++,
                open: (_) {},
              ),
            ),
          );
      await show(empty: false, stale: true);
      expect(find.text('Shop A'), findsOneWidget);
      expect(
        find.textContaining('These results may be out of date'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry loading more'));
      expect(pages, 0);
      await tester.tap(find.text('Retry'));
      expect(refreshes, 1);
      await show(empty: true, stale: true);
      expect(find.textContaining('No conversations yet'), findsNothing);
      await show(empty: false, stale: false);
      await tester.tap(find.text('Retry loading more'));
      expect(pages, 1);
    },
  );

  testWidgets(
    'recovery actions fit narrow doubled text and expose 48px targets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(
                children: [
                  ListRecovery(
                    retry: () {},
                    retained: true,
                    requestedPage: 2,
                    displayedPage: 1,
                    error: 'Connection interrupted. Please try again.',
                  ),
                  ListPageAction(
                    load: () {},
                    hasMore: true,
                    error: 'More results are unavailable.',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text('Showing page 1. Could not load page 2.'),
        findsOneWidget,
      );
      for (final label in ['Retry page 2', 'Retry loading more']) {
        final button = find.widgetWithText(TextButton, label);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'focusing the inbox page action does not replace it with a first-page refresh',
    (tester) async {
      final h = CommunicationHarness();
      await tester.runAsync(h.initialize);
      final d = h.dependencies();
      addTearDown(d.dispose);
      final body = fixture('chat-messaging', 'op-057');
      body['next_cursor'] = 'next';
      final page = Completer<ResponseBody>();
      h.reply = (o) => o.uri.queryParameters['cursor'] == 'next'
          ? page.future
          : jsonReply(body);
      await tester.pumpWidget(
        MaterialApp(
          theme: buyerTheme(),
          home: ShopInboxScreen(dependencies: d),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.state.shopInbox.loading, false);
      expect(h.state.shopInbox.stale, false);
      expect(h.session.active, true);
      final start = h.adapter.requests.length;
      final action = find.widgetWithText(TextButton, 'Load more conversations');
      tester.widget<TextButton>(action).onPressed!();
      expect(h.state.shopInbox.paging, true);
      Focus.of(tester.element(find.text('Load more conversations')))
          .requestFocus();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      // Focus-triggered background refresh must not discard this deliberate page.
      expect(h.state.shopInbox.paging, true);
      expect(h.state.shopInbox.loading, false);
      page.complete(jsonReply({}, status: 422));
      await tester.pumpAndSettle();
      expect(find.text('Retry loading more'), findsOneWidget);
      expect(
        h.adapter.requests
            .skip(start)
            .map((r) => r.uri.queryParameters['cursor'])
            .toList(),
        ['next'],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final kind in ['search', 'directory', 'shop']) {
    testWidgets(
      '$kind route retains page one after page two failure and retries exact target',
      (tester) async {
        final h = CommerceHarness();
        await tester.runAsync(h.initialize);
        final d = h.dependencies();
        addTearDown(d.dispose);
        var failing = false;
        final pages = <String>[];
        h.reply = (o) {
          if (o.uri.path.endsWith('/shops/example')) {
            return jsonReply(fixture('browse-shop', 'op-023'));
          }
          if (o.uri.path.endsWith('/search') ||
              o.uri.path.endsWith('/shops') ||
              o.uri.path.endsWith('/products')) {
            final requested = o.uri.queryParameters['page'] ?? '1';
            pages.add(requested);
            if (failing) return jsonReply({}, status: 503);
            final value = fixture(
              kind == 'search' ? 'search' : 'browse-shop',
              kind == 'search'
                  ? 'op-019'
                  : kind == 'directory'
                  ? 'op-021'
                  : 'op-022',
            );
            value['pagination']['currentPage'] = int.parse(requested);
            value['pagination']['lastPage'] = 3;
            value['items'][0][kind == 'directory' ? 'name' : 'title'] =
                'Result page $requested';
            return jsonReply(value);
          }
          return h.defaultReply(o);
        };
        final router = buyerRouter(d);
        addTearDown(router.dispose);
        final base = kind == 'search'
            ? '/search?q=example&mode=products'
            : kind == 'directory'
            ? '/shops'
            : '/shops/example';
        router.go(base);
        await tester.pumpWidget(
          MaterialApp.router(theme: buyerTheme(), routerConfig: router),
        );
        await tester.pumpAndSettle();
        expect(find.text('Result page 1'), findsOneWidget);
        failing = true;
        router.replace('$base${base.contains('?') ? '&' : '?'}page=2');
        await tester.pumpAndSettle();
        expect(find.text('Result page 1'), findsOneWidget);
        expect(
          find.text('Showing page 1. Could not load page 2.'),
          findsOneWidget,
        );
        expect(
          router.routeInformationProvider.value.uri.queryParameters['page'],
          '2',
        );
        failing = false;
        await tester.ensureVisible(find.text('Retry page 2'));
        await tester.tap(find.text('Retry page 2'));
        await tester.pumpAndSettle();
        expect(pages.last, '2');
        expect(find.text('Result page 2'), findsOneWidget);
        expect(find.text('Result page 1'), findsNothing);
        // Returning from a detail route restores the successful list page.
        router.push('/policies/terms_of_service');
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Result page 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
