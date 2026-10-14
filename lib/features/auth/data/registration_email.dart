class RegistrationEmailChallenge {
  const RegistrationEmailChallenge({
    required this.id,
    required this.expiresAt,
    required this.resendAt,
  });
  final String id;
  final DateTime expiresAt, resendAt;
  factory RegistrationEmailChallenge.parse(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid verification response.');
    }
    final id = value['challenge_id'],
        expiry = value['expires_at'],
        resend = value['resend_available_at'];
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
        expiry is! String ||
        resend is! String) {
      throw const FormatException('Invalid verification response.');
    }
    final expiresAt = DateTime.tryParse(expiry),
        resendAt = DateTime.tryParse(resend);
    if (expiresAt == null || resendAt == null) {
      throw const FormatException('Invalid verification timestamp.');
    }
    return RegistrationEmailChallenge(
      id: id,
      expiresAt: expiresAt,
      resendAt: resendAt,
    );
  }
}

class RegistrationEmailProof {
  const RegistrationEmailProof({required this.token, required this.expiresAt});
  final String token;
  final DateTime expiresAt;
  factory RegistrationEmailProof.parse(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid email verification response.');
    }
    final token = value['email_verification_token'],
        expiry = value['expires_at'];
    if (token is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(token) ||
        expiry is! String) {
      throw const FormatException('Invalid email verification response.');
    }
    final expiresAt = DateTime.tryParse(expiry);
    if (expiresAt == null) {
      throw const FormatException('Invalid email verification expiry.');
    }
    return RegistrationEmailProof(token: token, expiresAt: expiresAt);
  }
  @override
  String toString() => 'RegistrationEmailProof';
}

abstract interface class RegistrationEmailRepository {
  Future<RegistrationEmailChallenge> requestRegistrationCode(String email);
  Future<RegistrationEmailProof> verifyRegistrationEmail(
    String email,
    String challengeId,
    String code,
  );
}
