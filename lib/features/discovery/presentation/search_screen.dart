import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/list_recovery.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../../../core/ui/marketplace_surfaces.dart';
import '../data/catalog_models.dart';
import 'catalog_widgets.dart';
import 'product_purchase_flow.dart';
import 'search_controller.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.dependencies,
    required this.mode,
    required this.query,
    required this.page,
    required this.validRoute,
    this.limit = 20,
  });
  final AppDependencies dependencies;
  final SearchMode mode;
  final String query;
  final int page, limit;
  final bool validRoute;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final DiscoverySearchController _controller =
      DiscoverySearchController(widget.dependencies.discovery!)
        ..mode = widget.mode
        ..limit = widget.limit;
  late final TextEditingController _query = TextEditingController(
    text: widget.query,
  );
  bool _autoSearched = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updated);
    if (widget.validRoute && widget.query.trim().isNotEmpty) {
      _autoSearched = true;
      _controller.search(widget.query, page: widget.page);
    }
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page != oldWidget.page) {
      _controller.search(widget.query, page: widget.page);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updated);
    _query.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShoppingPage(
    appBar: AppBar(
      title: const Text('Search'),
      actions: marketplaceDesktop(context)
          ? const []
          : marketplaceActions(context),
    ),
    body: ListView(
      padding: pagePadding(context),
      children: [
        if (!widget.validRoute)
          const Text(
            'The search link has unsupported filters. Start a new search.',
          ),
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          maxLength: 100,
          onSubmitted: (_) => _submit(context),
          decoration: InputDecoration(
            labelText: 'Search Products or Shops',
            hintText: 'Enter a name',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.clear),
              onPressed: () {
                _query.clear();
                _controller.search('');
                _updateRoute(context, page: null);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        MarketTabs<SearchMode>(
          values: const {
            SearchMode.products: 'Products',
            SearchMode.shops: 'Shops',
          },
          selected: _controller.mode,
          onSelected: (mode) {
            _controller.setMode(mode);
            _updateRoute(context, page: null);
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _controller.loading || _controller.coolingDown
                ? null
                : () => _submit(context),
            icon: const Icon(Icons.search),
            label: const Text('Search'),
          ),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _results(context),
        ),
      ],
    ),
  );

  Future<void> _submit(BuildContext context) async {
    if (_controller.loading || _controller.coolingDown) return;
    _updateRoute(context, page: 1);
  }

  void _updateRoute(BuildContext context, {required int? page}) {
    final query = _query.text.trim();
    final uri = Uri(
      path: '/search',
      queryParameters: {
        'mode': _controller.mode.name,
        if (widget.limit != 20) 'limit': '${widget.limit}',
        if (query.isNotEmpty) 'q': query,
        if (query.isNotEmpty && page != null && page > 1) 'page': '$page',
      },
    );
    if (uri.toString() == GoRouterState.of(context).uri.toString()) {
      _controller.retry();
    } else {
      context.replace(uri.toString());
    }
  }

  Widget _results(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListRecovery(
        stale: _controller.stale,
        retry: _controller.retry,
        error: _controller.error,
        retained: _controller.displayedPage != null,
        busy: _controller.loading,
        coolingDown: _controller.coolingDown,
        requestedPage: _controller.pageNumber,
        displayedPage: _controller.displayedPage,
      ),
      _resultRows(context),
    ],
  );

  Widget _resultRows(BuildContext context) {
    if (_controller.displayedPage == null &&
        (_controller.loading || _controller.error != null)) {
      return const SizedBox.shrink();
    }
    if (!_controller.hasQuery ||
        !_autoSearched &&
            _controller.products == null &&
            _controller.shops == null) {
      return const MarketEmptyState(
        icon: Icons.search,
        title: 'Enter a name to search.',
      );
    }
    if (!_controller.stale && _controller.pageOutOfRange) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('That page is no longer available.'),
            TextButton(
              onPressed: () => _goToPage(context, 1),
              child: const Text('Show the first page'),
            ),
          ],
        ),
      );
    }
    final products = _controller.products;
    if (products != null) {
      if (products.items.isEmpty) {
        if (_controller.stale) return const SizedBox.shrink();
        return const Center(
          child: Text('No Products match this search. Try another name.'),
        );
      }
      return _productResults(context, products.items, products.pagination);
    }
    final shops = _controller.shops;
    if (shops != null) {
      if (shops.items.isEmpty) {
        if (_controller.stale) return const SizedBox.shrink();
        return const Center(
          child: Text('No Shops match this search. Try another name.'),
        );
      }
      return _shopResults(context, shops.items, shops.pagination);
    }
    return const Center(child: Text('Enter a name to search.'));
  }

  Widget _productResults(
    BuildContext context,
    List<ProductCard> items,
    Pagination pagination,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${pagination.total} Products for “${widget.query}”',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      CatalogGrid(
        children: [
          for (final product in items)
            ProductCardTile(
              width: double.infinity,
              product: product,
              discovery: widget.dependencies.discovery!,
              onTap: () => context.push('/products/${product.id}'),
              onAddToCart: () => unawaited(
                beginProductPurchase(
                  context: context,
                  dependencies: widget.dependencies,
                  productId: product.id,
                  action: ProductPurchaseAction.addToCart,
                ),
              ),
            ),
        ],
      ),
      _pagination(context, pagination.currentPage, pagination.lastPage),
    ],
  );

  Widget _shopResults(
    BuildContext context,
    List<ShopSummary> items,
    Pagination pagination,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${pagination.total} Shops for “${widget.query}”',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      for (final shop in items)
        ShopCardTile(
          shop: shop,
          discovery: widget.dependencies.discovery!,
          onTap: () => context.push('/shops/${shop.slug}'),
        ),
      _pagination(context, pagination.currentPage, pagination.lastPage),
    ],
  );

  Widget _pagination(BuildContext context, int current, int last) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed:
              !_controller.loading && !_controller.coolingDown && current > 1
              ? () => _goToPage(context, current - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page $current of $last'),
        IconButton(
          tooltip: 'Next page',
          onPressed:
              !_controller.loading && !_controller.coolingDown && current < last
              ? () => _goToPage(context, current + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  void _goToPage(BuildContext context, int page) {
    _updateRoute(context, page: page);
  }
}
