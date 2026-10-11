import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/home_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/search_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/shop_controllers.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';

import '../support/communication_harness.dart';
import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CommunicationHarness h;
  late DiscoveryRepository repo;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
    repo = DiscoveryRepository(api: h.api, session: h.session);
  });
  tearDown(() {
    repo.dispose();
    h.dispose();
  });

  for (final name in ['products', 'shops', 'directory', 'shop']) {
    group(name, () {
      late dynamic c;
      late Future<void> Function(int, bool) load;
      dynamic result() => switch (name) {
        'products' => c.products,
        'shops' => c.shops,
        _ => c.result,
      };
      Map<String, dynamic> body(int page, {bool empty = false}) {
        final (feature, op) = switch (name) {
          'products' => ('search', 'op-019'),
          'shops' => ('search', 'op-020'),
          'directory' => ('browse-shop', 'op-021'),
          _ => ('browse-shop', 'op-022'),
        };
        final value = fixture(feature, op);
        value['pagination']['currentPage'] = page;
        value['pagination']['lastPage'] = 3;
        if (empty) value['items'] = [];
        return value;
      }

      setUp(() {
        switch (name) {
          case 'products':
          case 'shops':
            final search = DiscoverySearchController(repo);
            if (name == 'shops') search.setMode(SearchMode.shops);
            c = search;
            load = (page, refresh) =>
                search.search('example', page: page, refresh: refresh);
          case 'directory':
            final directory = ShopDirectoryController(repo);
            c = directory;
            load = (page, refresh) {
              directory.page = page;
              return directory.load(refresh: refresh);
            };
          default:
            final shop = ShopBrowseController(
              repo,
              slug: 'example',
              query: '',
              category: null,
              page: 1,
            );
            c = shop;
            load = (page, refresh) {
              shop.page = page;
              return shop.load(refresh: refresh);
            };
        }
        h.reply = (o) => jsonReply(
          o.uri.path.endsWith('/shops/example')
              ? fixture('browse-shop', 'op-023')
              : body(int.parse(o.uri.queryParameters['page'] ?? '1')),
        );
        addTearDown(c.dispose as void Function());
      });
      test(
        'failed target preserves previous page and retry bypasses cache',
        () async {
          await load(1, false);
          expect(result(), isNotNull);
          final original = result();
          h.reply = (_) => jsonReply({}, status: 503);
          await load(2, false);
          expect(result(), same(original));
          expect(result().pagination.currentPage, 1);
          expect(c.error, isNotNull);
          expect(c.stale, true);
          h.reply = (o) => jsonReply(
            o.uri.path.endsWith('/shops/example')
                ? fixture('browse-shop', 'op-023')
                : body(2),
          );
          await c.retry();
          expect(result().pagination.currentPage, 2);
          expect(c.error, isNull);
          expect(c.stale, false);
          h.reply = (o) => jsonReply(
            o.uri.path.endsWith('/shops/example')
                ? fixture('browse-shop', 'op-023')
                : body(2, empty: true),
          );
          await c.retry();
          expect(result().items, isEmpty);
        },
      );
      test(
        'deduplicates initial rows and rejects malformed replacement',
        () async {
          h.reply = (o) {
            if (o.uri.path.endsWith('/shops/example')) {
              return jsonReply(fixture('browse-shop', 'op-023'));
            }
            final value = body(1);
            value['items'] = [value['items'][0], value['items'][0]];
            return jsonReply(value);
          };
          await load(1, false);
          expect(result().items.length, 1);
          h.reply = (_) => jsonReply({});
          await c.retry();
          expect(result().items.length, 1);
          expect(c.error, isNotNull);
        },
      );
      test(
        'late public response cannot restore a signed-out controller',
        () async {
          await load(1, false);
          final delayed = Completer<ResponseBody>();
          h.reply = (_) => delayed.future;
          final pending = load(2, false);
          await Future<void>.delayed(Duration.zero);
          await h.session.signOut();
          delayed.complete(jsonReply(body(2)));
          await pending;
          expect(result(), isNull);
          expect(c.error, isNull);
          expect(c.loading, false);
        },
      );
      test('denial clears retained rows', () async {
        await load(1, false);
        h.reply = (_) => jsonReply({}, status: 404);
        await c.retry();
        expect(result(), isNull);
        expect(c.error, isNotNull);
      });
    });
  }

  test(
    'Home keeps stale overview and ignores page completing after refresh',
    () async {
      final home = fixture('customer-homepage', 'op-047');
      home['recommendations']['nextCursor'] = 'next';
      final c = HomeController(
        discovery: repo,
        session: h.session,
        recentlyViewed: RecentlyViewedRepository(h.api),
      );
      addTearDown(c.dispose);
      h.reply = (_) => jsonReply(home);
      await c.load();
      final previous = c.home;
      h.reply = (_) => jsonReply({}, status: 503);
      await c.load(refresh: true);
      expect(c.home, same(previous));
      expect(c.stale, true);
      final requests = h.adapter.requests.length;
      await c.loadMore();
      expect(h.adapter.requests.length, requests);
      h.reply = (_) => jsonReply(home);
      await c.load(refresh: true);
      final delayed = Completer<ResponseBody>();
      h.reply = (_) => delayed.future;
      final pending = c.loadMore();
      await Future<void>.delayed(Duration.zero);
      final empty = fixture('customer-homepage', 'op-047');
      empty['recommendations']['items'] = [];
      empty['recommendations']['nextCursor'] = null;
      h.reply = (_) => jsonReply(empty);
      await c.load(refresh: true);
      delayed.complete(jsonReply({'recommendations': home['recommendations']}));
      await pending;
      expect(c.recommendations, isEmpty);
      expect(c.cursor, isNull);
      expect(c.loadingMore, false);
      expect(c.stale, false);
    },
  );

  test(
    'late public cache write cannot overwrite newer explicit refresh',
    () async {
      final delayed = Completer<ResponseBody>();
      h.reply = (_) => delayed.future;
      final pending = repo.searchProducts(query: 'example');
      await Future<void>.delayed(Duration.zero);
      final fresh = fixture('search', 'op-019');
      fresh['items'] = [];
      h.reply = (_) => jsonReply(fresh);
      await repo.searchProducts(query: 'example', refresh: true);
      delayed.complete(jsonReply(fixture('search', 'op-019')));
      await pending;
      expect((await repo.searchProducts(query: 'example')).items, isEmpty);
    },
  );
}
