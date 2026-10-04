import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/ui/form_page.dart';
import '../data/batch_models.dart';
import 'commerce_widgets.dart';

class BatchResultController extends CommerceController {
  BatchResultController(super.session, this.dependencies, this.id);
  final AppDependencies dependencies;
  final String id;
  CheckoutBatch? batch;
  bool loading = false, stale = true;
  Future<void> load() async {
    final credential = lease;
    if (credential == null || loading || coolingDown) return;
    final generation = epoch;
    loading = true;
    stale = true;
    error = null;
    notifyListeners();
    try {
      final value = await dependencies.commerce!.checkout.repository.batch(
        credential,
        id,
      );
      if (!current(generation, credential)) return;
      if (value.id != id) throw const ApiFailure(FailureKind.decode);
      batch = value;
      stale = false;
    } on ApiFailure catch (value) {
      if (current(generation, credential)) {
        if (value.status == 403 || value.status == 404) batch = null;
        failure(value);
      }
    } finally {
      if (current(generation, credential)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    batch = null;
    loading = false;
    stale = true;
  }
}

class BatchResultScreen extends StatefulWidget {
  const BatchResultScreen({
    super.key,
    required this.dependencies,
    required this.id,
  });
  final AppDependencies dependencies;
  final String id;
  @override
  State<BatchResultScreen> createState() => _BatchResultScreenState();
}

class _BatchResultScreenState extends State<BatchResultScreen> {
  late final _controller = BatchResultController(
    widget.dependencies.session,
    widget.dependencies,
    widget.id,
  );
  @override
  void initState() {
    super.initState();
    _controller.batch =
        widget.dependencies.commerce!.checkout.result?.id == widget.id
        ? widget.dependencies.commerce!.checkout.result
        : null;
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
    builder: (context, _) => FormPage(
      title: 'Checkout result',
      onCancel: () => context.go('/orders'),
      children: [
        if (_controller.loading) const LinearProgressIndicator(),
        if (_controller.error != null) Text(_controller.error!),
        if (_controller.batch != null) ...[
          const Text('Order placement confirmed'),
          if (_controller.stale)
            const Text(
              'Saved result is stale. Refresh to check current details.',
            ),
          Text('Placed ${_controller.batch!.placedAt.toLocal()}'),
          for (final order in _controller.batch!.orders)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(order.shop.name),
                    Text(order.reference),
                    Text(
                      '${order.status} · ${order.paymentMethod} · ${order.paymentStatus}',
                    ),
                    for (final item in order.items)
                      Text('${item.name} × ${item.quantity}'),
                    AddressSnapshotView(order.address),
                    TotalsView(order.totals),
                    TextButton(
                      onPressed: () => context.push('/orders/${order.id}'),
                      child: const Text('View Order'),
                    ),
                  ],
                ),
              ),
            ),
        ],
        TextButton(
          onPressed: _controller.loading || _controller.coolingDown
              ? null
              : _controller.load,
          child: const Text('Refresh result'),
        ),
        FilledButton(
          onPressed: () => context.go('/orders'),
          child: const Text('View Orders'),
        ),
      ],
    ),
  );
}
