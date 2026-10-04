import '../../../core/commerce/commerce_value.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/wire.dart';

class BuyerCart {
  BuyerCart.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    itemCount = nonnegative(w, 'itemCount');
    distinctItemCount = nonnegative(w, 'distinctItemCount');
    subtotal = w.number('subtotal');
    availableSubtotal = w.number('availableSubtotal');
    items = w.list('items', CartLine.parse);
    if (distinctItemCount != items.length ||
        items.map((line) => line.id).toSet().length != items.length ||
        items.fold<int>(0, (sum, line) => sum + line.quantity) != itemCount) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final String id;
  late final int itemCount, distinctItemCount;
  late final double subtotal, availableSubtotal;
  late final List<CartLine> items;
}

class CartLine {
  CartLine.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    quantity = w.positiveInt('quantity');
    unitPrice = w.number('unitPrice');
    subtotal = w.number('lineSubtotal');
    final product = Wire(w.object('product'));
    productId = product.uuid('id');
    productName = product.string('name');
    productSlug = product.string('slug');
    productUrl = product.string('url');
    final rawVariant = w.field('variant');
    final variant = rawVariant == null ? null : Wire(rawVariant);
    variantId = variant?.uuid('id');
    sku = variant?.nullableString('sku');
    options = w.list('selectedOptions', SelectedOption.parse);
    final media = Wire(w.object('media'));
    mediaUrl = media.nullableString('url');
    altText = media.string('altText');
    final availability = Wire(w.object('availability'));
    isAvailable = availability.boolean('isAvailable');
    reason = availability.nullableString('reason');
    availableQuantity = nonnegative(availability, 'availableQuantity');
  }
  late final String id,
      productId,
      productName,
      productSlug,
      productUrl,
      altText;
  late final String? variantId, sku, mediaUrl, reason;
  late final int quantity, availableQuantity;
  late final double unitPrice, subtotal;
  late final bool isAvailable;
  late final List<SelectedOption> options;

  bool get selectable =>
      isAvailable && reason == null && availableQuantity >= quantity;
  String get availabilityLabel => switch (reason) {
    'product_unavailable' =>
      'Product is unavailable. Remove it or check the Product.',
    'variant_unavailable' =>
      'This variant is unavailable. Choose another variant.',
    'out_of_stock' => 'Out of stock.',
    'insufficient_stock' =>
      'Only $availableQuantity available. Reduce the quantity.',
    null when selectable => '$availableQuantity available',
    _ => 'Currently unavailable for checkout.',
  };
}
