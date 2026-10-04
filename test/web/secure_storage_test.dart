@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/security/token_store.dart';
// Browser unit tests do not run the app's generated plugin registrant. Register
// the already locked secure-storage platform implementation explicitly.
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_web/flutter_secure_storage_web.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

@JS('eval')
external JSAny? _evaluate(JSString source);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorageWeb.registerWith(webPluginRegistrar);

  test(
    'unreadable browser credential fails closed without plaintext fallback',
    () async {
      const origin = 'https://corrupt-storage-test.example.invalid';
      final store = SecureTokenStore(apiOrigin: origin);
      addTearDown(store.delete);
      await store.write('synthetic-browser-storage-token');
      _evaluate(
        "localStorage.setItem('AisleyBuyer.buyer_bearer:https://corrupt-storage-test.example.invalid', 'AA==.AA==');"
            .toJS,
      );
      await expectLater(store.read(), throwsA(anything));
      _evaluate(
        "localStorage.setItem('AisleyBuyer.buyer_bearer:https://corrupt-storage-test.example.invalid', '!invalid!');"
            .toJS,
      );
      await expectLater(store.read(), throwsA(isA<FormatException>()));
      await store.delete();
      expect(await store.read(), null);
    },
  );

  test(
    'browser plugin encrypts, restores and deletes a synthetic credential',
    () async {
      const origin = 'https://storage-test.example.invalid';
      const token = 'synthetic-browser-storage-token';
      final store = SecureTokenStore(apiOrigin: origin);
      addTearDown(store.delete);
      await store.delete();
      await store.write(token);
      expect(await SecureTokenStore(apiOrigin: origin).read(), token);
      expect(
        (_evaluate(
          "Object.values(localStorage).every(value => !String(value).includes('synthetic-browser-storage-token'))"
              .toJS,
        ) as JSBoolean).toDart,
        true,
      );
      expect(
        await SecureTokenStore(apiOrigin: 'https://other.example.invalid')
            .read(),
        null,
      );
      await store.delete();
      expect(await store.read(), null);
    },
  );
}
