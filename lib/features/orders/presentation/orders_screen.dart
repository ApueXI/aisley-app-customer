import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../data/order_models.dart';
import 'orders_controller.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  late final _controller = OrdersController(
    widget.dependencies.session,
    widget.dependencies.commerce!.orders,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await widget.dependencies.session.refresh();
    if (mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => ShoppingPage(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh Orders',
            onPressed: () => _controller.load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: pagePadding(context),
        children: [
          if (_controller.tabs.isNotEmpty)
            MarketTabs<String?>(
              values: {
                for (final tab in _controller.tabs)
                  if (tab.value == null || orderGroups.contains(tab.value))
                    tab.value: tab.label,
              },
              selected: _controller.group,
              onSelected: _controller.filter,
            ),
          if (_controller.loading)
            const LinearProgressIndicator(semanticsLabel: 'Loading Orders'),
          if (_controller.stale && _controller.items.isNotEmpty)
            const Text(
              'Saved Orders are stale. Refresh for current status and capabilities.',
            ),
          if (_controller.error != null)
            Semantics(liveRegion: true, child: Text(_controller.error!)),
          if (!_controller.loading &&
              _controller.error == null &&
              _controller.items.isEmpty)
            const Text('No Orders in this group.'),
          for (final order in _controller.items)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: MarketSection(
                title: order.shop.name,
                action: Text(
                  order.statusLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      order.reference,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      order.item?.name ?? '${order.lineCount} items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (order.item?.variantName != null)
                      Text(order.item!.variantName!),
                    const SizedBox(height: 8),
                    Text(
                      '${order.itemCount} items · ${order.totals.payable.display(order.totals.currency)}',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: () async {
                          await context.push('/orders/${order.id}');
                          if (mounted) await _controller.load();
                        },
                        child: Text(
                          order.group == 'completed' && order.actions.canReview
                              ? 'View order and review'
                              : 'View order / tracking',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_controller.pageError != null) Text(_controller.pageError!),
          if (_controller.hasMore)
            TextButton(
              onPressed:
                  _controller.paging ||
                      _controller.stale ||
                      _controller.coolingDown
                  ? null
                  : () => _controller.load(more: true),
              child: Text(_controller.paging ? 'Loading…' : 'Load more Orders'),
            ),
          TextButton(
            onPressed: _controller.loading || _controller.coolingDown
                ? null
                : () => _controller.load(),
            child: const Text('Retry / refresh Orders'),
          ),
        ],
      ),
    ),
  );
}
