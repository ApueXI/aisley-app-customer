import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/security/token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('secure credentials are bound to the configured API origin', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final first = SecureTokenStore(apiOrigin: 'https://first.example.invalid');
    final second = SecureTokenStore(
      apiOrigin: 'https://second.example.invalid',
    );
    await first.write('synthetic-test-token');
    expect(await second.read(), null);
    expect(await first.read(), isNotNull);
    await first.delete();
    expect(await first.read(), null);
  });
}
