import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/marketplace_widgets.dart';
import 'checkout_controller.dart';
import 'commerce_widgets.dart';
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
  final _mainKey = GlobalKey(), _actionsKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadAddresses();
    });
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
      final wide = marketplaceDesktop(context);
      return FormPage(
        title: 'Checkout',
        busy: c.placing,
        compact: true,
        maxWidth: 1200,
        bottomBar: !wide && (c.intent != null || c.pending != null)
            ? PurchaseBar(child: _actions())
            : null,
        children: [
          if (c.pending != null) ...[
            const Text(
              'Your order is not yet confirmed',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'Check the original request before placing another order. You can return to this page during this session. Closing the app loses this recovery record.',
            ),
            if (c.error != null)
              Semantics(liveRegion: true, child: Text(c.error!)),
            if (c.placing)
              const LinearProgressIndicator(
                semanticsLabel: 'Checking placement',
              ),
            if (wide) _actions(),
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
            if (c.loadingAddresses || c.quoting)
              const LinearProgressIndicator(semanticsLabel: 'Loading checkout'),
            if (c.error != null)
              Semantics(liveRegion: true, child: Text(c.error!)),
            for (final entry in c.fieldErrors.entries)
              Text('${_fieldLabel(entry.key)}: ${entry.value}'),
            if (c.cartChanged) ...[
              const Text(
                'Your Cart changed. Review and select its current items to continue.',
              ),
              FilledButton(
                onPressed: () => context.go('/cart'),
                child: const Text('Review Cart'),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    key: _mainKey,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _addresses(),
                      const SizedBox(height: 16),
                      const MarketSection(
                        title: 'Payment',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.payments_outlined),
                          title: Text('Cash on delivery (COD)'),
                          subtitle: Text('Pay when your order arrives.'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (c.quote != null)
                        QuoteReview(quote: c.quote!, controller: c)
                      else
                        MarketSection(
                          title: 'Order items',
                          child: Text(
                            c.intent!.mode == 'buy_now'
                                ? 'Your Buy Now selection will be checked when you review your order.'
                                : '${c.intent!.cartIds.length} selected Cart items. Review your order to confirm prices and shipping.',
                          ),
                        ),
                      if (!wide && c.quote != null) ...[
                        const SizedBox(height: 16),
                        MarketSection(
                          title: 'Order summary',
                          child: TotalsView(c.quote!.summary),
                        ),
                      ],
                      if (c.vouchers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        MarketSection(
                          title: 'Selected vouchers',
                          child: Column(
                            children: [
                              for (final selection in c.vouchers)
                                ListTile(
                                  title: const Text('Voucher selected'),
                                  subtitle: const Text(
                                    'Review your order to confirm the saving.',
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Remove selected voucher',
                                    onPressed: c.editable
                                        ? () => c.removeVoucher(
                                            selection.voucherId,
                                          )
                                        : null,
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (wide) ...[
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 320,
                    child: MarketSection(
                      title: 'Order summary',
                      child: _actions(),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      );
    },
  );

  String _fieldLabel(String key) => switch (key) {
    'address_id' => 'Delivery address',
    'payment_method' => 'Payment',
    'cart_item_ids' => 'Cart items',
    'quote_id' => 'Order review',
    _ => 'Order details',
  };

  Widget _addresses() {
    final c = _controller;
    return MarketSection(
      title: 'Delivery address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    contentPadding: EdgeInsets.zero,
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
          Wrap(
            spacing: 8,
            children: [
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    final c = _controller;
    return Column(
      key: _actionsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.pending != null)
          FilledButton(
            onPressed: c.placing || c.coolingDown || c.collision
                ? null
                : () => _place(retry: true),
            child: const Text('Retry exact placement'),
          )
        else ...[
          if (c.quote != null) ...[
            if (marketplaceDesktop(context))
              TotalsView(c.quote!.summary)
            else
              Text(
                'Total COD ${c.quote!.summary.payable.display(c.quote!.summary.currency)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 8),
            if (c.expired)
              const Text('This review expired. Review your order again.'),
          ],
          OutlinedButton(
            onPressed: c.canQuote ? c.getQuote : null,
            child: Text(c.quoting ? 'Reviewing…' : 'Review order'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: c.canPlace ? () => _place() : null,
            child: const Text('Place COD order'),
          ),
        ],
      ],
    );
  }

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
