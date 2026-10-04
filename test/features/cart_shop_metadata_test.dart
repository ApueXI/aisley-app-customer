import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/cart/data/cart_models.dart';
import 'package:aisley_mobile_buyer/features/cart/presentation/cart_shop_metadata.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/product_detail_model.dart';

import '../support/commerce_harness.dart';
import '../support/fakes.dart';

String productId(int n) =>
    '${n.toString().padLeft(8, '0')}-1111-4111-8111-111111111111';
CartLine line(int n) {
  final json = clone(fixture('view-cart', 'op-025')['data']['items'][0]);
  json['product']['id'] = productId(n);
  return CartLine.parse(json);
}

ProductDetail product(int n) {
  final json = clone(fixture('view-product', 'op-024')['data']);
  json['id'] = productId(n);
  return ProductDetail.parse(json);
}

void main() {
  test('metadata deduplicates products, limits reads to four and tolerates failure', () async {
    final h = CommerceHarness();
    await h.initialize();
    final pending = <String, Completer<ProductDetail>>{};
    final reads = <String>[];
    final metadata = CartShopMetadata(
      h.session,
      readProduct: (id) {
        reads.add(id);
        return (pending[id] = Completer<ProductDetail>()).future;
      },
    );
    addTearDown(() {
      metadata.dispose();
      h.dispose();
    });
    metadata.resolve([for (var n = 1; n <= 8; n++) line(n), line(1)]);
    expect(reads.length, 4);
    metadata.resolve([for (var n = 1; n <= 8; n++) line(n)]);
    expect(reads.length, 4);
    pending[productId(1)]!.complete(product(1));
    await Future<void>.delayed(Duration.zero);
    expect(reads.length, 5);
    pending[productId(2)]!.completeError(StateError('Synthetic unavailable'));
    await Future<void>.delayed(Duration.zero);
    expect(reads.length, 6);
    for (var n = 3; n <= 8; n++) {
      pending[productId(n)]!.complete(product(n));
      await Future<void>.delayed(Duration.zero);
    }
    expect(reads.toSet().length, 8);
    expect(metadata.shops.length, 7);
    expect(metadata.shops.containsKey(productId(2)), false);
    // Product metadata never edits the authoritative Cart or selection.
    expect(h.commerce.cart.selection, isEmpty);
    expect(h.commerce.cart.cart!.items.length, 1);
  });
  test(
    'removed lines and responses after identity loss cannot restore metadata',
    () async {
      final h = CommerceHarness();
      await h.initialize();
      final pending = <String, Completer<ProductDetail>>{};
      final metadata = CartShopMetadata(
        h.session,
        readProduct: (id) => (pending[id] = Completer<ProductDetail>()).future,
      );
      addTearDown(() {
        metadata.dispose();
        h.dispose();
      });
      metadata.resolve([line(1), line(2)]);
      metadata.resolve([line(2)]);
      pending[productId(1)]!.complete(product(1));
      await Future<void>.delayed(Duration.zero);
      expect(metadata.shops, isEmpty);
      await h.session.signOut();
      pending[productId(2)]!.complete(product(2));
      await Future<void>.delayed(Duration.zero);
      expect(metadata.shops, isEmpty);
    },
  );
}
