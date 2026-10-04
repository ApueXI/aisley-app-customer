import 'package:flutter/material.dart';

import '../../../core/commerce/commerce_value.dart';
import '../data/commerce_address.dart';

class TotalsView extends StatelessWidget {
  const TotalsView(this.totals, {super.key});
  final CommerceTotals totals;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Items: ${totals.merchandise.display(totals.currency)}'),
      Text('Shipping: ${totals.shipping.display(totals.currency)}'),
      Text('Item discount: ${totals.discount.display(totals.currency)}'),
      Text(
        'Shipping discount: ${totals.shippingDiscount.display(totals.currency)}',
      ),
      const SizedBox(height: 8),
      Text(
        'Payable: ${totals.payable.display(totals.currency)}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
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
