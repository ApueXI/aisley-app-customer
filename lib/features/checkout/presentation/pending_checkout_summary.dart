import 'package:flutter/material.dart';

import '../../../core/ui/marketplace_widgets.dart';
import '../../discovery/data/discovery_repository.dart';
import '../../discovery/presentation/product_item_row.dart';
import '../data/quote_models.dart';
import 'commerce_widgets.dart';
import 'shipping_details.dart';
import 'voucher_savings_summary.dart';

/// Shows facts from the quote attached to an unresolved placement attempt.
class PendingCheckoutSummary extends StatelessWidget {
  const PendingCheckoutSummary({
    super.key,
    required this.quote,
    required this.discovery,
  });

  final CheckoutQuote quote;
  final DiscoveryRepository discovery;

  @override
  Widget build(BuildContext context) => MarketSection(
    title: 'Original placement details',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment method'),
                  Text('Cash on Delivery (COD)'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Last reviewed total'),
                  Text(
                    quote.summary.payable.display(quote.summary.currency),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'These amounts are from the reviewed quote. They do not confirm that the Order was placed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final group in quote.groups) ...[
          const Divider(height: 24),
          Text(group.shop.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in group.items)
            ProductBoundaryCard(
              child: ProductItemRow(
                imageUrl: item.imageUrl,
                name: item.name,
                discovery: discovery,
                details: [
                  Text(
                    '${item.name} × ${item.quantity}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (item.options.isNotEmpty)
                    Text(
                      item.options
                          .map((option) => '${option.group}: ${option.value}')
                          .join(', '),
                    ),
                  Text(
                    'Line subtotal: ${item.subtotal.display(group.totals.currency)}',
                  ),
                ],
              ),
            ),
          ShippingDetails(
            businessName: group.shipping.businessName,
            fee: group.shipping.fee.display(group.totals.currency),
            routeStatus: group.shipping.routeStatus,
          ),
          for (final voucher in group.applied)
            VoucherSavingsSummary(
              name: voucher.name,
              code: voucher.code,
              issuer: voucher.issuer,
              benefit: voucher.benefit,
              discount: voucher.discount,
              currency: group.totals.currency,
            ),
          TotalsView(group.totals),
        ],
      ],
    ),
  );
}
