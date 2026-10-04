import 'package:flutter/material.dart';

import '../data/quote_models.dart';
import 'checkout_controller.dart';
import 'commerce_widgets.dart';

class QuoteReview extends StatelessWidget {
  const QuoteReview({super.key, required this.quote, required this.controller});
  final CheckoutQuote quote;
  final CheckoutController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Review your COD order',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      Text('Quote expires ${quote.expiresAt.toLocal()}'),
      if (controller.expired)
        const Text(
          'This quote expired. Get a new quote and review it before placing.',
        ),
      AddressSnapshotView(quote.address),
      for (final group in quote.groups)
        Card(
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  group.shop.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final item in group.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.name} × ${item.quantity}'),
                        Text(
                          item.options
                              .map((o) => '${o.group}: ${o.value}')
                              .join(', '),
                        ),
                        Text(
                          '${item.unitPrice.display(group.totals.currency)} each · ${item.subtotal.display(group.totals.currency)}',
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                TotalsView(group.totals),
                Text(
                  'Serviceable shipping · Rate version ${group.shipping.version}',
                ),
                for (final voucher in group.applied)
                  Text(
                    'Applied ${voucher.code}: ${voucher.discount.display(group.totals.currency)}',
                  ),
                if (group.candidates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Available vouchers'),
                  for (final voucher in group.candidates)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(voucher.code),
                      subtitle: Text(
                        '${voucher.terms}\n${voucher.selectable ? 'Saving ${voucher.saving.display(group.totals.currency)}' : voucher.reason ?? 'Unavailable'}${voucher.saving.minorUnits == 0 ? '\nUsing this voucher can still consume its redemption limit.' : ''}',
                      ),
                      value: controller.vouchers.any(
                        (v) =>
                            v.voucherId == voucher.id &&
                            v.shopId == group.shop.id,
                      ),
                      onChanged: controller.editable && voucher.selectable
                          ? (value) => controller.chooseVoucher(
                              group,
                              CheckoutVoucherCandidate(voucher.id),
                              value == true,
                            )
                          : null,
                    ),
                ],
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      Text('${quote.orderCount} separate Shop Orders'),
      TotalsView(quote.summary),
      const Text(
        'Pay the confirmed total on delivery. Vouchers used are not restored by cancellation.',
      ),
    ],
  );
}
