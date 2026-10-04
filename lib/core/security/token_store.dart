import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({required String apiOrigin, FlutterSecureStorage? storage})
    : _key = 'buyer_bearer:$apiOrigin',
      _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            webOptions: WebOptions(
              dbName: 'AisleyBuyerStorage',
              publicKey: 'AisleyBuyer',
            ),
          );
  final FlutterSecureStorage _storage;
  final String _key;
  @override
  Future<String?> read() async {
    if (!await _storage.containsKey(key: _key)) return null;
    // Some platform implementations return null after failed decryption and
    // print diagnostics in debug mode. Keep private diagnostics out of logs and
    // distinguish an unreadable existing credential from absent credentials.
    final token = await runZoned(
      () => _storage.read(key: _key),
      zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
    );
    if (token == null || token.isEmpty) {
      throw const FormatException('Secure credential is unreadable.');
    }
    return token;
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}
