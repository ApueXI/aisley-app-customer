import '../networking/api_failure.dart';

String normalizedText(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

String? plainTextError(String? value, int limit) {
  final text = normalizedText(value ?? '');
  if (text.isEmpty) return 'Enter some text.';
  if (text.runes.length > limit) return 'Use at most $limit characters.';
  if (RegExp(
    r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]|<[^>]*>|!\[|\[[^\]]*\]\(|(^|\n)\s*(#{1,6}\s|```|>)',
  ).hasMatch(text)) {
    return 'Use plain text without markup or control characters.';
  }
  return null;
}

String checkedText(String value, int limit) {
  if (plainTextError(value, limit) != null) {
    throw const ApiFailure(FailureKind.http, status: 422);
  }
  return normalizedText(value);
}
