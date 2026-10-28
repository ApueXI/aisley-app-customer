import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/marketplace_widgets.dart';
import 'checkout_controller.dart';
import 'commerce_widgets.dart';
import 'quote_review.dart';
import 'shipping_options_section.dart';
import 'pending_checkout_summary.dart';
import 'checkout_address_section.dart';

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
  bool _confirming = false;
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
      // Short viewports cannot reserve a bar with a fully visible action target.
      // Keep actions in the page scroll instead, including with an open keyboard
      // or enlarged text, so focus order follows the visible checkout content.
      final availableHeight =
          MediaQuery.sizeOf(context).height -
          MediaQuery.viewInsetsOf(context).bottom;
      final inlineActions =
          !wide &&
          (availableHeight < 500 ||
              MediaQuery.textScalerOf(context).scale(16) > 24);
      return FormPage(
        title: 'Checkout',
        busy: c.placing,
        compact: true,
        maxWidth: 1200,
        bottomBar:
            !wide && !inlineActions && (c.intent != null || c.pending != null)
            ? PurchaseBar(child: _actions())
            : null,
        children: [
          if (c.pending != null) ...[
            const MarketSection(
              title: 'Your order is not yet confirmed',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We did not receive confirmation for this placement. Do not start another order while the outcome is unclear.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Retry the same placement or Check Orders. This recovery stays in the current session; closing the app clears it.',
                  ),
                ],
              ),
            ),
            if (c.error != null)
              Semantics(liveRegion: true, child: Text(c.error!)),
            if (c.placing)
              const LinearProgressIndicator(
                semanticsLabel: 'Checking placement',
              ),
            if (c.quote case final quote?)
              PendingCheckoutSummary(
                quote: quote,
                discovery: widget.dependencies.discovery!,
              )
            else
              const Text(
                'The reviewed quote details are no longer shown, but the original placement is still held for this session.',
              ),
            if (wide || inlineActions) _actions(),
            OutlinedButton(
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
                      CheckoutAddressSection(
                        controller: c,
                        onManageAddresses: () async {
                          c.invalidateQuote();
                          await context.push('/account/addresses');
                          if (mounted) await c.loadAddresses();
                        },
                      ),
                      const SizedBox(height: 16),
                      ShippingOptionsSection(controller: c),
                      const SizedBox(height: 16),
                      if (c.quote != null)
                        QuoteReview(
                          quote: c.quote!,
                          controller: c,
                          discovery: widget.dependencies.discovery!,
                        )
                      else
                        MarketSection(
                          title: 'Order items',
                          child: Text(
                            c.intent!.mode == 'buy_now'
                                ? 'Your Buy Now selection will be checked when you review your order.'
                                : '${c.intent!.cartIds.length} selected Cart items. Review your order to confirm prices and shipping.',
                          ),
                        ),
                      const SizedBox(height: 16),
                      const MarketSection(
                        title: 'Payment method',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.payments_outlined),
                          title: Text('Cash on delivery (COD)'),
                          subtitle: Text('Pay when your order arrives.'),
                        ),
                      ),
                      if (!wide && c.quote != null) ...[
                        const SizedBox(height: 16),
                        MarketSection(
                          title: 'Order summary',
                          child: TotalsView(c.quote!.summary),
                        ),
                      ],
                      if (c.vouchers.isNotEmpty && c.quote == null) ...[
                        const SizedBox(height: 16),
                        MarketSection(
                          title: 'Selected vouchers',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${c.vouchers.length} selected ${c.vouchers.length == 1 ? 'voucher' : 'vouchers'}',
                              ),
                              const Text(
                                'Eligibility and savings appear in the next reviewed quote.',
                              ),
                              for (final selection in c.vouchers)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: c.editable
                                        ? () => c.removeVoucher(
                                            selection.voucherId,
                                          )
                                        : null,
                                    icon: const Icon(Icons.close),
                                    label: const Text(
                                      'Remove selected voucher',
                                    ),
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
            if (inlineActions) _actions(),
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
    'logistics_selections' => 'Shipping provider',
    _ => 'Order details',
  };

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
            child: Text(
              c.coolingDown
                  ? 'Wait before retrying'
                  : 'Retry the same placement',
            ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final review = OutlinedButton(
                onPressed: c.canQuote ? c.getQuote : null,
                child: Text(
                  c.quoting ? 'Reviewing…' : 'Review order',
                  textAlign: TextAlign.center,
                ),
              );
              final place = FilledButton(
                onPressed: c.canPlace && !_confirming ? () => _place() : null,
                child: const Text(
                  'Place COD order',
                  textAlign: TextAlign.center,
                ),
              );
              if (constraints.maxWidth >= 320 * catalogTextScale(context)) {
                return Row(
                  children: [
                    Expanded(child: review),
                    const SizedBox(width: 8),
                    Expanded(child: place),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [review, const SizedBox(height: 8), place],
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _place({bool retry = false}) async {
    final c = _controller;
    final reviewed = c.quote;
    if (!retry) {
      if (_confirming || !c.canPlace || reviewed == null) return;
      setState(() => _confirming = true);
      bool confirmed;
      try {
        confirmed = await confirmAction(
          context,
          title: 'Place COD order?',
          message:
              'Place ${reviewed.orderCount} Shop Orders for ${reviewed.summary.payable.display(reviewed.summary.currency)}? Pay on delivery.',
          action: 'Place order',
        );
      } finally {
        if (mounted) setState(() => _confirming = false);
      }
      if (!confirmed) return;
    }
    if (!mounted) return;
    final result = retry
        ? await c.retryPending()
        : await c.place(confirmedQuote: reviewed);
    if (mounted && result != null) context.go('/checkout/result/${result.id}');
  }
}
