import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_dependencies.dart';
import '../data/map_location_service.dart';

class MapPinDialog extends StatefulWidget {
  const MapPinDialog({
    super.key,
    required this.dependencies,
    required this.addressText,
    this.initial,
  });
  final AppDependencies dependencies;
  final String addressText;
  final GeoCandidate? initial;

  @override
  State<MapPinDialog> createState() => _MapPinDialogState();
}

class _MapPinDialogState extends State<MapPinDialog> {
  final _map = MapController();
  final _mapKey = GlobalKey();
  final _latitude = TextEditingController(),
      _longitude = TextEditingController();
  GeoCandidate? _selected;
  List<GeoCandidate> _candidates = const [];
  int _epoch = 0;
  bool _busy = false, _tileFailed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.dependencies.session.registerPrivateCleanup(_clearPrivate);
    _selected = widget.initial;
    if (_selected != null) _writeCoordinates(_selected!);
  }

  @override
  void dispose() {
    widget.dependencies.session.unregisterPrivateCleanup(_clearPrivate);
    _map.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _clearPrivate() {
    _epoch++;
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
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Confirm address pin'),
        leading: IconButton(
          tooltip: 'Cancel pin',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
              SizedBox(
                key: _mapKey,
                height: 300,
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: LatLng(
                      _selected!.latitude,
                      _selected!.longitude,
                    ),
                    initialZoom: 16,
                    onTap: (_, point) => _choose(
                      GeoCandidate(
                        label: 'Adjusted pin',
                        latitude: point.latitude,
                        longitude: point.longitude,
                      ),
                      moveCamera: false,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png?apiKey={apiKey}',
                      additionalOptions: {
                        'apiKey':
                            widget.dependencies.config.geoapifyPublicApiKey,
                      },
                      userAgentPackageName: 'com.aisley.buyer',
                      errorTileCallback: (_, _, _) {
                        if (!_tileFailed) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _tileFailed = true);
                          });
                        }
                      },
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _selected!.latitude,
                            _selected!.longitude,
                          ),
                          width: 48,
                          height: 48,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              final box = _mapKey.currentContext
                                  ?.findRenderObject();
                              if (box is! RenderBox) return;
                              final point = _map.camera.screenOffsetToLatLng(
                                box.globalToLocal(details.globalPosition),
                              );
                              _choose(
                                GeoCandidate(
                                  label: 'Adjusted pin',
                                  latitude: point.latitude,
                                  longitude: point.longitude,
                                ),
                                moveCamera: false,
                              );
                            },
                            child: const Icon(
                              Icons.location_on,
                              size: 48,
                              color: Color(0xFFB60060),
                              semanticLabel: 'Address pin',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => _source('https://www.geoapify.com/'),
                    child: const Text('© Geoapify'),
                  ),
                  TextButton(
                    onPressed: () =>
                        _source('https://www.openstreetmap.org/copyright'),
                    child: const Text('© OpenStreetMap contributors'),
                  ),
                ],
              ),
              if (_tileFailed)
                const Text(
                  'Map tiles are unavailable. You can still review the coordinates or cancel and save a manual address.',
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
    if (!widget.dependencies.session.active ||
        !widget.dependencies.config.mapsEnabled) {
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
    if (!widget.dependencies.session.active ||
        !widget.dependencies.config.mapsEnabled) {
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
    setState(() {
      _selected = candidate;
      _writeCoordinates(candidate);
    });
    if (moveCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapKey.currentContext != null) {
          _map.move(LatLng(candidate.latitude, candidate.longitude), 16);
        }
      });
    }
  }

  void _confirm() {
    if (!widget.dependencies.session.active) {
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

  Future<void> _source(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
