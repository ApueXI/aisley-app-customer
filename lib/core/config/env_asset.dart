import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<Map<String, String>> loadEnvAsset(AssetBundle bundle) async {
  final String source;
  try {
    source = await bundle.loadString('.env', cache: false);
  } on FlutterError {
    throw const FormatException('The service configuration is unavailable.');
  }

  final values = <String, String>{};
  final keyPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  for (var line in const LineSplitter().convert(source)) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();
    final separator = line.indexOf('=');
    if (separator < 1) {
      throw const FormatException('Invalid service configuration.');
    }
    final key = line.substring(0, separator).trim();
    if (!keyPattern.hasMatch(key)) {
      throw const FormatException('Invalid service configuration.');
    }
    var value = line.substring(separator + 1).trim();
    if (value.startsWith('"') || value.startsWith("'")) {
      final closing = value.indexOf(value[0], 1);
      if (closing < 0 ||
          (value.substring(closing + 1).trim().isNotEmpty &&
              !value.substring(closing + 1).trim().startsWith('#'))) {
        throw const FormatException('Invalid service configuration.');
      }
      value = value.substring(1, closing);
    } else {
      final comment = value.indexOf(RegExp(r'(^|\s)#'));
      if (comment >= 0) value = value.substring(0, comment).trimRight();
    }
    values[key] = value.trim();
  }
  return Map.unmodifiable(values);
}
