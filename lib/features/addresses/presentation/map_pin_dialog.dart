import 'package:flutter/material.dart';

import '../../../core/ui/responsive_layout.dart';

import 'package:geolocator/geolocator.dart';

import '../../../app/app_dependencies.dart';
import '../data/map_location_service.dart';
import 'address_map_adapter.dart';
import 'address_pin_map.dart';

Future<GeoCandidate?> showAddressPinDialog({
  required BuildContext context,
  required AppDependencies dependencies,
  required String addressText,
  GeoCandidate? initial,
  AddressMapFactory mapAdapterFactory = MapLibreAddressMap.new,
}) => Navigator.of(context, rootNavigator: true).push<GeoCandidate>(
  // DialogRoute's opaque web semantics intercept the HTML map's pointer events.
  // A fullscreen page keeps the modal focus/back behavior without that overlay.
  MaterialPageRoute<GeoCandidate>(
    fullscreenDialog: true,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    builder: (_) => SafeArea(
      child: MapPinDialog(
        dependencies: dependencies,
        addressText: addressText,
        initial: initial,
        mapAdapterFactory: mapAdapterFactory,
      ),
    ),
  ),
);

class MapPinDialog extends StatefulWidget {
  const MapPinDialog({
    super.key,
    required this.dependencies,
    required this.addressText,
    this.initial,
    this.mapAdapterFactory = MapLibreAddressMap.new,
  });
  final AppDependencies dependencies;
  final String addressText;
  final GeoCandidate? initial;
  final AddressMapFactory mapAdapterFactory;

  @override
  State<MapPinDialog> createState() => _MapPinDialogState();
}

class _MapPinDialogState extends State<MapPinDialog> {
  final _latitude = TextEditingController(),
      _longitude = TextEditingController();
  GeoCandidate? _selected;
  List<GeoCandidate> _candidates = const [];
  int _epoch = 0, _recenterRevision = 0;
  bool _busy = false, _accessRevoked = false;
  String? _error;

  bool get _allowed => !_accessRevoked && widget.dependencies.session.active;

  @override
  void initState() {
    super.initState();
    widget.dependencies.session.registerPrivateCleanup(_clearPrivate);
    _selected = _allowed ? widget.initial : null;
    if (_selected != null) _writeCoordinates(_selected!);
  }

  @override
  void dispose() {
    widget.dependencies.session.unregisterPrivateCleanup(_clearPrivate);
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _clearPrivate() {
    _epoch++;
    _accessRevoked = true;
    _busy = false;
    _selected = null;
    _candidates = const [];
    _latitude.clear();
    _longitude.clear();
    _error = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: ShoppingPage(
      appBar: AppBar(
        title: const Text('Confirm address pin'),
        leading: IconButton(
          tooltip: 'Cancel pin',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SingleChildScrollView(
        padding: pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Finding a pin sends the reviewed street and locality to Geoapify. A pin does not confirm delivery availability.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _geocode,
              icon: const Icon(Icons.search),
              label: const Text('Find this address on the map'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _gps,
              icon: const Icon(Icons.my_location),
              label: const Text('Use current location'),
            ),
            if (_busy)
              const LinearProgressIndicator(semanticsLabel: 'Finding location'),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            if (_error != null)
              TextButton(
                onPressed: Geolocator.openAppSettings,
                child: const Text('Open location settings'),
              ),
            for (final candidate in _candidates)
              ListTile(
                title: Text(candidate.label),
                subtitle: Text('${candidate.latitude}, ${candidate.longitude}'),
                trailing: const Icon(Icons.location_on_outlined),
                onTap: () => _choose(candidate),
              ),
            if (_selected != null &&
                widget.dependencies.config.mapsEnabled) ...[
              Text(_selected!.label),
              const Text('Tap the map or drag the pin to adjust its position.'),
              const SizedBox(height: 12),
              AddressPinMap(
                key: const ValueKey('address-pin-map'),
                point: _selected!,
                locations: widget.dependencies.mapLocations!,
                adapterFactory: widget.mapAdapterFactory,
                recenterRevision: _recenterRevision,
                onSelect: (point) => _choose(point, moveCamera: false),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _latitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Latitude (−90 to 90)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _longitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Longitude (−180 to 180)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _confirm,
              child: const Text('Confirm these coordinates'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel pin'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _geocode() async {
    if (!_allowed || !widget.dependencies.config.mapsEnabled) {
      return;
    }
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final candidates = await widget.dependencies.mapLocations!.geocode(
        widget.addressText,
      );
      if (mounted && epoch == _epoch && widget.dependencies.session.active) {
        setState(() {
          _candidates = candidates;
          if (candidates.isEmpty) _error = 'No matching location was found. Try GPS or save a manual address.';
        });
      }
    } catch (_) {
      if (mounted && epoch == _epoch && widget.dependencies.session.active) {
        setState(
          () => _error = 'Address lookup is unavailable. You can save the address manually.',
        );
      }
    } finally {
      if (mounted && epoch == _epoch && widget.dependencies.session.active) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _gps() async {
    if (!_allowed || !widget.dependencies.config.mapsEnabled) {
      return;
    }
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final candidate = await widget.dependencies.mapLocations!
          .currentLocation();
      if (mounted && epoch == _epoch && widget.dependencies.session.active) {
        _choose(candidate);
      }
    } on LocationChoiceFailure catch (failure) {
      if (mounted && epoch == _epoch && widget.dependencies.session.active) {
        setState(() => _error = failure.message);
      }
    } catch (_) {
      if (mounted && epoch == _epoch && widget.dependencies.session.active) {
        setState(
          () => _error = 'Current location is unavailable. Manual saving remains available.',
        );
      }
    } finally {
      if (mounted && epoch == _epoch && widget.dependencies.session.active) {
        setState(() => _busy = false);
      }
    }
  }

  void _writeCoordinates(GeoCandidate candidate) {
    _latitude.text = candidate.latitude.toStringAsFixed(6);
    _longitude.text = candidate.longitude.toStringAsFixed(6);
  }

  void _choose(GeoCandidate candidate, {bool moveCamera = true}) {
    if (!mounted || !_allowed) return;
    setState(() {
      _selected = candidate;
      if (moveCamera) _recenterRevision++;
      _writeCoordinates(candidate);
    });
  }

  void _confirm() {
    if (!_allowed) {
      Navigator.pop(context);
      return;
    }
    final latitude = double.tryParse(_latitude.text.trim()),
        longitude = double.tryParse(_longitude.text.trim());
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      setState(
        () => _error = 'Enter a finite, valid latitude and longitude pair.',
      );
      return;
    }
    Navigator.pop(
      context,
      GeoCandidate(
        label: 'Confirmed address pin',
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }
}
