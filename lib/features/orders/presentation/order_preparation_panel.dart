import 'package:flutter/material.dart';

import '../data/order_preparation.dart';
import 'order_detail_controller.dart';

class OrderPreparationPanel extends StatelessWidget {
  const OrderPreparationPanel({
    super.key,
    required this.preparation,
    required this.canExtend,
    required this.onExtend,
  });
  final OrderPreparation preparation;
  final bool canExtend;
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final deadline = preparation.deadlineAt;
    final local = deadline?.toLocal();
    final material = MaterialLocalizations.of(context);
    final formatted = local == null
        ? null
        : '${material.formatMediumDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seller preparation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              preparation.overdue
                  ? 'The seller has missed the preparation deadline.'
                  : 'The seller has 72 hours to prepare your parcel and request pickup.',
            ),
            if (formatted != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${preparation.extensionUsed ? 'Extended deadline' : 'Preparation deadline'}: $formatted (your local time)',
                ),
              ),
            const SizedBox(height: 8),
            Text(
              preparation.extensionUsed
                  ? preparation.overdue
                        ? 'Your one-time extension has been used. You can cancel while the parcel is still being prepared.'
                        : 'Your one-time extension has been used. Cancellation is unavailable until the extended deadline passes.'
                  : preparation.overdue
                  ? 'Give the seller another 3 days from your approval, or cancel this order. The order stays active until you decide or the seller finishes preparation.'
                  : 'Logistics waiting time does not count against the seller.',
            ),
            if (canExtend)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton(
                  onPressed: onExtend,
                  child: const Text('Extend preparation by 3 days'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmPreparationExtension(
  BuildContext context,
  OrderDetailController controller,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: controller.session,
        builder: (context, _) => AlertDialog(
          scrollable: true,
          title: Text(
            controller.session.active
                ? 'Extend preparation ${controller.order?.reference ?? ''}?'
                : 'Access must be verified.',
          ),
          content: const Text(
            'Give the seller one additional 72-hour window starting when your approval commits. You cannot cancel during this extension. If the seller misses it, you can cancel. This extension can only be used once.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Order'),
            ),
            FilledButton(
              onPressed: controller.canExtendPreparation
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Confirm 3-day extension'),
            ),
          ],
        ),
      ),
    ) ??
    false;
