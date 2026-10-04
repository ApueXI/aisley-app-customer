import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../../checkout/domain/checkout_intent.dart';
import '../data/cart_models.dart';
import 'cart_line_editor.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    widget.dependencies.commerce!.cart.load();
  }

  @override
  Widget build(BuildContext context) {
    final commerce = widget.dependencies.commerce!, cart = commerce.cart;
    return ListenableBuilder(
      listenable: Listenable.merge([cart, commerce.checkout]),
      builder: (context, _) {
        if (!widget.dependencies.session.active) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Your Cart', style: Theme.of(context).textTheme.headlineSmall),
            TextButton.icon(
              onPressed: cart.loading || cart.writing || cart.coolingDown
                  ? null
                  : cart.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Cart'),
            ),
            if (cart.loading || cart.writing)
              const LinearProgressIndicator(semanticsLabel: 'Updating Cart'),
            if (cart.stale && cart.cart != null)
              const Text(
                'Saved view is stale. Refresh before changing or checking out.',
              ),
            if (cart.error != null)
              Semantics(liveRegion: true, child: Text(cart.error!)),
            if (commerce.checkout.pending != null) ...[
              const Text(
                'A placement is unresolved. Return to checkout to check its outcome.',
              ),
              TextButton(
                onPressed: () => context.push('/checkout'),
                child: const Text('Return to checkout'),
              ),
            ],
            if (cart.cart != null)
              Text(
                '${cart.cart!.itemCount} items · ${cart.cart!.distinctItemCount} configurations',
              ),
            if (cart.cart?.items.isEmpty == true && !cart.loading)
              const Text('Your Cart is empty. Browse Products to add items.'),
            for (final line in cart.cart?.items ?? <CartLine>[]) _line(line),
            const SizedBox(height: 16),
            const Text(
              'Prices shown in Cart are estimates. Checkout provides the current shipping, discounts and COD total.',
            ),
            FilledButton(
              onPressed: cart.canEdit && cart.selection.isNotEmpty
                  ? () {
                      if (commerce.checkout.begin(
                        CheckoutIntent.cart(cart.selection),
                      )) {
                        context.push('/checkout');
                      }
                    }
                  : null,
              child: Text('Checkout selected (${cart.selection.length})'),
            ),
          ],
        );
      },
    );
  }

  Widget _line(CartLine line) {
    final cart = widget.dependencies.commerce!.cart;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.productName),
              value: cart.selection.contains(line.id),
              onChanged: cart.canEdit && line.selectable
                  ? (value) => cart.select(line.id, value == true)
                  : null,
            ),
            Text(
              line.options
                  .map((option) => '${option.group}: ${option.value}')
                  .join(', '),
            ),
            Text(
              'Quantity ${line.quantity} · ₱${line.unitPrice.toStringAsFixed(2)} each · ₱${line.subtotal.toStringAsFixed(2)}',
            ),
            Text(line.availabilityLabel),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    await context.push('/products/${line.productId}');
                    if (mounted) await cart.load();
                  },
                  child: const Text('View Product'),
                ),
                TextButton(
                  onPressed: cart.canEdit
                      ? () => showDialog<void>(
                          context: context,
                          builder: (_) => CartLineEditor(
                            dependencies: widget.dependencies,
                            line: line,
                          ),
                        )
                      : null,
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: cart.canEdit
                      ? () async {
                          if (await confirmAction(
                            context,
                            title: 'Remove item?',
                            message:
                                'Remove ${line.productName} from your Cart?',
                            action: 'Remove',
                          )) {
                            await cart.remove(line.id);
                          }
                        }
                      : null,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
