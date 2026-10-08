import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/form_page.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../../discovery/presentation/catalog_widgets.dart';
import 'saved_products_controller.dart';

class SavedProductsScreen extends StatefulWidget {
  const SavedProductsScreen({
    super.key,
    required this.dependencies,
    required this.collection,
  });
  final AppDependencies dependencies;
  final SavedCollection collection;
  @override
  State<SavedProductsScreen> createState() => _SavedProductsScreenState();
}

class _SavedProductsScreenState extends State<SavedProductsScreen> {
  late final _controller = SavedProductsController(
    widget.dependencies.session,
    collection: widget.collection,
    wishlist: widget.dependencies.wishlist!,
    recent: widget.dependencies.recentlyViewed!,
    savedStatus: widget.dependencies.savedStatus!,
  );
  bool get _history => widget.collection == SavedCollection.recentlyViewed;
  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShoppingPage(
    appBar: AppBar(
      title: Text(_history ? 'Recently viewed' : 'Wishlist'),
      actions: [
        IconButton(
          tooltip: 'Refresh list',
          onPressed: () => _controller.load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => ListView(
        padding: pagePadding(context),
        children: [
          if (_controller.loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading saved Products',
            ),
          if (_controller.error != null) ...[
            Semantics(liveRegion: true, child: Text(_controller.error!)),
            TextButton(
              onPressed: () => _controller.load(),
              child: const Text('Refresh'),
            ),
          ],
          if (_controller.loaded &&
              _controller.items.isEmpty &&
              _controller.error == null)
            Text(
              _history
                  ? 'No Products in your account history.'
                  : 'Your Wishlist is empty. Save Products from their details.',
            ),
          if (_history && _controller.items.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _controller.clearing ? null : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(
                _controller.clearing ? 'Clearing…' : 'Clear account history',
              ),
            ),
          for (final item in _controller.items)
            ProductBoundaryCard(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final wide = constraints.maxWidth >= 560 * scale;
                  final removing = _controller.pending.contains(
                    item.product.id,
                  );
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '₱${item.product.price.toStringAsFixed(2)} · ${item.product.shop.name}',
                      ),
                      Text(
                        '${_history ? 'Viewed' : 'Saved'} ${item.date.toLocal().toString().split('.').first}',
                      ),
                    ],
                  );
                  final actions = [
                    TextButton(
                      onPressed: () =>
                          context.push('/products/${item.product.id}'),
                      child: const Text('View product'),
                    ),
                    TextButton(
                      onPressed: removing ? null : () => _remove(item),
                      child: Text(
                        removing
                            ? 'Removing…'
                            : _history
                            ? 'Remove from history'
                            : 'Remove from wishlist',
                      ),
                    ),
                  ];
                  final image = SizedBox(
                    width: 80,
                    height: 80,
                    child: CatalogImage(
                      url: item.product.thumbnailUrl,
                      discovery: widget.dependencies.discovery!,
                      label: item.product.title,
                    ),
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        image,
                        const SizedBox(width: 12),
                        Expanded(child: details),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 210,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: actions,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          image,
                          const SizedBox(width: 12),
                          Expanded(child: details),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        children: actions,
                      ),
                    ],
                  );
                },
              ),
            ),
          if (_controller.pageError != null) Text(_controller.pageError!),
          if (_controller.nextCursor != null)
            OutlinedButton(
              onPressed: _controller.loadingMore
                  ? null
                  : () => _controller.load(more: true),
              child: Text(_controller.loadingMore ? 'Loading…' : 'Load more'),
            ),
        ],
      ),
    ),
  );

  Future<void> _remove(SavedProduct item) async {
    final confirmed = await confirmAction(
      context,
      title: _history ? 'Remove from history?' : 'Remove from Wishlist?',
      message:
          'Remove “${item.product.title}” from this account’s ${_history ? 'viewing history' : 'Wishlist'}?',
      action: 'Remove',
    );
    if (confirmed && mounted) await _controller.remove(item.product.id);
  }

  Future<void> _clear() async {
    final confirmed = await confirmAction(
      context,
      title: 'Clear account history?',
      message: 'Remove all recently viewed Products from this account?',
      action: 'Clear history',
    );
    if (confirmed && mounted) await _controller.clearHistory();
  }
}
