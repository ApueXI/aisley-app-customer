import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final result = _controller.result;
      return ListView(
        padding: pagePadding(context),
        children: [
          Text('Shops', style: Theme.of(context).textTheme.headlineSmall),
          OutlinedButton.icon(
            onPressed: () => context.push('/search?mode=shops'),
            icon: const Icon(Icons.search),
            label: const Text('Search Shops'),
          ),
          const SizedBox(height: 16),
          if (result != null && result.categories.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue:
                  result.categories.any((c) => c.slug == _controller.category)
                  ? _controller.category
                  : null,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Shop category'),
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
              onChanged: (value) => _replaceRoute(context, value, 1),
            ),
          const SizedBox(height: 24),
          if (_controller.loading)
            const LinearProgressIndicator(semanticsLabel: 'Loading Shops'),
          if (_controller.error != null) _error(_controller.error!),
          if (result != null) ...[
            if (_controller.page > result.pagination.lastPage) ...[
              const Text('This page is no longer available.'),
              TextButton(
                onPressed: () =>
                    _replaceRoute(context, _controller.category, 1),
                child: const Text('Go to first page'),
              ),
            ] else if (result.items.isEmpty)
              const Text('No Shops are listed in this category.')
            else
              for (final shop in result.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShopCardTile(
                    shop: shop,
                    discovery: widget.dependencies.discovery!,
                    onTap: () => context.push('/shops/${shop.slug}'),
                  ),
                ),
            _pagination(
              context,
              result.pagination.currentPage,
              result.pagination.lastPage,
            ),
          ],
        ],
      );
    },
  );

  Widget _error(String message) => Center(
    child: Padding(
      padding: pagePadding(context),
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

  Widget _pagination(BuildContext context, int current, int last) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
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
