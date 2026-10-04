import 'package:flutter/material.dart';

import '../data/map_location_service.dart';

class CoordinateDialog extends StatefulWidget {
  const CoordinateDialog({super.key, this.initial});
  final GeoCandidate? initial;
  @override
  State<CoordinateDialog> createState() => _CoordinateDialogState();
}

class _CoordinateDialogState extends State<CoordinateDialog> {
  late final _latitude = TextEditingController(
    text: widget.initial?.latitude.toString() ?? '',
  );
  late final _longitude = TextEditingController(
    text: widget.initial?.longitude.toString() ?? '',
  );
  String? _error;
  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm coordinates'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Coordinates are optional and must be entered together.'),
          TextField(
            controller: _latitude,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: const InputDecoration(labelText: 'Latitude'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _longitude,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: const InputDecoration(labelText: 'Longitude'),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _confirm, child: const Text('Confirm')),
    ],
  );
  void _confirm() {
    final lat = double.tryParse(_latitude.text.trim()),
        lon = double.tryParse(_longitude.text.trim());
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      setState(() => _error = 'Enter latitude −90…90 and longitude −180…180.');
      return;
    }
    Navigator.pop(
      context,
      GeoCandidate(
        label: 'Confirmed coordinates',
        latitude: lat,
        longitude: lon,
      ),
    );
  }
}
