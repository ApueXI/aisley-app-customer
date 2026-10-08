import 'package:flutter/material.dart';

import '../../../core/commerce/commerce_value.dart';
import '../data/commerce_address.dart';

class TotalsView extends StatelessWidget {
  const TotalsView(this.totals, {super.key});
  final CommerceTotals totals;
  Widget _amount(
    BuildContext context,
    String label,
    Money value, {
    bool total = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(
          '$label:',
          style: total ? Theme.of(context).textTheme.titleMedium : null,
        ),
        Text(
          value.display(totals.currency),
          style: total
              ? Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                )
              : null,
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _amount(context, 'Items', totals.merchandise),
      _amount(context, 'Shipping', totals.shipping),
      _amount(context, 'Item discount', totals.discount),
      _amount(context, 'Shipping discount', totals.shippingDiscount),
      const Divider(),
      _amount(context, 'Payable', totals.payable, total: true),
    ],
  );
}

class AddressSnapshotView extends StatelessWidget {
  const AddressSnapshotView(this.address, {super.key});
  final CommerceAddress address;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(address.recipient),
      Text(address.contact),
      Text(address.locationText),
      if (address.version != null) Text('Address version ${address.version}'),
    ],
  );
}
