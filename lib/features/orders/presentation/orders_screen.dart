import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tab in _controller.tabs)
                  ChoiceChip(
                    label: Text(tab.label),
                    selected: _controller.group == tab.value,
                    onSelected:
                        tab.value == null || orderGroups.contains(tab.value)
                        ? (_) => _controller.filter(tab.value)
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
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
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: ListTile(
                title: Text('${order.shop.name}\n${order.reference}'),
                subtitle: Text(
                  '${order.statusLabel} · ${order.groupLabel}\n${order.item?.name ?? '${order.lineCount} configurations'}\n${order.itemCount} items · ${order.totals.payable.display(order.totals.currency)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push('/orders/${order.id}');
                  if (mounted) await _controller.load();
                },
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
