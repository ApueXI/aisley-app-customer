import 'package:dio/dio.dart';

enum FailureKind { http, offline, timeout, decode, cancelled, storage }

class ApiFailure implements Exception {
  const ApiFailure(
    this.kind, {
    this.status,
    this.code,
    this.fields = const {},
    this.retryAt,
  });
  final FailureKind kind;
  final int? status;
  final String? code;
  final Map<String, List<String>> fields;
  final DateTime? retryAt;
  bool get uncertain =>
      kind == FailureKind.timeout ||
      kind == FailureKind.offline ||
      status != null && status! >= 500;

  bool get identityLost =>
      status == 401 ||
      status == 403 &&
          (code == 'FORBIDDEN_ROLE' ||
              const [
                'ACCOUNT_PENDING_APPROVAL',
                'ACCOUNT_REJECTED',
                'ACCOUNT_SUSPENDED',
                'ACCOUNT_INACTIVE',
              ].contains(code));

  String get description {
    if (kind == FailureKind.storage) {
      return 'Secure storage is unavailable. Please retry.';
    }
    if (kind == FailureKind.decode) {
      return 'The response could not be read. Please retry.';
    }
    if (kind == FailureKind.timeout) {
      return 'The request timed out. Its outcome may be uncertain.';
    }
    if (kind == FailureKind.offline) {
      return 'Cannot reach the service. Check your connection and retry.';
    }
    if (kind == FailureKind.cancelled) {
      return 'This request is no longer current.';
    }
    return switch (code) {
      'ACCOUNT_PENDING_APPROVAL' => 'Your registration is awaiting Admin approval. Try signing in after approval.',
      'ACCOUNT_REJECTED' =>
        'Your registration was rejected. Access is unavailable.',
      'ACCOUNT_SUSPENDED' =>
        'Your account is suspended. Access is unavailable.',
      'ACCOUNT_INACTIVE' => 'Your account is inactive. Access is unavailable.',
      'FORBIDDEN_ROLE' => 'This account cannot access Buyer features.',
      'INVALID_CREDENTIALS' => 'Check your email and password.',
      'EMAIL_ALREADY_REGISTERED' =>
        'This email is already registered. Sign in or recover your password.',
      'INVALID_RESET_TOKEN' => 'This reset link is invalid or has expired.',
      'POLICY_CONSENT_REQUIRED' =>
        'Read and accept the required policies to continue.',
      'POLICY_VERSION_STALE' =>
        'The policy changed. Read the new version and confirm again.',
      _ => switch (status) {
        401 => 'Your session has ended. Sign in again.',
        403 => 'Access to this resource is unavailable.',
        404 => 'This resource is unavailable.',
        409 => 'The information changed. Refresh before trying again.',
        422 => 'Check the highlighted fields.',
        429 => 'Too many attempts. Wait before trying again.',
        _ => 'The service is unavailable. Please retry.',
      },
    };
  }

  factory ApiFailure.response(Response<dynamic> response, DateTime now) {
    final body = response.data;
    final fields = <String, List<String>>{};
    if (body is Map && body['errors'] is Map) {
      for (final entry in (body['errors'] as Map).entries) {
        if (entry.key is String && entry.value is List) {
          // Do not surface backend values, traces or unreviewed payloads.
          fields[entry.key as String] = const ['Check this field.'];
        }
      }
    }
    final header = response.headers.value('retry-after');
    final seconds = int.tryParse(header ?? '');
    final date = header == null ? null : _httpDate(header);
    return ApiFailure(
      FailureKind.http,
      status: response.statusCode,
      code: body is Map && body['code'] is String
          ? body['code'] as String
          : null,
      fields: Map.unmodifiable(fields),
      retryAt: seconds != null && seconds >= 0
          ? now.add(Duration(seconds: seconds))
          : date,
    );
  }

  static DateTime? _httpDate(String value) {
    final match = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (match == null || !months.contains(match[2])) return null;
    return DateTime.utc(
      int.parse(match[3]!),
      months.indexOf(match[2]!) + 1,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6]!),
    );
  }

  @override
  String toString() => 'ApiFailure(${kind.name}, status: $status)';
}
