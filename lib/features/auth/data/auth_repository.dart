import '../../../core/networking/api_client.dart';
import '../../../core/networking/wire.dart';
import 'auth_models.dart';

abstract interface class AuthRepository {
  Future<LoginResult> login(String email, String password);
  Future<RegistrationResult> register(RegistrationInput input);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confirmation,
  });
  Future<CustomerIdentity> me(SessionLease lease);
  Future<void> logout(SessionLease lease);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.client, {required this.deviceName});
  final ApiClient client;
  final String deviceName;
  static const _path = 'customer/auth/';
  @override
  Future<LoginResult> login(String email, String password) async =>
      LoginResult.parse(
        await client.request(
          'POST',
          '${_path}login',
          body: {
            'email': normalizeEmail(email),
            'password': password,
            'device_name': deviceName,
          },
        ),
      );
  @override
  Future<RegistrationResult> register(RegistrationInput input) async =>
      RegistrationResult.parse(
        await client.request('POST', '${_path}register', body: input.toJson()),
      );
  @override
  Future<void> forgotPassword(String email) async {
    Wire(
      await client.request(
        'POST',
        '${_path}forgot-password',
        body: {'email': normalizeEmail(email)},
      ),
    ).string('message');
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confirmation,
  }) async {
    Wire(
      await client.request(
        'POST',
        '${_path}reset-password',
        body: {
          'email': normalizeEmail(email),
          'token': token,
          'password': password,
          'password_confirmation': confirmation,
        },
      ),
    ).string('message');
  }

  @override
  Future<CustomerIdentity> me(SessionLease lease) async =>
      CustomerIdentity.parse(
        Wire(await client.request('GET', '${_path}me', lease: lease))
            .field('customer'),
      );
  @override
  Future<void> logout(SessionLease lease) async {
    Wire(await client.request('POST', '${_path}logout', lease: lease))
        .string('message');
  }
}
