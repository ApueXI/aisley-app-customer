import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/config/app_config.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';

import '../support/fakes.dart';

void main() {
  group(
    'Phase 2 localhost public and denial scope',
    () {
      late ApiClient api;
      late SessionController session;
      late DiscoveryRepository discovery;
      setUp(() async {
        api = ApiClient(
          AppConfig(
            apiBaseUrl: 'http://127.0.0.1:8000',
            storefrontOrigin: 'http://localhost:3000',
            allowLocalHttp: true,
          ),
        );
        session = SessionController(
          FakeAuth(),
          FakePolicies(),
          MemoryTokenStore(),
        );
        await session.bootstrap();
        discovery = DiscoveryRepository(api: api, session: session);
      });
      tearDown(() {
        discovery.dispose();
        session.dispose();
        api.close();
      });
      test(
        'public Home and cursor recommendations match typed contracts',
        () async {
          final home = await discovery.home();
          expect(home.viewer.isAuthenticated, isFalse);
          expect(home.viewer.email, isNull);
          expect(home.recentlyViewed, isEmpty);
          final page = await discovery.recommendations(
            cursor: home.recommendations.nextCursor,
          );
          expect(page.items, isA<List>());
        },
      );
      test(
        'both search modes and Shop directory/category filters remain public',
        () async {
          final products = await discovery.searchProducts(query: 'shirt');
          final shops = await discovery.searchShops(query: 'shop');
          expect(products.pagination.perPage, 20);
          expect(shops.pagination.perPage, 20);
          final directory = await discovery.shops();
          expect(directory.pagination.perPage, 20);
          if (directory.categories.isNotEmpty) {
            await discovery.shops(category: directory.categories.first.slug);
          }
          if (directory.items.isNotEmpty) {
            final slug = directory.items.first.slug;
            final detail = await discovery.shop(slug);
            expect(detail.slug, slug);
            final page = await discovery.shopProducts(
              slug: slug,
              query: 'shirt',
            );
            expect(page.shop.id, detail.id);
            if (page.categories.isNotEmpty) {
              await discovery.shopProducts(
                slug: slug,
                category: page.categories.first.slug,
              );
            }
          }
        },
      );
      test(
        'visible public Product detail and resolver use documented envelopes',
        () async {
          final home = await discovery.home();
          final products = [...home.recommendations.items, ...home.topProducts];
          if (products.isEmpty) {
            final result = await discovery.searchProducts(query: 'a');
            products.addAll(result.items);
          }
          if (products.isEmpty) {
            markTestSkipped(
              'No public Product available for detail acceptance.',
            );
            return;
          }
          final detail = await discovery.product(products.first.id);
          expect(detail.id, products.first.id);
          final resolved = await RecentlyViewedRepository(api)
              .resolve([detail.id]);
          expect(resolved.any((item) => item.id == detail.id), isTrue);
        },
      );
      for (final path in [
        'customer/account',
        'customer/addresses',
        'customer/wishlist',
        'customer/recently-viewed',
        'customer/account/profile-photo',
      ]) {
        test('unauthenticated $path remains denied', () async {
          await expectLater(
            api.request('GET', path),
            throwsA(
              isA<ApiFailure>().having(
                (failure) => failure.status,
                'status',
                401,
              ),
            ),
          );
        });
      }
    },
    skip: Platform.environment['BUYER_LIVE_API'] == '1'
        ? false
        : 'Opt in for existing localhost public/denial API.',
  );
}
