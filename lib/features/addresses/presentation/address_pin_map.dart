import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/geoapify_map_style.dart';
import '../data/map_location_service.dart';
import 'address_map_adapter.dart';

class AddressPinMap extends StatefulWidget {
  const AddressPinMap({
    super.key,
    required this.point,
    required this.locations,
    required this.onSelect,
    required this.recenterRevision,
    this.adapterFactory = MapLibreAddressMap.new,
  });
  final GeoCandidate point;
  final MapLocationService locations;
  final ValueChanged<GeoCandidate> onSelect;
  final int recenterRevision;
  final AddressMapFactory adapterFactory;

  @override
  State<AddressPinMap> createState() => _AddressPinMapState();
}

class _AddressPinMapState extends State<AddressPinMap> {
  AddressMapAdapter? _adapter;
  CancelToken? _tileRequest;
  Timer? _deadline;
  int _generation = 0;
  bool _prepared = false, _ready = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  bool _current(int generation) => mounted && generation == _generation;

  Future<void> _start() async {
    final generation = ++_generation;
    _prepared = _ready = _failed = false;
    final adapter = _adapter = widget.adapterFactory();
    final tileRequest = _tileRequest = CancelToken();
    _deadline = Timer(const Duration(seconds: 15), () => _fail(generation));
    try {
      final bytes = await widget.locations.pinTile(
        widget.point,
        cancelToken: tileRequest,
      );
      if (!_current(generation)) return;
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      codec.dispose();
      if (!_current(generation)) return;
      await adapter.prepare();
      if (!_current(generation)) return;
      setState(() => _prepared = true);
    } catch (_) {
      _fail(generation);
    }
  }

  @override
  void didUpdateWidget(AddressPinMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.latitude != widget.point.latitude ||
        oldWidget.point.longitude != widget.point.longitude ||
        oldWidget.recenterRevision != widget.recenterRevision) {
      final generation = _generation;
      _adapter
          ?.setPin(
            widget.point,
            recenter: oldWidget.recenterRevision != widget.recenterRevision,
          )
          .catchError((Object _) => _fail(generation));
    }
  }

  void _fail(int generation) {
    if (!_current(generation)) return;
    _stop();
    setState(() => _failed = true);
  }

  void _stop() {
    _generation++;
    _deadline?.cancel();
    _tileRequest?.cancel();
    _adapter?.dispose();
    _adapter = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_failed)
          SizedBox(
            height: 300,
            child: _prepared
                ? _adapter!.build(
                    style: geoapifyMapStyle(
                      widget.locations.config.geoapifyPublicApiKey,
                    ),
                    initial: widget.point,
                    onReady: () {
                      if (!_current(generation)) return;
                      _deadline?.cancel();
                      setState(() => _ready = true);
                    },
                    onError: () => _fail(generation),
                    onSelect: (point) {
                      if (_current(generation) &&
                          _ready &&
                          point.latitude.isFinite &&
                          point.longitude.isFinite &&
                          point.latitude.abs() <= 90 &&
                          point.longitude.abs() <= 180) {
                        widget.onSelect(point);
                      }
                    },
                  )
                : const Center(child: Text('Loading address map…')),
          ),
        if (!_failed && !_ready)
          const LinearProgressIndicator(semanticsLabel: 'Loading address map'),
        if (_failed) ...[
          Semantics(
            liveRegion: true,
            child: const Text(
              'The map is unavailable. You can still review or enter coordinates, or cancel and save a manual address.',
            ),
          ),
          OutlinedButton(
            onPressed: () {
              setState(() {});
              _start();
            },
            child: const Text('Retry map'),
          ),
        ],
        Wrap(
          children: [
            for (final source in const {
              '© Geoapify': 'https://www.geoapify.com/',
              '© OpenStreetMap contributors':
                  'https://www.openstreetmap.org/copyright',
              '© OpenMapTiles': 'https://openmaptiles.org/',
            }.entries)
              TextButton(
                onPressed: () async {
                  try {
                    await launchUrl(
                      Uri.parse(source.value),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}
                },
                child: Text(source.key),
              ),
          ],
        ),
      ],
    );
  }
}
