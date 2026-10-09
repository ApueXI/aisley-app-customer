import 'package:flutter/material.dart';

import '../../../core/ui/marketplace_widgets.dart';
import 'checkout_controller.dart';
import 'shipping_details.dart';

class ShippingOptionsSection extends StatelessWidget {
  const ShippingOptionsSection({super.key, required this.controller});
  final CheckoutController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller, shipping = c.shipping;
    return MarketSection(
      title: 'Shipping provider',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shipping.loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading shipping options',
            ),
          if (shipping.error != null)
            Semantics(liveRegion: true, child: Text(shipping.error!)),
          if (!shipping.fresh && !shipping.loading)
            const Text(
              'Load current shipping options before reviewing your order.',
            ),
          if (shipping.fresh)
            for (final group in shipping.options!.groups) ...[
              Text(
                group.shop.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (group.options.isEmpty)
                const Text(
                  'No shipping provider can quote this Shop order right now. Try another address or retry later.',
                )
              else if (group.options.length == 1 &&
                  !shipping.needsConfirmation.contains(
                    group.shop.id.toLowerCase(),
                  ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ShippingDetails(
                    businessName: group.options.single.businessName,
                    fee: group.options.single.fee.display(),
                    routeStatus: group.options.single.routeStatus,
                  ),
                )
              else ...[
                if (shipping.needsConfirmation.contains(
                  group.shop.id.toLowerCase(),
                ))
                  const Text(
                    'Your previous provider is no longer available. Confirm a provider before reviewing again.',
                  ),
                RadioGroup<String>(
                  groupValue: shipping.selectedProvider(group),
                  onChanged: (value) {
                    if (value != null && c.editable) {
                      c.chooseProvider(group.shop.id, value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final option in group.options)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          visualDensity: VisualDensity.standard,
                          minTileHeight: 48,
                          value: option.organizationId,
                          enabled:
                              c.editable &&
                              !shipping.coolingDown &&
                              option.supported,
                          title: Text(option.businessName),
                          subtitle: Text(
                            'Shipping ${option.fee.display()}${shippingRouteMessage(option.routeStatus) == null ? '' : '\n${shippingRouteMessage(option.routeStatus)}'}',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          TextButton(
            onPressed:
                c.editable &&
                    c.addressesFresh &&
                    c.addressId != null &&
                    !c.cartChanged &&
                    !shipping.loading &&
                    !shipping.coolingDown
                ? c.loadShippingOptions
                : null,
            child: Text(
              shipping.error == null
                  ? 'Refresh shipping options'
                  : 'Retry shipping options',
            ),
          ),
        ],
      ),
    );
  }
}
