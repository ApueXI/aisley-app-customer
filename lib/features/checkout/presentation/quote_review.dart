import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../vouchers/data/customer_voucher.dart';
import '../../discovery/data/discovery_repository.dart';
import '../../discovery/presentation/product_item_row.dart';

import '../../../core/ui/marketplace_widgets.dart';
import '../data/quote_models.dart';
import 'checkout_controller.dart';
import 'commerce_widgets.dart';
import 'shipping_details.dart';
import 'voucher_savings_summary.dart';

class QuoteReview extends StatelessWidget {
  const QuoteReview({
    super.key,
    required this.quote,
    required this.controller,
    required this.discovery,
  });
  final CheckoutQuote quote;
  final CheckoutController controller;
  final DiscoveryRepository discovery;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Review your COD order',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      Text('Review valid until ${quote.expiresAt.toLocal()}'),
      if (controller.expired)
        const Text(
          'This review expired. Review your order again before placing.',
        ),

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
                const SizedBox(height: 12),
                for (final item in group.items)
                  ProductBoundaryCard(
                    child: ProductItemRow(
                      imageUrl: item.imageUrl,
                      name: item.name,
                      discovery: discovery,
                      details: [
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
                ShippingDetails(
                  businessName: group.shipping.businessName,
                  fee: group.shipping.fee.display(group.totals.currency),
                  routeStatus: group.shipping.routeStatus,
                ),
                for (final voucher in group.applied)
                  VoucherSavingsSummary(
                    name: voucher.name,
                    code: voucher.code,
                    benefit: voucher.benefit,
                    discount: voucher.discount,
                    currency: group.totals.currency,
                  ),
                if (group.candidates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Available vouchers'),
                  for (final voucher in group.candidates)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(voucher.name),
                          subtitle: Text(
                            '${voucher.terms}\n${voucher.selectable ? 'Saving ${voucher.saving.display(group.totals.currency)}' : voucherReason(voucher.reason)}${voucher.saving.minorUnits == 0 ? '\nUsing this voucher can still consume its redemption limit.' : ''}',
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
                        if (voucher.reason == 'VOUCHER_NOT_CLAIMED')
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: const Icon(Icons.local_offer_outlined),
                              label: const Text('Collect voucher'),
                              onPressed: controller.editable
                                  ? () {
                                      if (controller.openVoucherCollection(
                                        voucher.id,
                                      )) {
                                        context.push('/vouchers/${voucher.id}');
                                      }
                                    }
                                  : null,
                            ),
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      Text('${quote.orderCount} separate Shop Orders'),

      const Text(
        'Pay the confirmed total on delivery. Vouchers used are not restored by cancellation.',
      ),
    ],
  );
}
