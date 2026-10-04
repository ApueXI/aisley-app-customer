# Progress

Short, dated log for the standalone Buyer Flutter project. Append implementation and actual verification here after copying the bundle. Preserve history; archive complete logs after 150 physical lines.

Format:

```text
## YYYY-MM-DD
- Change, backend baseline, checks actually run, remaining gates.
```

---

## 2026-10-03

- Established a portable Buyer Flutter documentation baseline from Laravel `7b1a08a0c89d7983a0e0503c5e8d322d2c2fa2a0`, current Customer contracts/source tests and reusable Courier Flutter practices. Covers all 19 Customer areas plus notifications, policy consent and separate Logistics/Courier messaging, phased Android/local-browser guidance, API/DTO/security/upload/PSGC boundaries and integration gaps. Every Buyer Flutter screen remains pending; no Courier implementation history is imported.
- Documentation verification is recorded in `references/documentation-validation.md`. No Flutter scaffold, runtime/backend changes, migrations, seeds, dependency installs, application tests/builds, installed-device checks or live API exchange were performed. Source inspection and route enumeration do not certify mobile acceptance. The bundle remains Git-ignored/local in its originating monorepo.

## 2026-10-03

- Updated Buyer AGENTS.md to the Courier guide's structure and added features/customer/rule.md for Customer-specific contracts, WHAT/MUST/HOW and a rule requiring 200–230 physical lines that overrides the feature-spec skill's shorter preference. Existing specs remain baseline documents; all Flutter implementation/acceptance is pending. Dart source thresholds remain separate.
- Updated reading links and current location/tracking guidance: commit c5ce0cc moved this formerly ignored bundle into tracked docs/docs-mobile-buyer; the historical entries above describe its original location. Preserved the docs/cabigan ignore policy and backend baseline 7b1a08a; this revision changes no API contract.
- Documentation checks pass for portable links, root-copy paths, role/skill-precedence wording, feature coverage, pending criteria and diff whitespace. See references/documentation-validation.md for limits. No Flutter/backend/runtime/schema/dependency changes or application tests/builds/live checks ran.

## 2026-10-03

- Made the Buyer bundle a standalone Customer Flutter handoff against separately inspected checkout 57e9eb2: all 22 Customer specs now meet WHAT/MUST/HOW and 200–230 lines; shared consent, architecture/navigation/lifecycle, exact requests, 107 typed nested models, 95 operations and synthetic examples supply local implementation authority. Historical baseline/provenance and unchecked acceptance remain preserved.
- Added the Material/ChangeNotifier blueprint, pinned SDK/ten-package official metadata, Android/local-web setup on port 8766, optional reviewed Geoapify pin/GPS guidance and all 19 unchanged PSGC assets with checksums/attribution. Documented copying into docs/ and selectively merging existing root instructions; deployment origins/CORS/map inputs remain external.
- Standalone copy/link/anchor/instruction, contract/fixture/schema, source-hash, PSGC byte/manifest, history/coverage and whitespace checks pass; see references/documentation-validation.md. No backend, Flutter runtime or server configuration changed. No application/Flutter tests, builds, dependency resolution, live API or device acceptance ran; release gaps remain explicit.

## 2026-10-04

- Corrected synthetic Customer registration examples in both inventories to HTTP 201, pending/no token and request-consistent profile fields; successful active login and all other operations remain unchanged. Backend contract baseline remains 57e9eb2; no backend/live-contract reinspection occurred.
- Reconciled setup/package baseline to the existing Flutter 3.47.2 stable / Dart 3.13.2 and `^3.13.2` constraint. Preserved old SDK/package metadata as historical inspection; application SDK, dependencies, lockfile and behavior were unchanged.
- Executed SDK version verification, repository `flutter pub get --enforce-lockfile` and `flutter analyze --no-pub` successfully (no analysis issues). All ten documented pins resolved in an isolated temporary project (126 packages); JSON/semantic fixture checks and diff whitespace passed. See references/documentation-validation.md and references/package-baseline.json for scope/evidence.
- All Buyer features remain pending. No Flutter tests, feature implementation/analysis, Android/web builds, backend changes or installed-device/browser/live API acceptance ran; remaining integration gates stay open.

## 2026-10-04

- Implemented Phase 1 on `feature/buyer-phase-1-auth` against local contract baseline `57e9eb20e569321b1c7ab7ae22265a3e5cbd7c50`: light app/navigation shells, typed Customer networking/DTOs, scoped bearer login, pending registration, generic recovery/storefront handoff, secure restoration/logout and policy reading/explicit consent. Later-phase shopping/account actions remain unavailable; broad live/device acceptance criteria stay open.
- Added origin-bound secure storage with unreadable-credential failure, session generations/cancellation/private cleanup, serialized token writes/deletes, consent race handling, safe field errors and bounded public policy cache. Browser JSON Fetch omits cookies and rejects redirects; native redirects are disabled. No automatic mutation replay or plaintext token fallback. Android backup is disabled and HTTP exceptions are debug/local only.
- Locked approved Phase 1 dependencies on Flutter 3.47.2 / Dart 3.13.2. Formatting, `flutter analyze --no-pub`, 55 unit/widget tests, five Chromium transport/WebCrypto tests, five opt-in public/denial localhost API tests, isolated browser smoke, Android debug/release and web builds passed. Documentation links, Customer spec lengths (revised specs 215 lines), Android XML and whitespace checks pass. See [Phase 1 evidence](references/phase-1-verification.md) for commands, synthetic test scope and build configuration.
- Verified API `http://localhost:8000/api/v1` and Buyer `http://localhost:8766`: live public policy contracts, unauthenticated/invalid-bearer denial, exact-origin CORS and Authorization/Content-Type preflight pass. `Retry-After` is not exposed to browser code; backend-owner follow-up remains G04. Storefront port 3000 follows documented defaults but recovery delivery/page was not live-verified; running backend revision remains unidentified.
- No real credentials/accounts, live auth/consent writes, backend edits, migrations/seeds or other checkout changes. Installed Android/TalkBack/keystore and controlled live account restoration/revocation/approval/consent/switching remain gates; release builds use HTTPS placeholders and existing debug signing, so compilation does not establish distribution readiness. Progress is below the 150-line archive threshold.

## 2026-10-04

- Accepted origin-only `API_BASE_URL` on `fix/buyer-api-origin-config`: `http://127.0.0.1:8000`, root trailing slash and existing `/api/v1` bases normalize to `/api/v1` without changing the trusted origin. Other paths, credentials, queries, fragments and release HTTP remain rejected. Backend contract baseline remains `57e9eb20e569321b1c7ab7ae22265a3e5cbd7c50`; no endpoint contract or backend change.
- Updated README/setup/architecture for the Courier-style command and expanded browser smoke capture to the loopback API alias. Formatting, analysis (no issues), all 56 unit/widget tests, Python syntax, web release compilation with public HTTPS origin placeholders, documentation links and whitespace checks pass.
- Ran the exact requested `flutter run -d web-server --web-port 8766 --dart-define=API_BASE_URL=http://127.0.0.1:8000`; it served Buyer at `http://localhost:8766`. Isolated Chromium smoke passed auth/public navigation, Cart guard, live policies through the normalized loopback API, cookie/redirect settings, CORS and invalid-bearer denial. No real authentication writes; prior live-account/installed-device and Retry-After exposure gates remain open. Progress remains below the archive threshold.
