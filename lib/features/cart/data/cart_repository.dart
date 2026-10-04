import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';
import 'cart_models.dart';

class CartRepository {
  CartRepository(this.api);
  final ApiClient api;
  Future<BuyerCart> read(SessionLease lease) =>
      _request('GET', 'customer/cart', lease);
  Future<BuyerCart> add(
    SessionLease lease,
    String productId,
    String? variantId,
    int quantity,
  ) {
    _quantity(quantity);
    return _request(
      'POST',
      'customer/cart/items',
      lease,
      body: {
        'product_id': requireUuid(productId),
        'variant_id': variantId == null ? null : requireUuid(variantId),
        'quantity': quantity,
      },
    );
  }

  Future<BuyerCart> update(
    SessionLease lease,
    String id, {
    int? quantity,
    String? variantId,
    bool changeVariant = false,
  }) {
    if (quantity == null && !changeVariant) {
      throw const ApiFailure(FailureKind.decode);
    }
    if (quantity != null) _quantity(quantity);
    return _request(
      'PATCH',
      'customer/cart/items/${requireUuid(id)}',
      lease,
      body: {
        'quantity': ?quantity,
        if (changeVariant)
          'variant_id': variantId == null ? null : requireUuid(variantId),
      },
    );
  }

  Future<BuyerCart> remove(SessionLease lease, String id) =>
      _request('DELETE', 'customer/cart/items/${requireUuid(id)}', lease);
  Future<BuyerCart> _request(
    String method,
    String path,
    SessionLease lease, {
    Map<String, dynamic>? body,
  }) async => BuyerCart.parse(
    Wire(await api.request(method, path, lease: lease, body: body))
        .object('data'),
  );
  void _quantity(int value) {
    if (value < 1 || value > 2147483647) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
}
