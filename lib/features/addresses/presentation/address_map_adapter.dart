import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../data/map_location_service.dart';

typedef AddressMapFactory = AddressMapAdapter Function();

abstract interface class AddressMapAdapter {
  Future<void> prepare();
  Widget build({
    required String style,
    required GeoCandidate initial,
    required VoidCallback onReady,
    required VoidCallback onError,
    required ValueChanged<GeoCandidate> onSelect,
  });
  Future<void> setPin(GeoCandidate point, {required bool recenter});
  void dispose();
}

class MapLibreAddressMap implements AddressMapAdapter {
  MapLibreMapController? _controller;
  Symbol? _pin;
  GeoCandidate? _latest;
  bool _disposed = false, _recenter = false;
  Future<void> _updates = Future.value();
  OnFeatureDragCallback? _drag;

  @override
  Future<void> prepare() async {
    // The web library is loaded only when an enabled pin workflow needs a map.
    // Catch its load failure in the owning widget before building the platform view.
    if (kIsWeb) await MapLibreMap.ensureWebLibraryLoaded();
  }

  @override
  Widget build({
    required String style,
    required GeoCandidate initial,
    required VoidCallback onReady,
    required VoidCallback onError,
    required ValueChanged<GeoCandidate> onSelect,
  }) {
    _latest ??= initial;
    return MapLibreMap(
      styleString: style,
      initialCameraPosition: CameraPosition(
        target: LatLng(initial.latitude, initial.longitude),
        zoom: 16,
      ),
      // Native platform views must accept a pin drag inside the scrolling form.
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      annotationOrder: const [AnnotationType.symbol],
      annotationConsumeTapEvents: const [AnnotationType.symbol],
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
      onMapCreated: (controller) {
        if (_disposed) return;
        _controller = controller;
        _drag =
            (
              Point<double> position,
              LatLng origin,
              LatLng current,
              LatLng delta,
              String id,
              Annotation? annotation,
              DragEventType phase,
            ) {
              if (!_disposed &&
                  annotation == _pin &&
                  phase == DragEventType.end) {
                onSelect(_candidate(current));
              }
            };
        controller.onFeatureDrag.add(_drag!);
      },
      onStyleLoadedCallback: () => unawaited(_loadPin(onReady, onError)),
      onMapClick: (_, point) {
        if (!_disposed) onSelect(_candidate(point));
      },
    );
  }

  static GeoCandidate _candidate(LatLng point) => GeoCandidate(
    label: 'Adjusted pin',
    latitude: point.latitude,
    longitude: point.longitude,
  );

  Future<void> _loadPin(VoidCallback onReady, VoidCallback onError) async {
    final controller = _controller;
    if (_disposed || controller == null) return;
    try {
      final bytes = await _pinImage();
      if (_disposed) return;
      await controller.addImage('buyer-address-pin', bytes);
      if (_disposed) return;
      await controller.setSymbolIconAllowOverlap(true);
      await controller.setSymbolIconIgnorePlacement(true);
      if (_disposed) return;
      final point = _latest!;
      final pin = await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(point.latitude, point.longitude),
          iconImage: 'buyer-address-pin',
          iconAnchor: 'bottom',
          draggable: true,
        ),
      );
      if (_disposed) return;
      _pin = pin;
      await setPin(_latest!, recenter: _recenter);
      if (!_disposed) onReady();
    } catch (_) {
      // SDK errors can contain provider URLs. Surface only a fixed message.
      if (!_disposed) onError();
    }
  }

  @override
  Future<void> setPin(GeoCandidate point, {required bool recenter}) {
    if (_disposed) return Future.value();
    _latest = point;
    _recenter = recenter;
    final pending = _updates.then((_) async {
      final controller = _controller, pin = _pin;
      if (_disposed || controller == null || pin == null) return;
      final latest = _latest!;
      final target = LatLng(latest.latitude, latest.longitude);
      await controller.updateSymbol(pin, SymbolOptions(geometry: target));
      if (_disposed) return;
      if (_recenter) {
        _recenter = false;
        await controller.moveCamera(CameraUpdate.newLatLngZoom(target, 16));
      }
    });
    // A failed update must not poison the queue; the caller handles this failure.
    _updates = pending.catchError((Object _) {});
    return pending;
  }

  @override
  void dispose() {
    _disposed = true;
    if (_drag != null) _controller?.onFeatureDrag.remove(_drag);
    _drag = null;
    _latest = null;
    _pin = null;
    // MapLibreMap owns and disposes the controller/platform view on unmount.
    _controller = null;
  }

  static Future<Uint8List> _pinImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final path = Path()
      ..moveTo(24, 48)
      ..cubicTo(19, 39, 7, 28, 7, 18)
      ..arcToPoint(const Offset(41, 18), radius: const Radius.circular(17))
      ..cubicTo(41, 28, 29, 39, 24, 48)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFB60060));
    canvas.drawCircle(const Offset(24, 18), 6, Paint()..color = Colors.white);
    final picture = recorder.endRecording();
    final image = await picture.toImage(48, 48);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
