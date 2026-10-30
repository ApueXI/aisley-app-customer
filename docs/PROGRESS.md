# Buyer Flutter Progress

Short, dated implementation log. Append entries; archive complete logs after 150 physical lines. Preserve historical reports and distinguish local verification from deployed/device acceptance.

## Current status

- Buyer Phases 1–4 and Phase 5 local tooling are implemented. B14 inbox refresh supersession is implemented and locally verified; live/device acceptance remains partial. See [B14 evidence](references/message-center-verification.md).
- Current backend adoption is `1858785e` plus the recorded historical feature slices; the deployed backend revision remains unidentified.
- Live authenticated/deployed API, private-media runtime, installed Android/GPS/TalkBack, provider configuration and production signing gates remain open.
- Dated test/build/browser results remain in the archived history and the relevant feature evidence pages.

## Historical progress

- [Complete history through 2026-10-28](logs/PROGRESS-2026-10-28.md).
- [Platform history](logs/PROGRESS-2026-10-12.md): original dated results with their own execution scope.
- [Client history](logs/PROGRESS-2026-10-12-2.md): original dated results with their own execution scope.

## 2026-10-29 — Support-ticket notifications and inbox categories

- Synced the Buyer support-ticket, notification, and API contracts for safe in-app ticket alerts and role-specific category filtering. The focused Buyer suite (41 tests) and `flutter analyze --no-pub` pass; no installed device, deployed API, or Flutter build acceptance is claimed.
- Independent contract review found both Buyer and Courier parsers reject nullable redacted resource fields (TCK-NOTIF-001, P2); disposition is pending. API validation used isolated SQLite; PostgreSQL/live acceptance remains open.

## 2026-10-29 — Nullable notification destination

- Synced the Buyer API field index and DTO schema: `Notification.destination` may be null for unavailable/redacted resources and is not navigable when null. The implementation suite (42 tests), analyzer, and diff checks pass per implementor; independent retesting is running. No device, app build, deployed API, or live acceptance is claimed.

## 2026-10-29 — Independent nullable-notification retest

- Independent tester confirms Buyer accepts the saved nullable-resource reproduction with no new findings; five contract checks and one redacted list/detail/read widget check pass. No app build, environment access, live API, or device acceptance occurred. Courier retest also passed; see the main progress log for its separate result.


## 2026-10-29 — Product photos, Shop vouchers and automatic chat updates

- Removed the Home discounted-price “Was” prefix, corrected image bounds and added credential-free loading for the exact public legacy photo host evidenced in Laravel `850a73b43b3c28b058fd1502269e4ed125ca31ed`; unsupported hosts remain unavailable. Buyer backend adoption stays `1858785e` plus recorded slices; no API/backend changes were needed.
- Replaced inline Shop vouchers with a dedicated scoped page and normal Back navigation. Open Shop/Logistics/Courier threads now refresh quietly every five seconds, recover failed reads every thirty seconds and preserve drafts, pending keys and older-history position. Inbox offline recovery is bounded; session/consent/throttle/lifecycle guards remain. Compact chat styling follows Stitch, with stacked large-text controls and bounded scrolling Product context.
- [Verification](reports/buyer-fixes-verification-2026-10-29.md): final full suite **1,001 passed / 42 live-skipped / zero failures**; final Flutter analysis zero issues; all 40 changed/new Dart files formatted; web and release APK builds pass with synthetic public configuration. Bundle/spec-length/link/asset/Android and whitespace checks pass. The untouched baseline formatter issue is recorded in the report.
- [Independent design review](reports/buyer-fixes-design-2026-10-29.md): 43 synthetic screenshots reviewed across seven viewports; voucher tap/Back and a received reply without manual refresh verified. Strict Stitch fidelity **7.7/10**; four remaining visual differences are documented, so pixel identity is not claimed. The later long-context correction has focused widget coverage.
- Controlled deployed API/media/counterpart exchange, installed Android/TalkBack/real-keyboard acceptance and production configuration/signing remain open. Builds and synthetic fixtures do not close those gates.

## 2026-10-30 — Details-first Buyer registration

- Collect existing profile, email and password fields before email OTP, then explicitly submit. Preserve controllers through verification, email edits and background/resume; lock inputs during submission. Updated affected registration/auth contracts.
- Verification: 10 focused OTP/controller/widget tests pass, including simulated app-switch retention; full and final scoped analyzers and web build pass. No live API/SMTP, installed Android or release APK acceptance; process termination recovery is outside scope. Existing account approval handling is unchanged.

## 2026-10-30 — Registration birth-date picker

- Replaced typed registration birth date with a calendar picker that opens at year selection, excludes today/future dates and preserves the draft on Cancel and through email verification. Profile already uses a birthday picker; no other editable date fields were found. Updated the authentication presentation contract; backend adoption remains `1858785e` plus recorded slices.
- Verification: `flutter test --no-pub test/features/registration_email_test.dart test/features/responsive_layout_test.dart` passes all 43 tests, including picker selection/cancellation, date bounds, OTP retention and mounted responsive/accessibility checks. `flutter analyze --no-pub`, formatting of both changed Dart files, `python3 tool/verify_bundle.py` and `git diff --check` pass; the revised Customer spec remains 215 lines.
- No app builds, live API/SMTP, manual browser or installed Android/TalkBack checks were performed for this change; those acceptance gates remain open.
