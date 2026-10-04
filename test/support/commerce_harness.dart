import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/commerce_state.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_repository.dart';
import 'package:aisley_mobile_buyer/features/cart/data/cart_repository.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/checkout_repository.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_repository.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/saved_status_controller.dart';

import 'fakes.dart';

Map<String, dynamic> clone(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class CommerceHarness {
  final auth = FakeAuth(), policies = FakePolicies();
  late SessionController session;
  late ApiClient api;
  late FakeAdapter adapter;
  late CommerceState commerce;
  Reply? reply;
  DateTime now = DateTime.utc(2026, 10, 3);
  int keys = 0;
  Map<String, dynamic> cartJson = fixture('view-cart', 'op-025');
  Map<String, dynamic> orderJson = fixture('order-status', 'op-033');
  Future<void> initialize({bool active = true}) async {
    session = SessionController(
      auth,
      policies,
      MemoryTokenStore()..token = active ? 'synthetic-token' : null,
    );
    await session.bootstrap();
    adapter = FakeAdapter(
      (options) => reply == null ? defaultReply(options) : reply!(options),
    );
    api = ApiClient(
      testConfig,
      publicClient: Dio()..httpClientAdapter = adapter,
      privateClient: Dio()..httpClientAdapter = adapter,
      readBackoff: Duration.zero,
      deadline: const Duration(milliseconds: 500),
    );
    commerce = CommerceState(
      session: session,
      carts: CartRepository(api),
      checkoutRepository: CheckoutRepository(api),
      addresses: AddressRepository(api),
      orders: OrderRepository(api),
      clock: () => now,
      uuid: () =>
          '${(++keys).toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
    );
    await Future<void>.delayed(Duration.zero);
    while (commerce.cart.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  FutureOr<ResponseBody> defaultReply(RequestOptions options) {
    final path = options.uri.path;
    if (path.contains('/cart')) return jsonReply(cartJson);
    if (path.endsWith('/addresses')) {
      return jsonReply(fixture('address-book', 'op-015'));
    }
    if (path.endsWith('/checkout/quote')) {
      return jsonReply(quoteFor(options.data as Map<String, dynamic>));
    }
    if (path.contains('/checkout/')) {
      return jsonReply(fixture('checkout-order', 'op-030'));
    }
    if (path.endsWith('/orders')) {
      return jsonReply(fixture('order-status', 'op-032'));
    }
    if (path.endsWith('/tracking')) {
      return jsonReply(fixture('order-status', 'op-034'));
    }
    if (path.endsWith('/cancel')) {
      final value = clone(orderJson);
      value['data']['status'] = 'cancelled';
      return jsonReply(value);
    }
    if (path.endsWith('/modification')) {
      final value = clone(orderJson);
      value['data']['deliveryAddress']['version'] = 2;
      return jsonReply(value);
    }
    if (path.contains('/orders/')) return jsonReply(orderJson);
    if (path == '/api/v1/products/$customerId') {
      return jsonReply(fixture('view-product', 'op-024'));
    }
    if (path.endsWith('/wishlist/status')) {
      return jsonReply({
        'data': {customerId: false},
      });
    }
    return jsonReply({}, status: 404);
  }

  Map<String, dynamic> quoteFor(Map<String, dynamic> input) {
    final value = fixture('checkout-order', 'op-029');
    final data = value['data'] as Map<String, dynamic>;
    data['mode'] = input['mode'];
    data['expiresAt'] = now.add(const Duration(minutes: 15)).toIso8601String();
    data['address']['id'] = input['address_id'];
    final item = data['groups'][0]['items'][0] as Map<String, dynamic>;
    if (input['mode'] == 'cart') {
      data['groups'][0]['items'] = [
        for (final id in input['cart_item_ids'] as List)
          {...item, 'cartItemId': id},
      ];
    } else {
      item['productId'] = input['buy_now']['product_id'];
      item['variantId'] = input['buy_now']['variant_id'];
      item['quantity'] = input['buy_now']['quantity'];
    }
    return value;
  }

  AppDependencies dependencies() => AppDependencies(
    config: testConfig,
    auth: auth,
    policies: policies,
    session: session,
    launcher: TrustedLauncher(testConfig),
    client: api,
    commerce: commerce,
    addresses: AddressRepository(api),
    discovery: DiscoveryRepository(api: api, session: session),
    recentlyViewed: RecentlyViewedRepository(api),
    savedStatus: SavedStatusController(session, WishlistRepository(api)),
    clock: () => now,
  );
  void dispose() {
    commerce.dispose();
    session.dispose();
    api.close();
  }
}
