import 'package:flutter/material.dart';

import '../../../core/ui/marketplace_widgets.dart';
import '../../../core/ui/marketplace_surfaces.dart';
import 'checkout_controller.dart';

class CheckoutAddressSection extends StatelessWidget {
  const CheckoutAddressSection({
    super.key,
    required this.controller,
    required this.onManageAddresses,
  });

  final CheckoutController controller;
  final VoidCallback onManageAddresses;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return MarketSection(
      title: 'Shipping address',
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
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: VisualDensity.standard,
                    minTileHeight: 48,
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(address.label ?? address.recipientName),
                        if (address.isDefault)
                          const MarketStatusLabel('Default'),
                      ],
                    ),
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
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: c.editable ? onManageAddresses : null,
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
}
