# AISLEY Buyer

AISLEY's Flutter shopping app for Customers, backed by an external Laravel API.
Browse Products and Shops, manage your account, place cash-on-delivery Orders,
and communicate with Shops, Logistics and Couriers from one app.

## Features and platforms

- Registration, sign-in, secure session restoration, recovery and policy consent.
- Home, Product/Shop search, Shop browsing, Product details, Wishlist and Recently Viewed.
- Profile, password, photo and address management, with offline PSGC address selectors and optional maps.
- Cart, Buy Now, server-priced COD checkout, vouchers, Orders and tracking, eligible cancellation and same-location recipient/contact correction.
- Separate Shop/Logistics/Courier messages, notification inbox, Product Q&A, purchase-verified reviews/photos and support tickets.
- Repeatable local verification and a documented acceptance runbook.

| Platform | Current support |
| --- | --- |
| Android | Implemented delivery target; minimum Android API 24. APK compilation is verified; installed-device acceptance remains open. |
| Web | Implemented for local browser testing at `http://localhost:8766`; production web hosting is not established. |
| iOS, macOS, Linux, Windows | Scaffold directories exist, but implementation and acceptance are not verified. |

Phases 1–4 are implemented and Phase 5 provides verification tooling. Controlled
authenticated integration, installed Android/accessibility checks and distribution
readiness remain open. Native push, online payments, returns/refunds and live Courier
GPS are deferred. See the [verification evidence](docs/references/phase-5-verification.md)
and [integration gaps](docs/references/integration-gaps.md).

## Prerequisites

- Git and **Flutter 3.47.2 stable**, which includes **Dart 3.13.2**, matching the project's verified SDK baseline. The Dart constraint is `^3.13.2`.
- For web: a browser, such as Chrome or Chromium.
- For Android: Android Studio or equivalent Android SDK tooling, compatible JDK/Gradle tooling, and an API-24-or-newer emulator or device. The project targets Java 17; use `flutter doctor -v` to diagnose toolchain compatibility.
- A reachable AISLEY Laravel API. The backend is maintained separately; this repository does not provision it. The local development API is expected on port **8000**.
- A configured storefront for recovery links; the local default is port **3000**. Coordinate recovery delivery with the backend owner.

Python 3 and Chrome/Chromium are additionally needed for the full verification runner.
Its optional browser smoke check requires Chromium and a compatible `chromedriver`
available on `PATH`.

## Clone and set up

Replace `<repository-url>` with this repository's GitHub HTTPS or SSH clone URL.
Run these commands in a terminal:

```sh
git clone <repository-url> aisley_mobile_buyer
cd aisley_mobile_buyer
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
```

Resolve doctor issues for your chosen platform before running the app. Keep the
committed `pubspec.lock`; the clone already contains the app, platform projects and
registered PSGC assets. No `flutter create` or asset-copy step is needed.

The app uses public compile-time configuration via `--dart-define`; setup does not
require copying a backend `.env` file. Coordinate API access and approved test data
with the backend owner. Every shopping screen requires an active, Admin-approved
Customer verified through `/me` and current required consent. Authentication, approval,
recovery and Terms/Privacy remain reachable before sign-in. Layouts target Android phones
and tablets in portrait, landscape and split-screen; desktop layouts are outside scope. Registration
creates a pending account; approval takes place outside Buyer.

## Run locally

Run commands below from the repository root, after the separately managed API is
available. Keep the Flutter process running while using the app; press `q` to stop it.

### Web

```sh
flutter run -d web-server --web-port 8766 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Open **http://localhost:8766** in your browser. `web-server` serves the app; open the
URL yourself. The app adds `/api/v1` to the configured API origin. The recovery
storefront defaults to `http://localhost:3000`; override `STOREFRONT_ORIGIN` when needed.

Keep the browser origin fixed at `http://localhost:8766`, even when the API uses
`127.0.0.1`. Browser secure storage is origin-bound, so changing the host or port
changes the stored session. Backend CORS must permit this exact Buyer origin,
required methods and the `Authorization`, `Content-Type` and `Idempotency-Key`
headers, and expose `Retry-After`. The Buyer origin uses bearer authentication and
must stay outside Sanctum's stateful-cookie domains. Ask the backend owner to handle
server configuration; the documented missing `Retry-After` exposure remains an open gate.

### Android emulator

Start an Android emulator through Android Studio's Device Manager, then list devices:

```sh
flutter devices
```

Replace `<android-device-id>` with the emulator's ID from that output:

```sh
flutter run -d <android-device-id>
```

Android debug defaults to `http://10.0.2.2:8000/api/v1` for the API and
`http://10.0.2.2:3000` for the storefront. In the standard Android emulator,
`10.0.2.2` reaches the development computer's localhost. Your backend must be
running and reachable there. These are debug defaults; release builds need explicit
HTTPS configuration.

### Physical Android device

Enable Developer options and USB debugging, connect your phone, accept its debugging
prompt, then run `flutter devices`. Use API/storefront HTTPS origins reachable from
the phone. Replace the `.invalid` placeholders and device ID before running:

```sh
flutter run -d <android-device-id> \
  --dart-define=API_BASE_URL=https://api.example.invalid \
  --dart-define=STOREFRONT_ORIGIN=https://shop.example.invalid
```

A phone's `localhost` refers to the phone; `10.0.2.2` is the emulator alias. Arbitrary
LAN HTTP addresses are rejected by the current configuration. Physical-device
connectivity, secure storage, native photo picking, location permissions and TalkBack
still require acceptance on the installed app.

