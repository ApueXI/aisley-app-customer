import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../../../core/ui/marketplace_surfaces.dart';
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
    final cart = widget.dependencies.commerce!.cart;
    cart.addListener(_resolve);
    _resolve();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cart.load();
    });
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
        final selectedLines = (cart.cart?.items ?? <CartLine>[])
            .where(
              (line) => line.selectable && cart.selection.contains(line.id),
            )
            .toList(growable: false);
        final eligibleCount =
            cart.cart?.items.where((line) => line.selectable).length ?? 0;
        final selectedEstimate = selectedLines.fold<double>(
          0,
          (sum, line) => sum + line.subtotal,
        );
        final groups = <String?, List<CartLine>>{};
        for (final line in cart.cart?.items ?? <CartLine>[]) {
          (groups[_metadata.shops[line.productId]?.id] ??= []).add(line);
        }
        final cartContents = <Widget>[
          MarketPageHeading(
            title: 'Your Cart',
            action: TextButton.icon(
              onPressed: cart.loading || cart.writing || cart.coolingDown
                  ? null
                  : cart.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Cart'),
            ),
          ),
          if (cart.loading || cart.writing)
            const LinearProgressIndicator(semanticsLabel: 'Updating Cart'),
          if (cart.stale && cart.cart != null)
            const Text('This Cart view needs a refresh before you continue.'),
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
          if (cart.cart?.items.any((line) => line.selectable) == true)
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                tristate: true,
                value: cart.selectAllValue,
                onChanged: cart.canEdit
                    ? (_) => cart.toggleSelectAllEligible()
                    : null,
                title: const Text('Select all available items'),
                subtitle: Text(
                  '${selectedLines.length} of $eligibleCount available lines selected',
                ),
              ),
            ),
          if (cart.cart?.items.isEmpty == true && !cart.loading) ...[
            MarketEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your Cart is empty.',
              message: 'Browse Products to add items.',
              action: TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Browse Products'),
              ),
            ),
          ],
          for (final group in groups.entries)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: MarketSection(
                title: group.key == null
                    ? 'Cart items'
                    : _metadata.shops[group.value.first.productId]!.name,
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
        ];
        final purchaseSummary = LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'The selected merchandise estimate excludes shipping and discounts. Final COD appears after Checkout review.',
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selected merchandise estimate'),
                      Text(
                        '${selectedLines.length} selected ${selectedLines.length == 1 ? 'line' : 'lines'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (selectedLines.isNotEmpty)
                    Text(
                      '₱${selectedEstimate.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  SizedBox(
                    width: constraints.maxWidth < 280
                        ? constraints.maxWidth
                        : null,
                    child: FilledButton(
                      onPressed: cart.canEdit && selectedLines.isNotEmpty
                          ? () {
                              if (commerce.checkout.begin(
                                CheckoutIntent.cart(
                                  selectedLines.map((line) => line.id),
                                ),
                              )) {
                                context.push('/checkout');
                              }
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(
                        'Checkout selected (${selectedLines.length})',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              if (selectedLines.isEmpty)
                const Text('Select available lines to see an estimate.'),
            ],
          ),
        );
        final compactHeight =
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom <
            500;
        if (compactHeight) {
          return ListView(
            padding: pagePadding(context),
            children: [
              ...cartContents,
              const SizedBox(height: 16),
              purchaseSummary,
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: pagePadding(context),
                children: cartContents,
              ),
            ),
            PurchaseBar(child: purchaseSummary),
          ],
        );
      },
    );
  }
}
