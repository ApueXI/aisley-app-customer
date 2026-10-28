import 'package:flutter/material.dart';

import '../../../core/ui/marketplace_widgets.dart';
import '../../../core/ui/marketplace_surfaces.dart';

import '../../checkout/presentation/commerce_widgets.dart';
import '../../checkout/presentation/shipping_details.dart';
import '../../discovery/data/discovery_repository.dart';
import '../data/order_models.dart';
import '../../discovery/presentation/product_item_row.dart';
import '../../checkout/presentation/voucher_savings_summary.dart';

class OrderFacts extends StatelessWidget {
  const OrderFacts(this.order, {super.key, required this.discovery});
  final BuyerOrder order;
  final DiscoveryRepository discovery;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MarketSection(
        title: order.shop.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ref: ${order.reference}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MarketStatusLabel(order.statusLabel),
                MarketStatusLabel(order.groupLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text('Placed ${order.placedAt.toLocal()}'),
            Text('Payment method: ${order.paymentMethod.toUpperCase()}'),
            Text('Payment status: ${order.paymentStatus}'),
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
                padding: const EdgeInsets.only(bottom: 8),
                child: ProductBoundaryCard(
                  child: ProductItemRow(
                    imageUrl: item.imageUrl,
                    name: item.name,
                    discovery: discovery,
                    details: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (item.variantName != null) Text(item.variantName!),
                      if (item.options.isNotEmpty)
                        Text(
                          item.options
                              .map((o) => '${o.group}: ${o.value}')
                              .join(', '),
                        ),
                      Text('Quantity ${item.quantity}'),
                      Text(
                        '${item.unitPrice.display(item.currency)} each · Line subtotal ${item.subtotal.display(item.currency)}',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      MarketSection(
        title: 'Payment breakdown',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TotalsView(order.totals),
            ShippingDetails(
              businessName: order.shippingProvider?.businessName,
              fee: order.totals.shipping.display(order.totals.currency),
            ),
            for (final voucher in order.vouchers) ...[
              VoucherSavingsSummary(
                name: voucher.name,
                code: voucher.code,
                issuer: voucher.issuer,
                benefit: voucher.benefit,
                discount: voucher.discount,
                currency: voucher.currency ?? order.totals.currency,
              ),
              if (voucher.terms.isNotEmpty)
                Text(
                  voucher.terms,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      MarketSection(
        title: 'Delivery details',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AddressSnapshotView(order.address),
            const SizedBox(height: 12),
            ShippingDetails(
              businessName: order.shippingProvider?.businessName,
              fee: order.totals.shipping.display(order.totals.currency),
            ),
            if (order.delivery != null) ...[
              const Divider(height: 24),
              Text('Delivery status: ${order.delivery!.status}'),
              if (order.delivery!.name != null)
                Text('Courier: ${order.delivery!.name}'),
              if (order.delivery!.contact != null)
                Text('Courier contact: ${order.delivery!.contact!}'),
            ],
          ],
        ),
      ),
    ],
  );
}
