import 'dart:convert';
import 'dart:io';

Map<String, dynamic> shippingScenario(String name) {
  final data = jsonDecode(
    File('docs/api/examples/shipping-selection-scenarios.json')
        .readAsStringSync(),
  ) as Map;
  return (data['scenarios'] as List).cast<Map<String, dynamic>>().singleWhere(
    (s) => s['name'] == name,
  );
}
