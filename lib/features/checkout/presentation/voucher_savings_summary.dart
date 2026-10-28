import 'package:flutter/material.dart';

import '../../../core/commerce/commerce_value.dart';

/// Quote and Batch savings use their own server-supplied voucher projection.
class VoucherSavingsSummary extends StatelessWidget {
  const VoucherSavingsSummary({
    super.key,
    required this.name,
    required this.code,
    required this.issuer,
    required this.benefit,
    required this.discount,
    required this.currency,
  });

  final String name, code, issuer, benefit, currency;
  final Money discount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${issuer == 'app' ? 'AISLEY' : 'Shop'} voucher',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Applied $name',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (code != name)
              Text('Code: $code', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Text(
          '${benefit == 'shipping' ? 'Shipping' : 'Merchandise'} savings: ${discount.display(currency)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
