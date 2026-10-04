import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import 'catalog_widgets.dart';
import 'shop_controllers.dart';

class ShopDirectoryScreen extends StatefulWidget {
  const ShopDirectoryScreen({
    super.key,
    required this.dependencies,
    this.category,
    this.page = 1,
    this.limit = 20,
  });
  final AppDependencies dependencies;
  final String? category;
  final int page, limit;

  @override
  State<ShopDirectoryScreen> createState() => _ShopDirectoryScreenState();
}

class _ShopDirectoryScreenState extends State<ShopDirectoryScreen> {
  late final ShopDirectoryController _controller =
      ShopDirectoryController(widget.dependencies.discovery!)
        ..category = widget.category
        ..page = widget.page
        ..limit = widget.limit;

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
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final result = _controller.result;
        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push('/search?mode=shops'),
                          icon: const Icon(Icons.search),
                          label: const Text('Search Shops'),
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
                              labelText: 'Shop category',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Shop categories'),
                              ),
                              for (final category in result.categories)
                                DropdownMenuItem<String?>(
                                  value: category.slug,
                                  child: Text(category.name),
                                ),
                            ],
                            onChanged: (value) =>
                                _replaceRoute(context, value, 1),
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
                      semanticsLabel: 'Loading Shops',
                    ),
                  ),
                )
              else if (_controller.error != null && result == null)
                Expanded(child: _error(_controller.error!))
              else if (result != null)
                Expanded(
                  child: Column(
                    children: [
                      if (_controller.error != null)
                        _inlineError(_controller.error!, _controller.retry),
                      if (_controller.loading)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Refreshing Shops',
                        ),
                      if (_controller.page > result.pagination.lastPage)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('This page is no longer available.'),
                                TextButton(
                                  onPressed: () => _replaceRoute(
                                    context,
                                    _controller.category,
                                    1,
                                  ),
                                  child: const Text('Go to first page'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (result.items.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No Shops are listed in this category.',
                            ),
                          ),
                        )
                      else ...[
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: result.items.length,
                            itemBuilder: (context, index) {
                              final shop = result.items[index];
                              return ShopCardTile(
                                shop: shop,
                                discovery: widget.dependencies.discovery!,
                                onTap: () =>
                                    context.push('/shops/${shop.slug}'),
                              );
                            },
                          ),
                        ),
                        _pagination(
                          context,
                          result.pagination.currentPage,
                          result.pagination.lastPage,
                        ),
                      ],
                    ],
                  ),
                )
              else
                const Expanded(
                  child: Center(child: Text('Shop directory is unavailable.')),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _error(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const Text('Shop directory is unavailable.'),
          Text(message),
          FilledButton(
            onPressed: _controller.retry,
            child: const Text('Retry'),
          ),
        ],
      ),
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

  Widget _pagination(BuildContext context, int current, int last) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: current > 1
              ? () => _replaceRoute(context, _controller.category, current - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page $current of $last'),
        IconButton(
          tooltip: 'Next page',
          onPressed: current < last
              ? () => _replaceRoute(context, _controller.category, current + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  void _replaceRoute(BuildContext context, String? category, int page) {
    final uri = Uri(
      path: '/shops',
      queryParameters: {
        'category': ?category,
        if (page > 1) 'page': '$page',
        if (widget.limit != 20) 'limit': '${widget.limit}',
      },
    );
    context.replace(uri.toString());
  }
}
