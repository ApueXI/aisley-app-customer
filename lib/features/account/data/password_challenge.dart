class PasswordChallenge {
  const PasswordChallenge({
    required this.id,
    required this.maskedEmail,
    required this.expiresAt,
    required this.resendAt,
  });
  final String id, maskedEmail;
  final DateTime expiresAt, resendAt;

  factory PasswordChallenge.parse(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('Invalid password verification response.');
    }
    final id = value['challenge_id'];
    final email = value['masked_email'];
    final expiry = value['expires_at'];
    final resend = value['resend_available_at'];
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
        email is! String ||
        email.isEmpty ||
        expiry is! String ||
        resend is! String) {
      throw FormatException('Invalid password verification response.');
    }
    final expiresAt = DateTime.tryParse(expiry),
        resendAt = DateTime.tryParse(resend);
    if (expiresAt == null || resendAt == null) {
      throw FormatException('Invalid password verification timestamps.');
    }
    return PasswordChallenge(
      id: id,
      maskedEmail: email,
      expiresAt: expiresAt,
      resendAt: resendAt,
    );
  }
  bool get expired => !expiresAt.isAfter(DateTime.now());
  int get resendSeconds =>
      resendAt.difference(DateTime.now()).inMilliseconds <= 0
      ? 0
      : (resendAt.difference(DateTime.now()).inMilliseconds / 1000).ceil();
}
