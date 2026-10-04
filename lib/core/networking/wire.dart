import 'api_failure.dart';

class Wire {
  Wire(Object? value) {
    if (value is! Map<String, dynamic>) _bad();
    data = value;
  }
  late final Map<String, dynamic> data;
  Object? field(String key) {
    if (!data.containsKey(key)) _bad();
    return data[key];
  }

  String string(String key) {
    final value = field(key);
    if (value is! String) _bad();
    return value;
  }

  String? nullableString(String key) {
    final value = field(key);
    if (value != null && value is! String) _bad();
    return value as String?;
  }

  String? optionalString(String key) {
    if (!data.containsKey(key)) return null;
    return nullableString(key);
  }

  int integer(String key) {
    final value = field(key);
    if (value is! int) _bad();
    return value;
  }

  int? nullableInt(String key) {
    final value = field(key);
    if (value != null && value is! int) _bad();
    return value as int?;
  }

  double number(String key) {
    final value = field(key);
    if (value is! num || !value.isFinite) _bad();
    return value.toDouble();
  }

  double? nullableNumber(String key) {
    final value = field(key);
    if (value == null) return null;
    if (value is num && value.isFinite) return value.toDouble();
    _bad();
  }

  double? nullableCoordinate(String key) {
    final value = field(key);
    if (value == null) return null;
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    _bad();
  }

  Map<String, dynamic> object(String key) {
    final value = field(key);
    if (value is! Map<String, dynamic>) _bad();
    return value;
  }

  List<String> strings(String key) => list(key, (value) {
    if (value is! String) _bad();
    return value;
  });

  String uuid(String key) {
    final value = string(key);
    if (!RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
        .hasMatch(value)) {
      _bad();
    }
    return value;
  }

  int positiveInt(String key) {
    final value = field(key);
    if (value is! int || value < 1) _bad();
    return value;
  }

  bool boolean(String key) {
    final value = field(key);
    if (value is! bool) _bad();
    return value;
  }

  List<T> list<T>(String key, T Function(Object?) parse) {
    final value = field(key);
    if (value is! List) _bad();
    return List.unmodifiable((value).map(parse));
  }

  DateTime? timestamp(String key) {
    final value = nullableString(key);
    if (value == null) return null;
    final date = DateTime.tryParse(value);
    if (date == null || !date.isUtc) _bad();
    return date;
  }

  Never _bad() => throw const ApiFailure(FailureKind.decode);
}
