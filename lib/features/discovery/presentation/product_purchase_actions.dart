import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/security/session_controller.dart';
import '../../checkout/domain/checkout_intent.dart';
import 'product_controller.dart';

class ProductPurchaseActions extends StatelessWidget {
  const ProductPurchaseActions({
    super.key,
    required this.dependencies,
    required this.product,
  });
  final AppDependencies dependencies;
  final ProductDetailController product;
  @override
  Widget build(BuildContext context) {
    final commerce = dependencies.commerce;
    if (commerce == null) return const Text('Purchasing is unavailable.');
    return ListenableBuilder(
      listenable: Listenable.merge([
        commerce.cart,
        commerce.checkout,
        dependencies.session,
      ]),
      builder: (context, _) {
        final cart = commerce.cart, checkout = commerce.checkout;
        final available =
            product.available &&
            product.quantity > 0 &&
            product.product?.shop.isOnVacation != true &&
            !product.loading;
        final busy = cart.writing || cart.loading || checkout.placing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cart.error != null && dependencies.session.active)
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
                  ? () async {
                      if (!_authorized(context)) return;
                      final success = await cart.add(
                        product.productId,
                        product.selectedVariant?.id,
                        product.quantity,
                      );
                      if (context.mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Added to Cart')),
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(cart.writing ? 'Adding…' : 'Add to Cart'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed:
                  available &&
                      !busy &&
                      checkout.pending == null &&
                      !checkout.coolingDown
                  ? () {
                      if (!_authorized(context)) return;
                      if (checkout.begin(
                        CheckoutIntent.buyNow(
                          BuyNowItem(
                            product.productId,
                            product.selectedVariant?.id,
                            product.quantity,
                          ),
                        ),
                      )) {
                        context.push('/checkout');
                      }
                    }
                  : null,
              child: const Text('Buy Now'),
            ),
          ],
        );
      },
    );
  }

  bool _authorized(BuildContext context) {
    if (dependencies.session.active) return true;
    final screen = switch (dependencies.session.phase) {
      SessionPhase.signedOut || SessionPhase.accountDenied => '/login',
      SessionPhase.consentRequired => '/consent',
      _ => '/session',
    };
    context.push(
      '$screen?returnTo=${Uri.encodeComponent('/products/${product.productId}')}',
    );
    return false;
  }
}
