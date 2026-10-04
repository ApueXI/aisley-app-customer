import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../../checkout/domain/checkout_intent.dart';
import '../data/cart_models.dart';
import 'cart_item_row.dart';
import 'cart_shop_metadata.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final _metadata = CartShopMetadata(
    widget.dependencies.session,
    readProduct: (id) => widget.dependencies.discovery!.product(id),
  );
  @override
  void initState() {
    super.initState();
    widget.dependencies.commerce!.cart.addListener(_resolve);
    widget.dependencies.commerce!.cart.load();
    _resolve();
  }

  void _resolve() {
    final lines = widget.dependencies.commerce!.cart.cart?.items;
    if (lines != null && widget.dependencies.discovery != null) {
      _metadata.resolve(lines);
    } else if (lines == null) {
      _metadata.clearPrivate();
    }
  }

  @override
  void dispose() {
    widget.dependencies.commerce!.cart.removeListener(_resolve);
    _metadata.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commerce = widget.dependencies.commerce!, cart = commerce.cart;
    return ListenableBuilder(
      listenable: Listenable.merge([cart, commerce.checkout, _metadata]),
      builder: (context, _) {
        if (!widget.dependencies.session.active) return const SizedBox.shrink();
        final groups = <String?, List<CartLine>>{};
        for (final line in cart.cart?.items ?? <CartLine>[]) {
          (groups[_metadata.shops[line.productId]?.id] ??= []).add(line);
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: pagePadding(context),
                children: [
                  Text(
                    'Your Cart',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  TextButton.icon(
                    onPressed: cart.loading || cart.writing || cart.coolingDown
                        ? null
                        : cart.load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Cart'),
                  ),
                  if (cart.loading || cart.writing)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Updating Cart',
                    ),
                  if (cart.stale && cart.cart != null)
                    const Text(
                      'This Cart view needs a refresh before you continue.',
                    ),
                  if (cart.error != null)
                    Semantics(liveRegion: true, child: Text(cart.error!)),
                  if (commerce.checkout.pending != null) ...[
                    const Text(
                      'An order is unconfirmed. Check its outcome in checkout.',
                    ),
                    TextButton(
                      onPressed: () => context.push('/checkout'),
                      child: const Text('Return to checkout'),
                    ),
                  ],
                  if (cart.cart != null) Text('${cart.cart!.itemCount} items'),
                  if (cart.cart?.items.isEmpty == true && !cart.loading) ...[
                    const SizedBox(height: 24),
                    const Text('Your Cart is empty.'),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Browse Products'),
                    ),
                  ],
                  for (final group in groups.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: MarketSection(
                        title: group.key == null
                            ? 'Cart items'
                            : _metadata
                                  .shops[group.value.first.productId]!
                                  .name,
                        child: Column(
                          children: [
                            for (final line in group.value)
                              CartItemRow(
                                key: ValueKey(line.id),
                                line: line,
                                dependencies: widget.dependencies,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PurchaseBar(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Shipping and discounts are confirmed when you review your order.',
                  ),
                  const SizedBox(height: 8),
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
              ),
            ),
          ],
        );
      },
    );
  }
}
