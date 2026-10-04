import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../data/catalog_models.dart';
import 'catalog_widgets.dart';
import 'shop_controllers.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.dependencies,
    required this.slug,
    required this.query,
    required this.category,
    required this.page,
    this.limit = 20,
  });
  final AppDependencies dependencies;
  final String slug, query;
  final String? category;
  final int page, limit;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final ShopBrowseController _controller = ShopBrowseController(
    widget.dependencies.discovery!,
    slug: widget.slug,
    query: widget.query,
    category: widget.category,
    page: widget.page,
    limit: widget.limit,
  );
  late final TextEditingController _query = TextEditingController(
    text: widget.query,
  );

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shop')),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final result = _controller.result;
        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (_controller.shop != null)
                    _shopHeader(context, _controller.shop!),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _query,
                          maxLength: 100,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _applyFilters(context),
                          decoration: InputDecoration(
                            labelText: 'Search this Shop',
                            hintText: 'Product name',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              tooltip: 'Clear keyword',
                              onPressed: () {
                                _query.clear();
                                _applyFilters(context);
                              },
                              icon: const Icon(Icons.clear),
                            ),
                          ),
                        ),
                        if (result != null && result.categories.isNotEmpty)
                          DropdownButtonFormField<String?>(
                            initialValue:
                                result.categories.any(
                                  (item) => item.slug == _controller.category,
                                )
                                ? _controller.category
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Product category',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Product categories'),
                              ),
                              for (final category in result.categories)
                                DropdownMenuItem<String?>(
                                  value: category.slug,
                                  child: Text(category.name),
                                ),
                            ],
                            onChanged: (value) => _replaceShopRoute(
                              context,
                              query: _query.text.trim(),
                              category: value,
                              page: 1,
                              clearCategory: value == null,
                            ),
                          ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => _applyFilters(context),
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: const Text('Apply filters'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          body: Column(
            children: [
              if (_controller.loading && result == null)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Loading Shop Products',
                    ),
                  ),
                )
              else if (_controller.error != null && result == null)
                Expanded(child: _error(context, _controller.error!))
              else if (result != null)
                Expanded(
                  child: Column(
                    children: [
                      if (_controller.error != null)
                        _inlineError(_controller.error!, _controller.retry),
                      if (_controller.loading) const LinearProgressIndicator(),
                      if (_controller.page > result.pagination.lastPage)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('This page is no longer available.'),
                                TextButton(
                                  onPressed: () =>
                                      _replaceShopRoute(context, page: 1),
                                  child: const Text('Go to first page'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (result.items.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text('No Products match these filters.'),
                          ),
                        )
                      else ...[
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = (constraints.maxWidth / 210)
                                  .floor()
                                  .clamp(1, 5);
                              return GridView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: result.items.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      mainAxisExtent:
                                          170 +
                                          145 *
                                              MediaQuery.textScalerOf(context)
                                                  .scale(14) /
                                              14,
                                    ),
                                itemBuilder: (context, index) {
                                  final product = result.items[index];
                                  return ProductCardTile(
                                    width: double.infinity,
                                    product: product,
                                    discovery: widget.dependencies.discovery!,
                                    onTap: () =>
                                        context.push('/products/${product.id}'),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        _pagination(context, result.pagination),
                      ],
                    ],
                  ),
                )
              else
                const Expanded(
                  child: Center(child: Text('Shop Products are unavailable.')),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _shopHeader(BuildContext context, ShopSummary shop) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shop.bannerUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CatalogImage(
              url: shop.bannerUrl,
              discovery: widget.dependencies.discovery!,
              height: 130,
              width: double.infinity,
              label: '${shop.name} banner',
            ),
          ),
        const SizedBox(height: 8),
        Text(shop.name, style: Theme.of(context).textTheme.headlineSmall),
        if (shop.category != null) Text(shop.category!.name),
        if (shop.description != null) Text(shop.description!),
        if (widget.dependencies.communication != null)
          TextButton.icon(
            onPressed: () => context.push('/messages/shops/new/${shop.id}'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message Shop'),
          ),
      ],
    ),
  );

  Widget _error(BuildContext context, String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('This Shop is unavailable.'),
        Text(message),
        FilledButton(onPressed: _controller.retry, child: const Text('Retry')),
      ],
    ),
  );

  Widget _inlineError(String message, VoidCallback retry) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );

  Widget _pagination(BuildContext context, Pagination pagination) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: pagination.currentPage > 1
              ? () =>
                    _replaceShopRoute(context, page: pagination.currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page ${pagination.currentPage} of ${pagination.lastPage}'),
        IconButton(
          tooltip: 'Next page',
          onPressed: pagination.currentPage < pagination.lastPage
              ? () =>
                    _replaceShopRoute(context, page: pagination.currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  void _applyFilters(BuildContext context, {String? category}) {
    _replaceShopRoute(
      context,
      query: _query.text.trim(),
      category: category ?? _controller.category,
      page: 1,
    );
  }

  void _replaceShopRoute(
    BuildContext context, {
    String? query,
    String? category,
    int? page,
    bool clearCategory = false,
  }) {
    final nextQuery = query ?? _controller.query;
    final nextCategory = clearCategory
        ? null
        : category ?? _controller.category;
    final uri = Uri(
      path: '/shops/${widget.slug}',
      queryParameters: {
        if (nextQuery.isNotEmpty) 'q': nextQuery,
        'category': ?nextCategory,
        if ((page ?? 1) > 1) 'page': '${page ?? 1}',
        if (widget.limit != 20) 'limit': '${widget.limit}',
      },
    );
    context.replace(uri.toString());
  }
}
