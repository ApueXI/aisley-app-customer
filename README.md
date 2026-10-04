# AISLEY Buyer

Standalone Flutter Customer client for the external Laravel API. Phase 1 implements
authentication, secure session restoration, policy reading/consent and protected navigation.
Shopping and account-management screens remain unavailable until later phases.

See [local setup](docs/setup.md), [delivery phases](docs/README.md), and
[verification evidence and remaining gates](docs/references/phase-1-verification.md).

```sh
flutter pub get --enforce-lockfile
flutter run -d web-server --web-hostname localhost --web-port 8766
flutter build apk --debug
```

Debug web uses `http://localhost:8000/api/v1`; Android emulator debug uses
`http://10.0.2.2:8000/api/v1`. The recovery storefront defaults to port 3000.
Release builds require public `API_BASE_URL` and `STOREFRONT_ORIGIN` HTTPS dart-defines.
Never place credentials in build configuration. The existing debug signing configuration
is preserved; release compilation does not establish distribution readiness.
