import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import 'checkout_controller.dart';
import 'quote_review.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with WidgetsBindingObserver {
  CheckoutController get _controller => widget.dependencies.commerce!.checkout;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.loadAddresses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await widget.dependencies.session.refresh();
    if (mounted) await _controller.loadAddresses();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      if (!widget.dependencies.session.active) return const SizedBox.shrink();
      return FormPage(
        title: 'Checkout',
        busy: c.placing,
        children: [
          if (c.pending != null) ...[
            const Text('Placement outcome unresolved'),
            const Text(
              'Your reviewed request is kept for this session. Leaving this page preserves it. Closing the app loses this reconciliation record.',
            ),
            if (c.error != null)
              Semantics(liveRegion: true, child: Text(c.error!)),
            if (c.placing)
              const LinearProgressIndicator(
                semanticsLabel: 'Checking placement',
              ),
            FilledButton(
              onPressed: c.placing || c.coolingDown || c.collision
                  ? null
                  : () => _place(retry: true),
              child: const Text('Retry exact placement'),
            ),
            TextButton(
              onPressed: () => context.push('/orders'),
              child: const Text('Check Orders'),
            ),
          ] else if (c.intent == null) ...[
            const Text(
              'Choose Buy Now from a Product or select Cart items to start checkout.',
            ),
            FilledButton(
              onPressed: () => context.go('/cart'),
              child: const Text('Return to Cart'),
            ),
          ] else ...[
            Text(
              c.intent!.mode == 'buy_now'
                  ? 'Buy Now · Cart stays unchanged'
                  : 'Selected Cart checkout',
            ),
            const Text('Cash on delivery (COD)'),
            if (c.cartChanged) ...[
              const Text(
                'The Cart changed or was refreshed. Review and select its current items before continuing.',
              ),
              FilledButton(
                onPressed: () => context.go('/cart'),
                child: const Text('Review Cart'),
              ),
            ],
            if (c.loadingAddresses || c.quoting)
              const LinearProgressIndicator(semanticsLabel: 'Loading checkout'),
            if (c.error != null)
              Semantics(liveRegion: true, child: Text(c.error!)),
            for (final entry in c.fieldErrors.entries)
              Text('${entry.key}: ${entry.value}'),
            if (c.addressesFresh && c.addresses.isEmpty)
              const Text('Add a shipping address to continue.'),
            RadioGroup<String>(
              groupValue: c.addressId,
              onChanged: (value) {
                if (value != null && c.editable && c.addressesFresh) {
                  c.chooseAddress(value);
                }
              },
              child: Column(
                children: [
                  for (final address in c.addresses)
                    RadioListTile<String>(
                      title: Text(address.label ?? address.recipientName),
                      subtitle: Text(
                        '${address.recipientName} · ${address.contactNumber}\n${address.addressLine1}, ${address.barangay}, ${address.cityMunicipality}, ${address.province}, ${address.region} ${address.postalCode}, ${address.country}',
                      ),
                      value: address.id,
                      enabled: c.editable && c.addressesFresh,
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: c.editable
                  ? () async {
                      c.invalidateQuote();
                      await context.push('/account/addresses');
                      if (mounted) await c.loadAddresses();
                    }
                  : null,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Manage addresses'),
            ),
            TextButton(
              onPressed: c.loadingAddresses || !c.editable
                  ? null
                  : c.loadAddresses,
              child: const Text('Refresh addresses'),
            ),
            for (final selection in c.vouchers)
              ListTile(
                title: const Text('Selected voucher'),
                subtitle: const Text(
                  'Selection will be checked by the next quote.',
                ),
                trailing: IconButton(
                  tooltip: 'Remove selected voucher',
                  onPressed: c.editable
                      ? () => c.removeVoucher(selection.voucherId)
                      : null,
                  icon: const Icon(Icons.close),
                ),
              ),
            FilledButton(
              onPressed: c.canQuote ? c.getQuote : null,
              child: Text(c.quoting ? 'Getting quote…' : 'Get current quote'),
            ),
            if (c.quote != null) QuoteReview(quote: c.quote!, controller: c),
            FilledButton(
              onPressed: c.canPlace ? () => _place() : null,
              child: const Text('Place COD order'),
            ),
          ],
        ],
      );
    },
  );
  Future<void> _place({bool retry = false}) async {
    final c = _controller;
    if (!retry &&
        !await confirmAction(
          context,
          title: 'Place COD order?',
          message:
              'Place ${c.quote?.orderCount} Shop Orders for ${c.quote?.summary.payable.display(c.quote!.summary.currency)}? Pay on delivery.',
          action: 'Place order',
        )) {
      return;
    }
    if (!mounted) return;
    final result = retry ? await c.retryPending() : await c.place();
    if (mounted && result != null) context.go('/checkout/result/${result.id}');
  }
}
