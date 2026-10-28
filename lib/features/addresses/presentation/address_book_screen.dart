import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/form_page.dart';
import '../../../core/ui/marketplace_surfaces.dart';
import '../data/address_models.dart';
import 'address_controller.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late final _controller = AddressController(
    widget.dependencies.session,
    widget.dependencies.addresses!,
  );
  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShoppingPage(
    appBar: AppBar(
      title: const Text('Address book'),
      actions: [
        if (!marketplaceDesktop(context)) ...marketplaceActions(context),
        IconButton(
          tooltip: 'Refresh addresses',
          onPressed: _controller.load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => ListView(
        padding: pagePadding(context),
        children: [
          const Card(
            margin: EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Address changes apply to future orders. Placed orders keep their saved address.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _open('/account/addresses/new'),
            icon: const Icon(Icons.add),
            label: const Text('Add address'),
          ),
          const SizedBox(height: 16),
          if (_controller.loading)
            const LinearProgressIndicator(semanticsLabel: 'Loading addresses'),
          if (_controller.error != null)
            Semantics(liveRegion: true, child: Text(_controller.error!)),
          if (!_controller.loading &&
              _controller.error == null &&
              _controller.addresses.isEmpty)
            const MarketEmptyState(
              icon: Icons.location_on_outlined,
              title: 'No addresses saved. Add a shipping or billing address.',
            ),
          for (final address in _controller.addresses) _address(address),
        ],
      ),
    ),
  );

  Widget _address(BuyerAddress address) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconFor(address),
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.label?.trim().isNotEmpty == true
                          ? address.label!.trim()
                          : 'Saved address',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        MarketStatusLabel(_friendlyType(address.type)),
                        if (address.isDefault)
                          const MarketStatusLabel('Default'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            address.recipientName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(address.contactNumber),
          const SizedBox(height: 8),
          Text(
            [
              address.addressLine1,
              if (address.addressLine2 != null) address.addressLine2!,
              address.barangay,
              address.cityMunicipality,
              address.province,
              address.region,
              address.postalCode,
              address.country,
            ].join(', '),
          ),
          const Divider(),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _open('/account/addresses/${address.id}'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: _controller.deletingId != null
                    ? null
                    : () => _delete(address),
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  _controller.deletingId == address.id ? 'Removing…' : 'Delete',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  IconData _iconFor(BuyerAddress address) {
    final label = address.label?.trim().toLowerCase();
    if (label == 'home') {
      return Icons.home_outlined;
    }
    if (label == 'work' || label == 'office') {
      return Icons.work_outline;
    }
    if (address.type.toLowerCase() == 'billing') {
      return Icons.receipt_long_outlined;
    }
    return Icons.location_on_outlined;
  }

  String _friendlyType(String type) {
    final value = type.trim();
    if (value.isEmpty) return 'Address';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted && widget.dependencies.session.active) await _controller.load();
  }

  Future<void> _delete(BuyerAddress address) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete address?',
      message:
          'Remove ${address.label ?? 'this address'} from your address book? Placed orders keep their saved address.',
      action: 'Delete',
    );
    if (confirmed && mounted) await _controller.delete(address.id);
  }
}
