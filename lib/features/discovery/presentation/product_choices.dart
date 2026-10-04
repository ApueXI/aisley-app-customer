import 'package:flutter/material.dart';

import '../data/product_detail_model.dart';
import 'product_controller.dart';

class ProductChoices extends StatelessWidget {
  const ProductChoices({
    super.key,
    required this.product,
    required this.controller,
  });
  final ProductDetail product;
  final ProductDetailController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (product.optionGroups.isNotEmpty) _options(product),
      const SizedBox(height: 12),
      _availability(product),
      _quantity(context, product),
    ],
  );
  Widget _options(ProductDetail product) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final group in product.optionGroups)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DropdownButtonFormField<String?>(
            initialValue: controller.selectedValues[group.id],
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(labelText: group.name),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Choose ${group.name}'),
              ),
              for (final value in group.values)
                DropdownMenuItem<String?>(
                  value: value.id,
                  enabled: controller.canChoose(group.id, value.id),
                  child: Text(value.value),
                ),
            ],
            onChanged: (value) {
              if (value != null) controller.choose(group.id, value);
            },
          ),
        ),
      if (controller.selectedValues.isNotEmpty)
        TextButton(
          onPressed: controller.resetChoices,
          child: const Text('Clear choices'),
        ),
    ],
  );

  Widget _availability(ProductDetail product) {
    if (controller.requiresVariantSelection && !controller.selectionValid) {
      return const Text('Choose one available option from each group.');
    }
    final variant = controller.selectedVariant;
    if (variant != null && !variant.inStock ||
        variant == null && !product.availability.inStock) {
      return const Text('Currently unavailable');
    }
    final stock = controller.availableStock;
    return Text(stock == null ? 'Available' : '$stock available');
  }

  Widget _quantity(BuildContext context, ProductDetail product) {
    final stock = controller.availableStock;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Quantity'),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Decrease quantity',
          onPressed: controller.quantity > 1 ? controller.decrement : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Semantics(
          label: 'Quantity ${controller.quantity}',
          child: Text('${controller.quantity}'),
        ),
        IconButton(
          tooltip: 'Increase quantity',
          onPressed:
              stock != null &&
                  controller.quantity < stock &&
                  controller.available
              ? controller.increment
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
