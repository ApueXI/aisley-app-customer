import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../data/catalog_models.dart';
import 'catalog_widgets.dart';
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
  void dispose() {
    _controller.removeListener(_updated);
    _query.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Search')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            onPressed: () {
                              _query.clear();
                              _controller.search('');
                              _updateRoute(context, page: null);
                            },
                            icon: const Icon(Icons.clear),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<SearchMode>(
                        segments: const [
                          ButtonSegment(
                            value: SearchMode.products,
                            label: Text('Products'),
                            icon: Icon(Icons.shopping_bag_outlined),
                          ),
                          ButtonSegment(
                            value: SearchMode.shops,
                            label: Text('Shops'),
                            icon: Icon(Icons.storefront_outlined),
                          ),
                        ],
                        selected: {_controller.mode},
                        onSelectionChanged: (selected) {
                          _controller.setMode(selected.first);
                          _updateRoute(context, page: null);
                        },
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed:
                            _controller.loading || _controller.coolingDown
                            ? null
                            : () => _submit(context),
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _results(context),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _submit(BuildContext context) async {
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
    context.replace(uri.toString());
  }

  Widget _results(BuildContext context) {
    if (_controller.loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Searching'),
      );
    }
    if (_controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 8),
              const Text('Search is unavailable.'),
              Text(_controller.error!),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _controller.retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_controller.hasQuery ||
        !_autoSearched &&
            _controller.products == null &&
            _controller.shops == null) {
      return const Center(child: Text('Enter a name to search.'));
    }
    if (_controller.pageOutOfRange) {
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
        return const Center(
          child: Text('No Products match this search. Try another name.'),
        );
      }
      return _productResults(context, products.items, products.pagination);
    }
    final shops = _controller.shops;
    if (shops != null) {
      if (shops.items.isEmpty) {
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
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('${pagination.total} Products'),
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisExtent:
                170 + 145 * MediaQuery.textScalerOf(context).scale(14) / 14,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final product = items[index];
            return ProductCardTile(
              width: double.infinity,
              product: product,
              discovery: widget.dependencies.discovery!,
              onTap: () => context.push('/products/${product.id}'),
            );
          },
        ),
      ),
      _pagination(context, pagination.currentPage, pagination.lastPage),
    ],
  );

  Widget _shopResults(
    BuildContext context,
    List<ShopSummary> items,
    Pagination pagination,
  ) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('${pagination.total} Shops'),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) => ShopCardTile(
            shop: items[index],
            discovery: widget.dependencies.discovery!,
            onTap: () => context.push('/shops/${items[index].slug}'),
          ),
        ),
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
          onPressed: current > 1 ? () => _goToPage(context, current - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page $current of $last'),
        IconButton(
          tooltip: 'Next page',
          onPressed: current < last
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
