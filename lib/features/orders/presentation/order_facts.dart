import 'package:flutter/material.dart';

import '../../../core/ui/marketplace_widgets.dart';
import '../../../core/ui/marketplace_surfaces.dart';

import '../../checkout/presentation/commerce_widgets.dart';
import '../../checkout/presentation/shipping_details.dart';
import '../../discovery/data/discovery_repository.dart';
import '../data/order_models.dart';
import '../../discovery/presentation/product_item_row.dart';

class OrderFacts extends StatelessWidget {
  const OrderFacts(this.order, {super.key, required this.discovery});
  final BuyerOrder order;
  final DiscoveryRepository discovery;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MarketSection(
        title: order.reference,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.shop.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            MarketStatusLabel('${order.statusLabel} · ${order.groupLabel}'),
            const SizedBox(height: 8),
            Text('Placed ${order.placedAt.toLocal()}'),
            Text('${order.paymentMethod} · ${order.paymentStatus}'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      MarketSection(
        title: 'Purchased items',
        child: Column(
          children: [
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ProductItemRow(
                  imageUrl: item.imageUrl,
                  name: item.name,
                  discovery: discovery,
                  details: [
                    Text('${item.name} × ${item.quantity}'),
                    if (item.variantName != null) Text(item.variantName!),
                    Text(
                      item.options
                          .map((o) => '${o.group}: ${o.value}')
                          .join(', '),
                    ),
                    Text(
                      '${item.unitPrice.display(item.currency)} each · ${item.subtotal.display(item.currency)}',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      MarketSection(
        title: 'Order summary',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TotalsView(order.totals),
            ShippingDetails(
              businessName: order.shippingProvider?.businessName,
              fee: order.totals.shipping.display(order.totals.currency),
            ),
            for (final voucher in order.vouchers)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${voucher.code}: ${voucher.discount.display(voucher.currency ?? order.totals.currency)}\n${voucher.terms}',
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      MarketSection(
        title: 'Delivery address snapshot',
        child: AddressSnapshotView(order.address),
      ),
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
