import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_repository.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/address_controller.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/saved_products_controller.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/saved_status_controller.dart';

import '../support/fakes.dart';
import 'phase_2_contract_test.dart' show addressInput;

void main() {
  late SessionController session;
  setUp(() async {
    session = SessionController(
      FakeAuth(),
      FakePolicies(),
      MemoryTokenStore()..token = 'synthetic-token',
    );
    await session.bootstrap();
  });
  tearDown(() => session.dispose());
  ApiClient api(FakeAdapter adapter) {
    final value = ApiClient(
      testConfig,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(value.close);
    return value;
  }

  test('confirmed address creation refetches server-owned defaults and delete refetches the list', () async {
    final adapter = FakeAdapter(
      (options) => options.method == 'DELETE'
          ? ResponseBody.fromString('', 204)
          : jsonReply(
              fixture(
                'address-book',
                options.method == 'POST' ? 'op-016' : 'op-015',
              ),
              status: options.method == 'POST' ? 201 : 200,
            ),
    );
    final controller = AddressController(
      session,
      AddressRepository(api(adapter)),
    );
    addTearDown(controller.dispose);
    expect(await controller.save(addressInput), isTrue);
    expect(adapter.requests.map((options) => options.method), ['POST', 'GET']);
    expect(controller.addresses, isNotEmpty);
    expect(await controller.delete(controller.addresses.first.id), isTrue);
    expect(adapter.requests.map((options) => options.method), [
      'POST',
      'GET',
      'DELETE',
      'GET',
    ]);
  });
  test('uncertain address create reconciles without retry and blocks another write pending review', () async {
    final adapter = FakeAdapter(
      (options) => jsonReply(
        options.method == 'POST' ? {} : fixture('address-book', 'op-015'),
        status: options.method == 'POST' ? 503 : 200,
      ),
    );
    final controller = AddressController(
      session,
      AddressRepository(api(adapter)),
    );
    addTearDown(controller.dispose);
    expect(await controller.save(addressInput), isFalse);
    expect(controller.requiresReconciliation, isTrue);
    expect(controller.reconciliationAvailable, isTrue);
    expect(await controller.save(addressInput), isFalse);
    expect(adapter.requests.map((options) => options.method), ['POST', 'GET']);
  });
  test('owned Wishlist cursor pages deduplicate and clear immediately when identity is lost', () async {
    final adapter = FakeAdapter((options) {
      final body = fixture('wishlist', 'op-037');
      body['meta']['next_cursor'] =
          options.uri.queryParameters['cursor'] == null ? 'opaque-next' : null;
      return jsonReply(body);
    });
    final client = api(adapter), wishlist = WishlistRepository(api(adapter));
    final saved = SavedStatusController(session, wishlist);
    addTearDown(saved.dispose);
    final controller = SavedProductsController(
      session,
      collection: SavedCollection.wishlist,
      wishlist: wishlist,
      recent: RecentlyViewedRepository(client),
      savedStatus: saved,
    );
    addTearDown(controller.dispose);
    await controller.load();
    final length = controller.items.length;
    await controller.load(more: true);
    expect(controller.items.length, length);
    expect(controller.nextCursor, isNull);
    expect(adapter.requests.last.uri.queryParameters['cursor'], 'opaque-next');
    await session.signOut();
    expect(controller.items, isEmpty);
    expect(controller.nextCursor, isNull);
  });
}
