import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/security/session_controller.dart';
import '../../checkout/domain/checkout_intent.dart';
import 'product_choices.dart';
import 'product_controller.dart';

enum ProductPurchaseAction { addToCart, buyNow }

final Set<String> _purchaseFlights = {};

Future<void> beginProductPurchase({
  required BuildContext context,
  required AppDependencies dependencies,
  required String productId,
  required ProductPurchaseAction action,
  String? variantId,
  int quantity = 1,
}) async {
  final session = dependencies.session;
  final flightKey =
      '${session.generation}:${session.customer?.id}:$productId:${action.name}';
  if (!_purchaseFlights.add(flightKey)) return;
  try {
    await _runProductPurchase(
      context: context,
      dependencies: dependencies,
      productId: productId,
      action: action,
      variantId: variantId,
      quantity: quantity,
    );
  } finally {
    _purchaseFlights.remove(flightKey);
  }
}

Future<void> _runProductPurchase({
  required BuildContext context,
  required AppDependencies dependencies,
  required String productId,
  required ProductPurchaseAction action,
  String? variantId,
  required int quantity,
}) async {
  final session = dependencies.session;
  if (!session.active) {
    final route = switch (session.phase) {
      SessionPhase.signedOut || SessionPhase.accountDenied => '/login',
      SessionPhase.consentRequired => '/consent',
      _ => '/session',
    };
    context.push(
      '$route?returnTo=${Uri.encodeComponent('/products/$productId')}',
    );
    return;
  }
  final commerce = dependencies.commerce;
  final discovery = dependencies.discovery;
  if (commerce == null || discovery == null) {
    _message(context, 'Purchasing is unavailable.');
    return;
  }
  final cart = commerce.cart;
  final checkout = commerce.checkout;
  if (cart.uncertain) {
    _message(context, 'Check your Cart before adding another item.');
    return;
  }
  if (cart.loading ||
      cart.writing ||
      cart.coolingDown ||
      checkout.placing ||
      checkout.coolingDown ||
      checkout.pending != null) {
    _message(context, 'Finish the current Cart or checkout action first.');
    return;
  }

  final controller = ProductDetailController(discovery, productId);
  try {
    await controller.load();
    if (!context.mounted) return;
    final product = controller.product;
    if (product == null) {
      _message(
        context,
        controller.error ?? 'Current Product details are unavailable.',
      );
      return;
    }
    controller.chooseVariantId(variantId);
    controller.setQuantity(quantity < 1 ? 1 : quantity);
    if (product.shop.isOnVacation) {
      _message(
        context,
        product.shop.vacationMessage ?? 'This Shop is on vacation.',
      );
      return;
    }

    if (product.availability.requiresVariantSelection) {
      if (product.optionGroups.isEmpty || product.variants.isEmpty) {
        _message(context, 'Product options are currently unavailable.');
        return;
      }
      final confirmed = await _chooseVariant(
        context,
        controller: controller,
        action: action,
      );
      if (confirmed != true || !context.mounted) return;
    }

    if (!controller.canPurchaseQuantity) {
      final stock = controller.availableStock;
      _message(
        context,
        stock == 0
            ? 'This option is out of stock.'
            : 'Choose an available option and a quantity within current stock.',
      );
      return;
    }
    final selectedVariant = controller.selectedVariant;
    if (action == ProductPurchaseAction.addToCart) {
      final added = await cart.add(
        productId,
        selectedVariant?.id,
        controller.quantity,
      );
      if (!context.mounted) return;
      if (added) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Added to Cart')));
      } else {
        _message(context, cart.error ?? 'Could not update your Cart.');
      }
      return;
    }

    if (checkout.begin(
      CheckoutIntent.buyNow(
        BuyNowItem(productId, selectedVariant?.id, controller.quantity),
      ),
    )) {
      context.push('/checkout');
    } else if (context.mounted) {
      _message(
        context,
        'Checkout is unavailable until the current action is resolved.',
      );
    }
  } finally {
    controller.dispose();
  }
}

Future<bool?> _chooseVariant(
  BuildContext context, {
  required ProductDetailController controller,
  required ProductPurchaseAction action,
}) {
  final narrow = MediaQuery.sizeOf(context).width < 600;
  if (narrow) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final height = (media.size.height - media.viewInsets.bottom - 24).clamp(
          320.0,
          720.0,
        );
        return SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: _VariantPicker(controller: controller, action: action),
          ),
        );
      },
    );
  }
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final height = (MediaQuery.sizeOf(context).height * .78).clamp(
        360.0,
        720.0,
      );
      return Dialog(
        child: SizedBox(
          width: 520,
          height: height,
          child: _VariantPicker(controller: controller, action: action),
        ),
      );
    },
  );
}

class _VariantPicker extends StatelessWidget {
  const _VariantPicker({required this.controller, required this.action});
  final ProductDetailController controller;
  final ProductPurchaseAction action;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final product = controller.product;
      if (product == null) return const SizedBox.shrink();
      final stock = controller.availableStock;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose Product options',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close options',
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              '₱${(controller.currentPrice ?? product.price).toStringAsFixed(2)}'
              '${stock == null ? '' : ' · $stock available'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: ProductChoices(product: product, controller: controller),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: controller.canPurchaseQuantity
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(
                    action == ProductPurchaseAction.addToCart
                        ? 'Add to Cart'
                        : 'Continue to checkout',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
