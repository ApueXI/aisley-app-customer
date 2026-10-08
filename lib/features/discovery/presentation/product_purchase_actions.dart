import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import 'product_controller.dart';
import 'product_purchase_flow.dart';

class ProductPurchaseActions extends StatefulWidget {
  const ProductPurchaseActions({
    super.key,
    required this.dependencies,
    required this.product,
  });
  final AppDependencies dependencies;
  final ProductDetailController product;

  @override
  State<ProductPurchaseActions> createState() => _ProductPurchaseActionsState();
}

class _ProductPurchaseActionsState extends State<ProductPurchaseActions> {
  bool _preparing = false;

  @override
  Widget build(BuildContext context) {
    final commerce = widget.dependencies.commerce;
    if (commerce == null) return const Text('Purchasing is unavailable.');
    return ListenableBuilder(
      listenable: Listenable.merge([
        commerce.cart,
        commerce.checkout,
        widget.dependencies.session,
      ]),
      builder: (context, _) {
        final cart = commerce.cart, checkout = commerce.checkout;
        final currentProduct = widget.product.product;
        final available =
            currentProduct != null &&
            currentProduct.shop.isOnVacation != true &&
            !widget.product.loading;
        final busy =
            _preparing || cart.writing || cart.loading || checkout.placing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cart.error != null && widget.dependencies.session.active)
              Semantics(liveRegion: true, child: Text(cart.error!)),
            if (cart.uncertain) ...[
              const Text('The Cart needs to be checked before adding again.'),
              TextButton(
                onPressed: busy || cart.coolingDown ? null : cart.load,
                child: const Text('Check Cart'),
              ),
            ],
            if (checkout.pending != null)
              TextButton(
                onPressed: () => context.push('/checkout'),
                child: const Text('Check unresolved placement'),
              ),
            FilledButton.icon(
              onPressed:
                  available &&
                      !busy &&
                      !cart.coolingDown &&
                      !cart.uncertain &&
                      checkout.pending == null
                  ? () => _purchase(ProductPurchaseAction.addToCart)
                  : null,
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(busy && cart.writing ? 'Adding…' : 'Add to Cart'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed:
                  available &&
                      !busy &&
                      checkout.pending == null &&
                      !checkout.coolingDown
                  ? () => _purchase(ProductPurchaseAction.buyNow)
                  : null,
              child: Text(busy && _preparing ? 'Checking Product…' : 'Buy Now'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _purchase(ProductPurchaseAction action) async {
    if (_preparing) return;
    setState(() => _preparing = true);
    try {
      await beginProductPurchase(
        context: context,
        dependencies: widget.dependencies,
        productId: widget.product.productId,
        action: action,
        variantId: widget.product.selectedVariant?.id,
        quantity: widget.product.quantity,
      );
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }
}
