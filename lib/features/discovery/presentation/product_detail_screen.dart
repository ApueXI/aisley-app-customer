import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../data/product_detail_model.dart';
import 'product_controller.dart';
import 'product_choices.dart';
import 'product_information.dart';
import 'product_gallery.dart';
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
  final _galleryKey = GlobalKey(),
      _contentKey = GlobalKey(),
      _actionsKey = GlobalKey();

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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => ShoppingPage(
      appBar: AppBar(title: const Text('Product')),
      body: _loaded(context),
      bottomBar: !_wide(context) && _controller.product != null
          ? PurchaseBar(child: _purchaseActions())
          : null,
    ),
  );

  bool _wide(BuildContext context) =>
      (MediaQuery.sizeOf(context).width.clamp(0, 1200) -
              pageSpacing(context) * 2) >=
          840 &&
      catalogTextScale(context) <= 1.5;

  Widget _purchaseActions() => ProductPurchaseActions(
    key: _actionsKey,
    dependencies: widget.dependencies,
    product: _controller,
  );

  Widget _loaded(BuildContext context) {
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
  }

  Future<void> _recordView(String id) async {
    final session = widget.dependencies.session;
    final lease = session.active ? session.verifiedLease : null;
    try {
      if (lease != null) {
        await widget.dependencies.recentlyViewed!.record(lease, id);
      }
    } catch (_) {
      // A history failure never hides successfully loaded public Product detail.
    }
  }

  Widget _unavailable(String message) => SingleChildScrollView(
    child: Center(
      child: Padding(
        padding: pagePadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 42),
            const SizedBox(height: 10),
            const Text('This Product is unavailable.'),
            Text(message),
            FilledButton(
              onPressed: _controller.load,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _detail(BuildContext context, ProductDetail product) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = pageSpacing(context);
      final width = (constraints.maxWidth - padding * 2).clamp(0.0, 1200.0);
      final wide = width >= 840 && catalogTextScale(context) <= 1.5;
      final originalPrice = _controller.selectedVariant == null
          ? product.originalPrice
          : _controller.selectedVariant!.originalPrice;
      final content = Column(
        key: _contentKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.zero,
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
                if (originalPrice != null &&
                    originalPrice > (_controller.currentPrice ?? product.price))
                  Text(
                    'Was ₱${originalPrice.toStringAsFixed(2)}',
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
                ProductChoices(product: product, controller: _controller),
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
                if (wide) _purchaseActions(),
                const SizedBox(height: 20),
                Text('Shop', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _shopCard(context, product),
                if (widget.dependencies.communication != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Reviews and questions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => context.push(
                              '/products/${product.id}/questions',
                            ),
                            child: const Text('Questions & answers'),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.push('/products/${product.id}/reviews'),
                            child: const Text('Reviews'),
                          ),
                          TextButton(
                            onPressed: () => context.push(
                              '/messages/shops/new/${product.shop.id}?context_type=product&context_id=${product.id}',
                            ),
                            child: const Text('Message Shop'),
                          ),
                        ],
                      ),
                    ],
                  ),
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
        padding: EdgeInsets.all(padding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: wide
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _gallery(product)),
                        const SizedBox(width: 24),
                        Expanded(child: content),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      if (product.media.isNotEmpty) _gallery(product),
                      content,
                    ],
                  ),
          ),
        ),
      );
    },
  );

  Widget _gallery(ProductDetail product) => ProductGallery(
    key: _galleryKey,
    product: product,
    variant: _controller.selectedVariant,
    discovery: widget.dependencies.discovery!,
  );

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
