# AISLEY Buyer

Standalone Flutter Customer client for the external Laravel API. Phase 1 implements
authentication, secure session restoration, policy reading/consent and protected navigation.
Shopping and account-management screens remain unavailable until later phases.

See [local setup](docs/setup.md), [delivery phases](docs/README.md), and
[verification evidence and remaining gates](docs/references/phase-1-verification.md).

```sh
flutter pub get --enforce-lockfile
flutter run -d web-server --web-port 8766 --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter build apk --debug
```

Debug web uses `http://localhost:8000/api/v1`; Android emulator debug uses
`http://10.0.2.2:8000/api/v1`. The recovery storefront defaults to port 3000.
`API_BASE_URL` accepts an origin or a full `/api/v1` base; the app adds the prefix
when omitted. Open the browser at `http://localhost:8766`.
Release builds require public `API_BASE_URL` and `STOREFRONT_ORIGIN` HTTPS dart-defines.
Never place credentials in build configuration. The existing debug signing configuration
is preserved; release compilation does not establish distribution readiness.