## Configuration

Pass overrides to `flutter run` or `flutter build` using `--dart-define=NAME=value`.
Restart the run or rebuild after changing them.

| Define | Debug default | Purpose |
| --- | --- | --- |
| `API_BASE_URL` | Web: `http://localhost:8000/api/v1`; Android: `http://10.0.2.2:8000/api/v1` | Trusted API origin or full `/api/v1` base; an optional trailing slash is accepted. |
| `STOREFRONT_ORIGIN` | Web: `http://localhost:3000`; Android: `http://10.0.2.2:3000` | Trusted storefront origin for recovery and external links. |
| `MAPS_ENABLED` | `false` | Requests optional address pin/map assistance. |
| `GEOAPIFY_PUBLIC_API_KEY` | Empty | Suitable public Geoapify key; maps need both this value and `MAPS_ENABLED=true`. |

API configuration rejects unrelated paths, embedded credentials, queries and
fragments; the storefront must be an origin. HTTP is permitted only in debug for
`localhost`, `127.0.0.1` and `10.0.2.2`. Release builds require explicit HTTPS API
and storefront origins.

All build configuration is public. Keep passwords, bearer tokens, backend/storage
credentials and private map-provider keys out of defines, assets and source control.
Maps remain optional. Offline PSGC locality selectors work without maps; locality values
must be selected from the searchable lists. Recipient, contact, street/building,
unit/additional line and postal code stay editable text fields. Missing address data
shows Retry and blocks saving. See the [map requirements](docs/maps-location-api.md)
before supplying a public provider key.

## Build artifacts

For an emulator-oriented debug APK using the local defaults:

```sh
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`. For a physical phone, pass the
reachable HTTPS API/storefront defines shown above to the build command. You can
install an APK through Android tooling, for example:

```sh
adb -s <android-device-id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

For release compilation, replace both nonfunctional `.invalid` placeholders with
authorized HTTPS origins:

```sh
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.invalid \
  --dart-define=STOREFRONT_ORIGIN=https://shop.example.invalid

flutter build web \
  --dart-define=API_BASE_URL=https://api.example.invalid \
  --dart-define=STOREFRONT_ORIGIN=https://shop.example.invalid
```

Outputs: `build/app/outputs/flutter-apk/app-release.apk` and `build/web/`.
The Android release configuration currently uses **debug signing** and the example
application ID `com.example.aisley_mobile_buyer`. Production signing, application ID,
origins and outstanding acceptance gates need resolution before distribution.
The web build establishes compilation; deployment/security acceptance is separate.

## Checks and tests

Basic local checks:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
python3 tool/verify_bundle.py
```

The complete local verification runner also runs browser transport/storage tests,
tooling checks and web/release APK builds with nonfunctional HTTPS placeholders:

```sh
python3 tool/verify_release.py
```

It requires the Android build toolchain and Chrome/Chromium on `PATH`. Reports go to
ignored `build/verification/`. Exit codes are `0` for all requested checks passing,
`1` for failure and `2` for blocked prerequisites. Placeholder builds and passing
local checks do not close live/device/distribution gates.

With the API and Buyer web server already running, and Chromium/chromedriver on
`PATH`, opt into public API and browser smoke checks:

```sh
python3 tool/verify_release.py --live --browser
```

These opt-ins test public reads, denial/preflight behavior and browser navigation;
they use no real accounts or authenticated writes. The runner starts neither the
Buyer web server nor Laravel. See the [acceptance runbook](docs/references/phase-5-verification.md)
for controlled authenticated and installed-device verification.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Dependency/SDK mismatch | Confirm Flutter/Dart versions match the baseline, run doctor, then retry locked dependency resolution. |
| Android device is missing | Start the emulator or enable/authorize USB debugging; inspect `flutter devices` and doctor. |
| API requests fail | Confirm the external API is running and reachable from the chosen target. Emulator and phone addresses differ from browser addresses. |
| Browser CORS errors | Use `http://localhost:8766` and have the backend owner review exact-origin methods, headers and preflights. |
| Service configuration is unavailable | Supply valid API/storefront values; release requires both HTTPS defines. Replace example placeholders and rebuild. |
| Phone cannot reach a local HTTP API | Use reachable approved HTTPS origins; arbitrary LAN HTTP hosts are not accepted. |
| Sign-in or private actions stay blocked | Confirm Customer approval/status, current consent and storage access; registration alone does not grant access. |
| Verification exits with code 2 | Read the report for missing Chrome/Chromium, chromedriver, API or Buyer-server prerequisites. |

## Project documentation

- [Documentation index and delivery phases](docs/README.md)
- [Detailed setup and SDK/package baseline](docs/setup.md)
- [Architecture and code organization](docs/architecture.md)
- [API endpoints and contracts](docs/api/endpoints.md)
- [Verification and remaining acceptance gates](docs/verification.md)
- [Integration gaps](docs/references/integration-gaps.md)
- [Progress history](docs/PROGRESS.md)


The Buyer marketplace now adapts to Android phones/tablets and desktop browsers in the
same Flutter app. See [design](docs/design-buyer.md) and [marketplace evidence](docs/references/marketplace-verification.md).

Optional address maps use MapLibre for rendering and Geoapify for address lookup
and light raster tiles. `MAPS_ENABLED` defaults to false; enable it with an approved
`GEOAPIFY_PUBLIC_API_KEY`. Coordinate entry and manual address saving remain available.
See [map setup](docs/maps-location-api.md) and [verification](docs/references/maplibre-verification.md).
