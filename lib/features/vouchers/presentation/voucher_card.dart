import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/customer_voucher.dart';
import 'voucher_collection_controller.dart';

class VoucherCard extends StatelessWidget {
  const VoucherCard({
    super.key,
    required this.voucher,
    required this.collection,
    this.allowCollect = true,
    this.details = false,
    this.overlay = true,
  });
  final CustomerVoucher voucher;
  final VoucherCollectionController collection;
  final bool allowCollect, details, overlay;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: collection,
    builder: (context, _) {
      final v = overlay ? collection.status(voucher.id) ?? voucher : voucher;
      final pending = collection.pending(v.id);
      final uncertain = collection.uncertain(v.id);
      final error = collection.errorFor(v.id);
      final action = pending
          ? 'Collecting…'
          : uncertain
          ? 'Retry collection'
          : v.collected == true
          ? 'Collected'
          : v.distribution == 'automatic'
          ? 'Available automatically'
          : 'Collect voucher';
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 4,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(v.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  v.valueLabel,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                Text(
                  v.issuer == 'app'
                      ? 'Aisley voucher'
                      : v.shop?.name ?? 'Shop unavailable',
                ),
                const Divider(),
                Text('Minimum spend ${v.minimumSpend.display(v.currency)}'),
                if (v.maximumDiscount != null)
                  Text(
                    'Maximum savings ${v.maximumDiscount!.display(v.currency)}',
                  ),
                Text(
                  'Valid ${manilaVoucherTime(v.validFrom)} to ${manilaVoucherTime(v.validUntil)} (Asia/Manila)',
                ),
                if (v.reason != null) Text(voucherReason(v.reason)),
                if (!v.supported)
                  const Text('This voucher is not supported by this app.'),
                if (v.remainingUses != null)
                  Text('${v.remainingUses} personal uses remaining'),
                if (v.terms != null && v.terms!.isNotEmpty) Text(v.terms!),
                if (details) ...[
                  Text('Code: ${v.code}'),
                  Text(
                    v.paymentMethod == null
                        ? 'Check payment eligibility at Checkout.'
                        : 'Payment: ${v.paymentMethod!.toUpperCase()}',
                  ),
                  if (v.scope.productIds.isNotEmpty ||
                      v.scope.categoryIds.isNotEmpty ||
                      v.scope.excludedProducts.isNotEmpty ||
                      v.scope.excludedCategories.isNotEmpty)
                    const Text(
                      'Selected Products or categories apply. Checkout checks qualifying items and exclusions.',
                    ),
                  const Text(
                    'Collection reserves no stock or uses. Select this voucher explicitly at Checkout; final savings are checked there. Cancellation does not restore redeemed uses.',
                  ),
                ],
                if (error != null)
                  Semantics(liveRegion: true, child: Text(error)),
                for (final entry in collection.fieldErrors.entries)
                  Text('${entry.key}: ${entry.value}'),
                if (pending)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Collecting voucher',
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed:
                          allowCollect &&
                              !collection.denied(v.id) &&
                              !pending &&
                              !collection.coolingDown &&
                              (v.collectable || uncertain)
                          ? () => collection.collect(v)
                          : null,
                      child: Text(
                        collection.coolingDown
                            ? 'Wait before collecting'
                            : action,
                      ),
                    ),
                    if (!details)
                      TextButton(
                        onPressed: () => context.push('/vouchers/${v.id}'),
                        child: const Text('Details'),
                      ),
                    if (v.shop != null && v.supported)
                      TextButton(
                        onPressed: () => context.push('/shops/${v.shop!.slug}'),
                        child: const Text('Shop now'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
