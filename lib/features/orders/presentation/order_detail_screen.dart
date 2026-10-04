import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import 'order_action_dialogs.dart';
import 'order_detail_controller.dart';
import 'order_facts.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.dependencies,
    required this.id,
  });
  final AppDependencies dependencies;
  final String id;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  late final _controller = OrderDetailController(
    widget.dependencies.session,
    widget.dependencies.commerce!.orders,
    widget.dependencies.commerce!.mutations,
    widget.dependencies.addresses!,
    widget.id,
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
  Widget build(BuildContext context) {
    final mutations = widget.dependencies.commerce!.mutations;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _controller,
        mutations,
        widget.dependencies.session,
      ]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Order'),
          actions: [
            IconButton(
              tooltip: 'Refresh Order',
              onPressed: _controller.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: !widget.dependencies.session.active
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_controller.loading || mutations.busy(widget.id))
                    const LinearProgressIndicator(
                      semanticsLabel: 'Updating Order',
                    ),
                  if (_controller.stale && _controller.order != null)
                    const Text(
                      'Saved Order is stale. Refresh before making changes.',
                    ),
                  if (_controller.error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(_controller.error!),
                    ),
                  if (mutations.errorFor(widget.id) != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(mutations.errorFor(widget.id)!),
                    ),
                  if (mutations.pending(widget.id) != null) ...[
                    const Text(
                      'An Order change is unresolved. The same request is kept across navigation in this session.',
                    ),
                    FilledButton(
                      onPressed:
                          mutations.busy(widget.id) ||
                              mutations.coolingDown ||
                              mutations.collision(widget.id)
                          ? null
                          : _controller.retryMutation,
                      child: const Text('Retry exact Order change'),
                    ),
                  ],
                  if (_controller.order != null) ...[
                    OrderFacts(_controller.order!),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _controller.canCancel
                              ? () => confirmOrderCancellation(
                                  context,
                                  _controller,
                                )
                              : null,
                          child: const Text('Cancel Order'),
                        ),
                        OutlinedButton(
                          onPressed: _controller.canCorrect
                              ? () => chooseContactCorrection(
                                  context,
                                  _controller,
                                )
                              : null,
                          child: const Text('Correct recipient/contact'),
                        ),
                        TextButton(
                          onPressed: _controller.canCorrect
                              ? () async {
                                  await context.push('/account/addresses');
                                  if (mounted) await _controller.load();
                                }
                              : null,
                          child: const Text('Address Book'),
                        ),
                      ],
                    ),
                    if (!_controller.order!.canCancel &&
                        !_controller.order!.canCorrect)
                      const Text(
                        'The server does not currently permit cancellation or correction.',
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Tracking',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final event in _controller.timeline)
                      ListTile(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: Text(event.label),
                        subtitle: Text(
                          [
                            event.occurredAt.toLocal().toString(),
                            if (event.hub != null) event.hub!,
                            if (event.city != null) event.city!,
                          ].join('\n'),
                        ),
                      ),
                    if (_controller.pageError != null)
                      Text(_controller.pageError!),
                    if (_controller.hasMore)
                      TextButton(
                        onPressed:
                            _controller.paging ||
                                _controller.stale ||
                                _controller.coolingDown
                            ? null
                            : _controller.moreTracking,
                        child: Text(
                          _controller.paging
                              ? 'Loading…'
                              : 'Load more tracking',
                        ),
                      ),
                  ],
                  TextButton(
                    onPressed:
                        _controller.loading ||
                            _controller.coolingDown ||
                            mutations.busy(widget.id)
                        ? null
                        : _controller.load,
                    child: const Text('Retry / refresh Order'),
                  ),
                ],
              ),
      ),
    );
  }
}
