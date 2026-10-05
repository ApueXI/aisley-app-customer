import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../data/address_models.dart';
import '../data/map_location_service.dart';
import 'address_controller.dart';
import 'coordinate_dialog.dart';
import 'map_pin_dialog.dart';
import 'psgc_fields.dart';

class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({
    super.key,
    required this.dependencies,
    this.addressId,
  });
  final AppDependencies dependencies;
  final String? addressId;
  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  late final _controller = AddressController(
    widget.dependencies.session,
    widget.dependencies.addresses!,
  );
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'label',
      'recipient_name',
      'contact_number',
      'address_line_1',
      'address_line_2',
      'barangay',
      'city_municipality',
      'province',
      'region',
      'postal_code',
      'country',
    ])
      key: TextEditingController(),
  };
  static const _locationKeys = [
    'address_line_1',
    'address_line_2',
    'barangay',
    'city_municipality',
    'province',
    'region',
    'postal_code',
    'country',
  ];
  String _type = 'shipping';
  bool _default = false, _dirty = false, _ready = false;
  GeoCandidate? _pin;

  @override
  void initState() {
    super.initState();
    widget.dependencies.session.registerPrivateCleanup(_clearDraft);
    _fields['country']!.text = 'Philippines';
    if (widget.addressId == null) {
      _ready = true;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    widget.dependencies.session.unregisterPrivateCleanup(_clearDraft);
    _controller.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    _pin = null;
    super.dispose();
  }

  void _clearDraft() {
    for (final field in _fields.values) {
      field.clear();
    }
    _pin = null;
    _ready = false;
    _dirty = false;
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _controller.load();
    if (!mounted) return;
    BuyerAddress? address;
    for (final row in _controller.addresses) {
      if (row.id == widget.addressId) address = row;
    }
    if (address == null) return;
    final value = address;
    final values = {
      'label': value.label ?? '',
      'recipient_name': value.recipientName,
      'contact_number': value.contactNumber,
      'address_line_1': value.addressLine1,
      'address_line_2': value.addressLine2 ?? '',
      'barangay': value.barangay,
      'city_municipality': value.cityMunicipality,
      'province': value.province,
      'region': value.region,
      'postal_code': value.postalCode,
      'country': value.country,
    };
    setState(() {
      for (final entry in values.entries) {
        _fields[entry.key]!.text = entry.value;
      }
      _type = value.type;
      _default = value.isDefault;
      _ready = true;
      if (value.latitude != null && value.longitude != null) {
        _pin = GeoCandidate(
          label: 'Saved address pin',
          latitude: value.latitude!,
          longitude: value.longitude!,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => FormPage(
      title: widget.addressId == null ? 'Add address' : 'Edit address',
      dirty: _dirty,
      busy: _controller.saving,
      children: [
        if (_controller.loading)
          const LinearProgressIndicator(semanticsLabel: 'Loading address'),
        if (_controller.error != null)
          Semantics(liveRegion: true, child: Text(_controller.error!)),
        if (!_ready && !_controller.loading) ...[
          const Text('This address is unavailable.'),
          OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ],
        if (_controller.requiresReconciliation) ...[
          const Text(
            'Review the refreshed saved addresses before submitting another change.',
          ),
          for (final address in _controller.addresses)
            Text(
              '${address.label ?? address.recipientName}: ${address.addressLine1}, ${address.cityMunicipality}',
            ),
          if (!_controller.reconciliationAvailable)
            OutlinedButton(
              onPressed: _controller.load,
              child: const Text('Refresh saved addresses'),
            ),
          if (_controller.reconciliationAvailable)
            OutlinedButton(
              onPressed: () =>
                  setState(() => _controller.requiresReconciliation = false),
              child: const Text('I reviewed the saved addresses'),
            ),
        ],
        if (_ready) ...[
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue:
                      const ['shipping', 'billing', 'both'].contains(_type)
                      ? _type
                      : null,
                  decoration: const InputDecoration(labelText: 'Address type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'shipping',
                      child: Text('Shipping'),
                    ),
                    DropdownMenuItem(value: 'billing', child: Text('Billing')),
                    DropdownMenuItem(
                      value: 'both',
                      child: Text('Shipping and billing'),
                    ),
                  ],
                  validator: (value) => value == null
                      ? 'Select a supported address type.'
                      : _controller.fieldErrors['type'],
                  onChanged: (value) => setState(() {
                    _type = value!;
                    _dirty = true;
                  }),
                ),
                _field('label', 'Label (optional)', optional: true, max: 80),
                _field('recipient_name', 'Recipient name'),
                _field(
                  'contact_number',
                  'Contact number',
                  max: 32,
                  keyboard: TextInputType.phone,
                ),
                _field('address_line_1', 'Street, house or building'),
                _field(
                  'address_line_2',
                  'Unit or additional address (optional)',
                  optional: true,
                ),
                PsgcFields(
                  initialValues: {
                    for (final key in const [
                      'region',
                      'province',
                      'city_municipality',
                      'barangay',
                    ])
                      key: _fields[key]!.text,
                  },
                  fieldErrors: _controller.fieldErrors,
                  onChange: (values) => setState(() {
                    for (final entry in values.entries) {
                      _fields[entry.key]!.text = entry.value;
                    }
                    _pin = null;
                    _dirty = true;
                  }),
                ),
                _field('postal_code', 'Postal code', max: 10),
                _field('country', 'Country'),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use as default for this address type'),
            value: _default,
            onChanged: (value) => setState(() {
              _default = value;
              _dirty = true;
            }),
          ),
          if (_pin != null) ...[
            Text('Confirmed pin: ${_pin!.latitude}, ${_pin!.longitude}'),
            TextButton(
              onPressed: () => setState(() {
                _pin = null;
                _dirty = true;
              }),
              child: const Text('Remove coordinates'),
            ),
          ],
          OutlinedButton(
            onPressed: _coordinates,
            child: const Text('Enter or edit coordinates'),
          ),
          if (widget.dependencies.config.mapsEnabled)
            OutlinedButton.icon(
              onPressed: _choosePin,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Pin location or use GPS'),
            ),
          const Text(
            'Address changes apply to your address book. Placed orders keep their address snapshot.',
          ),
          FilledButton(
            onPressed:
                _controller.saving ||
                    _controller.coolingDown ||
                    _controller.requiresReconciliation
                ? null
                : _save,
            child: Text(_controller.saving ? 'Saving…' : 'Save address'),
          ),
        ],
      ],
    ),
  );

  Widget _field(
    String key,
    String label, {
    bool optional = false,
    int max = 255,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: _fields[key],
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {
        _dirty = true;
        if (_locationKeys.contains(key)) _pin = null;
        _controller.fieldErrors = {..._controller.fieldErrors}..remove(key);
      }),
      validator: (value) =>
          (optional
              ? (value!.length > max ? 'Use at most $max characters.' : null)
              : requiredText(value, max: max)) ??
          _controller.fieldErrors[key],
    ),
  );

  Future<void> _coordinates() async {
    final pin = await showDialog<GeoCandidate>(
      context: context,
      builder: (_) => CoordinateDialog(initial: _pin),
    );
    if (mounted && pin != null && widget.dependencies.session.active) {
      setState(() {
        _pin = pin;
        _dirty = true;
      });
    }
  }

  Future<void> _choosePin() async {
    if (_locationKeys
        .where((key) => key != 'address_line_2')
        .any((key) => _fields[key]!.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete and review the address location fields first.',
          ),
        ),
      );
      return;
    }
    final pin = await showDialog<GeoCandidate>(
      context: context,
      builder: (_) => MapPinDialog(
        dependencies: widget.dependencies,
        initial: _pin,
        addressText: _locationKeys
            .map((key) => _fields[key]!.text.trim())
            .where((value) => value.isNotEmpty)
            .join(', '),
      ),
    );
    if (mounted && pin != null && widget.dependencies.session.active) {
      setState(() {
        _pin = pin;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (!validateForm(_form.currentState!)) return;
    final ok = await _controller.save(
      AddressInput(
        type: _type,
        label: _fields['label']!.text,
        recipientName: _fields['recipient_name']!.text,
        contactNumber: _fields['contact_number']!.text,
        addressLine1: _fields['address_line_1']!.text,
        addressLine2: _fields['address_line_2']!.text,
        barangay: _fields['barangay']!.text,
        cityMunicipality: _fields['city_municipality']!.text,
        province: _fields['province']!.text,
        region: _fields['region']!.text,
        postalCode: _fields['postal_code']!.text,
        country: _fields['country']!.text,
        latitude: _pin?.latitude,
        longitude: _pin?.longitude,
        isDefault: _default,
      ),
      id: widget.addressId,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _dirty = false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      context.pop();
    } else {
      validateForm(_form.currentState!);
    }
  }
}
