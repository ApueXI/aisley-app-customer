import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/list_recovery.dart';
import '../../../core/ui/marketplace_surfaces.dart';
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
  void didUpdateWidget(covariant ShopDirectoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page != oldWidget.page) {
      _controller.page = widget.page;
      _controller.load();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShoppingPage(
    appBar: AppBar(
      title: const Text('Shops'),
      actions: marketplaceDesktop(context)
          ? const []
          : marketplaceActions(context),
    ),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final result = _controller.result;
        return ListView(
          padding: pagePadding(context),
          children: [
            MarketPageHeading(
              title: 'Explore Shops',
              subtitle: 'Browse Shops in the AISLEY marketplace.',
              action: OutlinedButton.icon(
                onPressed: () => context.push('/search?mode=shops'),
                icon: const Icon(Icons.search),
                label: const Text('Search Shops'),
              ),
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
            ListRecovery(
              stale: _controller.stale,
              retry: _controller.retry,
              error: _controller.error,
              busy: _controller.loading,
              coolingDown: _controller.coolingDown,
              retained: result != null,
              requestedPage: _controller.page,
              displayedPage: result?.pagination.currentPage,
            ),
            if (result != null) ...[
              if (!_controller.stale &&
                  _controller.page > result.pagination.lastPage) ...[
                const Text('This page is no longer available.'),
                TextButton(
                  onPressed: () =>
                      _replaceRoute(context, _controller.category, 1),
                  child: const Text('Go to first page'),
                ),
              ] else if (result.items.isEmpty)
                Text(
                  _controller.stale
                      ? ''
                      : 'No Shops are listed in this category.',
                )
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
          onPressed:
              !_controller.loading && !_controller.coolingDown && current > 1
              ? () => _replaceRoute(context, _controller.category, current - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page $current of $last'),
        IconButton(
          tooltip: 'Next page',
          onPressed:
              !_controller.loading && !_controller.coolingDown && current < last
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
    if (uri.toString() == GoRouterState.of(context).uri.toString()) {
      _controller.retry();
    } else {
      context.replace(uri.toString());
    }
  }
}
