import 'dart:async';

import '../../../core/security/private_feature_controller.dart';
import '../../discovery/data/product_detail_model.dart';
import '../data/cart_models.dart';

class CartShop {
  const CartShop(this.id, this.name, this.slug);
  final String id, name, slug;
}

/// Optional display metadata. Never changes a Cart line's price or eligibility.
class CartShopMetadata extends PrivateFeatureController {
  CartShopMetadata(super.session, {required this.readProduct});
  final Future<ProductDetail> Function(String) readProduct;
  final _shops = <String, CartShop>{};
  final _attempted = <String>{};
  final _queue = <String>[];
  int _running = 0;
  Set<String> _wanted = {};
  Map<String, CartShop> get shops => Map.unmodifiable(_shops);

  void resolve(List<CartLine> lines) {
    if (currentLease == null || isDisposed) return;
    final ids = lines.map((line) => line.productId).toSet();
    _wanted = ids;
    _shops.removeWhere((id, _) => !ids.contains(id));
    _queue.removeWhere((id) => !ids.contains(id));
    for (final id in ids) {
      if (_attempted.add(id)) _queue.add(id);
    }
    _drain();
  }

  void _drain() {
    final lease = currentLease;
    if (lease == null || isDisposed) return;
    while (_running < 4 && _queue.isNotEmpty) {
      final id = _queue.removeAt(0);
      final generation = featureGeneration;
      _running++;
      unawaited(() async {
        try {
          final product = await readProduct(id);
          if (isCurrentEpoch(generation, lease) &&
              product.id == id &&
              _wanted.contains(id)) {
            _shops[id] = CartShop(
              product.shop.id,
              product.shop.name,
              product.shop.slug,
            );
            notifyListeners();
          }
        } catch (_) {
          // Lookup failure leaves the authoritative Cart usable and ungrouped.
        } finally {
          _running--;
          _drain();
        }
      }());
    }
  }

  @override
  void onClear() {
    _wanted.clear();
    _shops.clear();
    _attempted.clear();
    _queue.clear();
  }
}
