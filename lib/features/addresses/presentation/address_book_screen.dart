import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Address book'),
      actions: [
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
        padding: const EdgeInsets.all(16),
        children: [
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
            const Text(
              'No addresses saved. Add a shipping or billing address.',
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
          Text(
            address.label ?? address.recipientName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${address.type}${address.isDefault ? ' · Default' : ''}'),
          Text('${address.recipientName}\n${address.contactNumber}'),
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
          if (address.latitude != null)
            Text('Pin: ${address.latitude}, ${address.longitude}'),
          Wrap(
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
