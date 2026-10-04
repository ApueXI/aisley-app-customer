import 'package:flutter/material.dart';

import '../../../core/ui/form_page.dart';
import 'order_detail_controller.dart';

Future<void> confirmOrderCancellation(
  BuildContext context,
  OrderDetailController controller,
) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => _CancelOrderDialog(controller),
  );
  if (reason != null) await controller.cancel(reason);
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog(this.controller);
  final OrderDetailController controller;
  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    widget.controller.session.registerPrivateCleanup(_reason.clear);
  }

  @override
  void dispose() {
    widget.controller.session.unregisterPrivateCleanup(_reason.clear);
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller.session,
    builder: (context, _) => AlertDialog(
      title: const Text('Cancel this Order?'),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.controller.session.active
                  ? widget.controller.order?.reference ?? ''
                  : 'Access must be verified.',
            ),
            const Text(
              'This cancels only this Shop Order. Used vouchers are not restored.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              enabled: widget.controller.session.active,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
              maxLines: 3,
              validator: (value) => (value?.trim().length ?? 0) > 500
                  ? 'Use at most 500 characters.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep Order'),
        ),
        FilledButton(
          onPressed: widget.controller.session.active
              ? () {
                  if (validateForm(_form.currentState!)) {
                    Navigator.pop(context, _reason.text);
                  }
                }
              : null,
          child: const Text('Cancel Order'),
        ),
      ],
    ),
  );
}

Future<void> chooseContactCorrection(
  BuildContext context,
  OrderDetailController controller,
) async {
  await controller.loadAddresses();
  if (!context.mounted) return;
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AlertDialog(
        title: const Text('Correct recipient or contact'),
        scrollable: true,
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose an owned shipping address at the exact same location. Location changes are unavailable until shipping coverage and rate revalidation are resolved.',
              ),
              if (controller.addressError != null)
                Text(controller.addressError!),
              if (controller.addressesFresh && controller.addresses.isEmpty)
                const Text(
                  'No saved address has a different recipient/contact at the same verified location. Add or edit one in Address Book, then return.',
                ),
              for (final address in controller.addresses)
                ListTile(
                  title: Text(address.recipientName),
                  subtitle: Text(
                    '${address.contactNumber}\n${address.addressLine1}, ${address.barangay}, ${address.cityMunicipality}',
                  ),
                  onTap: controller.canCorrect && controller.addressesFresh
                      ? () => Navigator.pop(context, address.id)
                      : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
  if (selected == null || !context.mounted) return;
  final address = controller.addresses
      .where((a) => a.id == selected)
      .firstOrNull;
  if (address == null || !controller.canCorrect) return;
  if (await confirmAction(
    context,
    title: 'Confirm contact correction?',
    message:
        'Use ${address.recipientName} and ${address.contactNumber} for this Order at the same delivery location?',
    action: 'Confirm correction',
  )) {
    await controller.correct(address);
  }
}
