import 'package:flutter/material.dart';

import '../../checkout/presentation/commerce_widgets.dart';
import '../data/order_models.dart';

class OrderFacts extends StatelessWidget {
  const OrderFacts(this.order, {super.key});
  final BuyerOrder order;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(order.reference, style: Theme.of(context).textTheme.titleLarge),
      Text(order.shop.name),
      Text('${order.statusLabel} · ${order.groupLabel}'),
      Text('Placed ${order.placedAt.toLocal()}'),
      Text('${order.paymentMethod} · ${order.paymentStatus}'),
      const SizedBox(height: 16),
      const Text('Purchased items'),
      for (final item in order.items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item.name} × ${item.quantity}'),
              if (item.variantName != null) Text(item.variantName!),
              Text(
                item.options.map((o) => '${o.group}: ${o.value}').join(', '),
              ),
              Text(
                '${item.unitPrice.display(item.currency)} each · ${item.subtotal.display(item.currency)}',
              ),
            ],
          ),
        ),
      const Divider(),
      TotalsView(order.totals),
      for (final voucher in order.vouchers)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${voucher.code}: ${voucher.discount.display(voucher.currency ?? order.totals.currency)}\n${voucher.terms}',
          ),
        ),
      const SizedBox(height: 16),
      const Text('Delivery address snapshot'),
      AddressSnapshotView(order.address),
      const SizedBox(height: 16),
      if (order.delivery != null) ...[
        Text('Delivery: ${order.delivery!.status}'),
        if (order.delivery!.name != null)
          Text('Courier: ${order.delivery!.name}'),
        if (order.delivery!.contact != null) Text(order.delivery!.contact!),
      ],
      const Text('Live Courier map is unavailable.'),
    ],
  );
}
