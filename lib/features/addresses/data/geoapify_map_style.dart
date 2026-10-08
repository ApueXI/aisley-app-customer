import 'dart:convert';
import 'dart:math' as math;

/// The renderer gets only public provider configuration, never API credentials.
String geoapifyMapStyle(String publicKey) => jsonEncode({
  'version': 8,
  'sources': {
    'geoapify': {
      'type': 'raster',
      'tiles': [
        'https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png?apiKey=${Uri.encodeQueryComponent(publicKey)}',
      ],
      'tileSize': 256,
      'maxzoom': 20,
      'attribution':
          '© Geoapify | © OpenStreetMap contributors | © OpenMapTiles',
    },
  },
  'layers': [
    {
      'id': 'geoapify-map',
      'type': 'raster',
      'source': 'geoapify',
      'paint': {'raster-fade-duration': 0},
    },
  ],
});

Uri geoapifyPinTile(double latitude, double longitude, String publicKey) {
  const zoom = 16, count = 1 << zoom;
  // Web Mercator cannot project the geographic poles.
  final radians = latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
  final x = ((longitude + 180) / 360 * count).floor().clamp(0, count - 1);
  final y =
      ((1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) /
              2 *
              count)
          .floor()
          .clamp(0, count - 1);
  return Uri.https('maps.geoapify.com', '/v1/tile/osm-carto/$zoom/$x/$y.png', {
    'apiKey': publicKey,
  });
}
