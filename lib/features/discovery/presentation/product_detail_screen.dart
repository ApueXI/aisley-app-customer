import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../data/product_detail_model.dart';
import 'catalog_widgets.dart';
import 'product_controller.dart';
import 'product_information.dart';
import 'product_purchase_actions.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.dependencies,
    required this.productId,
  });
  final AppDependencies dependencies;
  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductDetailController _controller = ProductDetailController(
    widget.dependencies.discovery!,
    widget.productId,
  );
  bool _recorded = false, _statusRequested = false;

  @override
  void initState() {
    super.initState();
    widget.dependencies.session.addListener(_sessionChanged);
    _controller.load();
  }

  @override
  void dispose() {
    widget.dependencies.session.removeListener(_sessionChanged);
    _controller.dispose();
    super.dispose();
  }

  void _sessionChanged() {
    if (mounted) setState(() => _statusRequested = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Product')),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final product = _controller.product;
        if (_controller.loading && product == null) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading Product detail',
            ),
          );
        }
        if (_controller.error != null && product == null) {
          return _unavailable(_controller.error!);
        }
        if (product == null) {
          return _unavailable('Product detail is unavailable.');
        }
        if (!_recorded) {
          _recorded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _recordView(product.id);
          });
        }
        if (!_statusRequested && widget.dependencies.session.active) {
          _statusRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.dependencies.savedStatus!.loadStatuses([product.id]);
            }
          });
        }
        return _detail(context, product);
      },
    ),
  );

  Future<void> _recordView(String id) async {
    final session = widget.dependencies.session;
    final lease = session.active ? session.verifiedLease : null;
    try {
      if (lease != null) {
        await widget.dependencies.recentlyViewed!.record(lease, id);
      } else if (session.customer == null) {
        await widget.dependencies.guestRecent!.record(
          id,
          widget.dependencies.clock().toUtc(),
        );
      }
    } catch (_) {
      // A history failure never hides successfully loaded public Product detail.
    }
  }

  Widget _unavailable(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 42),
          const SizedBox(height: 10),
          const Text('This Product is unavailable.'),
          Text(message),
          FilledButton(onPressed: _controller.load, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _detail(BuildContext context, ProductDetail product) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide && product.media.isNotEmpty) _gallery(product),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    _wishlistButton(context, product.id),
                  ],
                ),
                if (product.averageRating != null)
                  Text(
                    '★ ${product.averageRating!.toStringAsFixed(1)} · ${product.reviewCount} reviews',
                  ),
                const SizedBox(height: 8),
                Text(
                  '₱${(_controller.currentPrice ?? product.price).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (product.originalPrice != null &&
                    product.originalPrice! >
                        (_controller.currentPrice ?? product.price))
                  Text(
                    'Was ₱${product.originalPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                if (product.shortDescription?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(product.shortDescription!),
                  ),
                const SizedBox(height: 16),
                if (product.optionGroups.isNotEmpty) _options(product),
                const SizedBox(height: 12),
                _availability(product),
                _quantity(context, product),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: widget.dependencies.savedStatus!,
                  builder: (context, _) =>
                      widget.dependencies.savedStatus!.error == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          liveRegion: true,
                          child: Text(widget.dependencies.savedStatus!.error!),
                        ),
                ),
                ProductPurchaseActions(
                  dependencies: widget.dependencies,
                  product: _controller,
                ),
                const SizedBox(height: 20),
                _shopCard(context, product),
                ProductInformation(
                  dependencies: widget.dependencies,
                  product: product,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      );
      return SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: wide
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: constraints.maxHeight * .72,
                            child: _gallery(product),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: content),
                      ],
                    ),
                  )
                : content,
          ),
        ),
      );
    },
  );

  Widget _gallery(ProductDetail product) {
    final variant = _controller.selectedVariant;
    final selected = variant == null
        ? product.media
        : product.media
              .where(
                (media) =>
                    media.variantId == null ||
                    media.variantId == variant.id ||
                    media.id == variant.primaryMediaId,
              )
              .toList();
    final media = selected.isEmpty ? product.media : selected;
    return SizedBox(
      height: 320,
      child: PageView.builder(
        itemCount: media.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CatalogImage(
              url: media[index].url,
              discovery: widget.dependencies.discovery!,
              width: double.infinity,
              height: 320,
              label: media[index].altText.isEmpty
                  ? product.title
                  : media[index].altText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _wishlistButton(BuildContext context, String productId) {
    final session = widget.dependencies.session;
    final savedStatus = widget.dependencies.savedStatus!;
    return ListenableBuilder(
      listenable: savedStatus,
      builder: (context, _) {
        final state = session.active ? savedStatus.isSaved(productId) : null;
        final saved = state == true;
        final pending = session.active && savedStatus.isPending(productId);
        return IconButton.filledTonal(
          tooltip: session.active && state == null
              ? 'Check Wishlist status'
              : saved
              ? 'Remove from Wishlist'
              : 'Save to Wishlist',
          onPressed: pending || savedStatus.coolingDown
              ? null
              : () {
                  if (!session.active) {
                    context.push(
                      '/login?returnTo=${Uri.encodeComponent('/products/$productId')}',
                    );
                    return;
                  }
                  if (state == null) {
                    savedStatus.loadStatuses([productId]);
                    return;
                  }
                  savedStatus.setSaved(productId, !saved);
                },
          icon: pending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(saved ? Icons.favorite : Icons.favorite_border),
        );
      },
    );
  }

  Widget _options(ProductDetail product) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final group in product.optionGroups)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DropdownButtonFormField<String?>(
            initialValue: _controller.selectedValues[group.id],
            isExpanded: true,
            decoration: InputDecoration(labelText: group.name),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Choose ${group.name}'),
              ),
              for (final value in group.values)
                DropdownMenuItem<String?>(
                  value: value.id,
                  enabled: _controller.canChoose(group.id, value.id),
                  child: Text(value.value),
                ),
            ],
            onChanged: (value) {
              if (value != null) _controller.choose(group.id, value);
            },
          ),
        ),
      if (_controller.selectedValues.isNotEmpty)
        TextButton(
          onPressed: _controller.resetChoices,
          child: const Text('Clear choices'),
        ),
    ],
  );

  Widget _availability(ProductDetail product) {
    if (_controller.requiresVariantSelection && !_controller.selectionValid) {
      return const Text('Choose one available option from each group.');
    }
    final variant = _controller.selectedVariant;
    if (variant != null && !variant.inStock ||
        variant == null && !product.availability.inStock) {
      return const Text('Currently unavailable');
    }
    final stock = _controller.availableStock;
    return Text(stock == null ? 'Available' : '$stock available');
  }

  Widget _quantity(BuildContext context, ProductDetail product) {
    final stock = _controller.availableStock;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Quantity'),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Decrease quantity',
          onPressed: _controller.quantity > 1 ? _controller.decrement : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Semantics(
          label: 'Quantity ${_controller.quantity}',
          child: Text('${_controller.quantity}'),
        ),
        IconButton(
          tooltip: 'Increase quantity',
          onPressed:
              stock != null &&
                  _controller.quantity < stock &&
                  _controller.available
              ? _controller.increment
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _shopCard(BuildContext context, ProductDetail product) => Card(
    elevation: 0,
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
      title: Text(product.shop.name),
      subtitle: Text(
        product.shop.isOnVacation
            ? product.shop.vacationMessage ?? 'Shop is on vacation'
            : 'View this Shop',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/shops/${product.shop.slug}'),
    ),
  );
}
