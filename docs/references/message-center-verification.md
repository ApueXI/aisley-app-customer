# Home search and combined Messages — 2026-10-17

Buyer implementation changes presentation and foreground HTTP refresh only. Backend adoption remains `57e9eb2` plus the recorded per-feature revisions, including Shop context `1d40b5d`; no endpoint, payload, dependency or backend configuration changes.

## Implemented behavior

- Shared-header search is explicitly enabled on Home only. Shops, Cart, Account and secondary routes omit the field and its reserved space; dedicated Search and Shop search actions remain available. Home keeps its search draft through tab switches and resizing.
- Mobile and desktop main headers place Messages beside Notifications and Terms/Privacy. The protected `/messages` read destination survives login/consent through the existing return allow-list.
- All/channel filters combine authorized Shop/Seller, Logistics and Courier previews, sorted newest first among loaded records with null times last and stable channel/UUID ties. Counterparty, channel, preview/time, textual unread and read-only states are displayed. Rows open existing channel thread routes; Account/channel shortcuts remain available.
- Channel-qualified identities, repositories, permissions, cursors and read markers remain separate. Load more traverses each selected channel independently; refresh merges first-page changes without discarding loaded pages or the reachable older cursor frontier. Repeated/no-progress cursors terminate traversal.
- One session-owned aggregate and foreground 15-second scheduler serve the header and inboxes. Focus/resume and confirmed thread reads/sends refresh authoritative totals. Overlapping requests and redundant channel inbox polling are suppressed; background, offline failures and blocked consent pause automatic work. Explicit retries remain available.
- Badge totals sum complete fresh server channel totals rather than loaded rows; confirmed zero hides the badge and display caps at 99+. Unknown/stale totals use an explicitly labeled indicator. Opening the combined list sends no read mutation. Notification/support read states remain separate.
- Partial failures retain permitted stale channel results with channel-specific feedback/retry. Scoped list denial clears that channel; denied thread previews are discarded and obsolete inbox responses cannot restore them. Identity/account loss clears private state; consent blocks protected requests and stale successes/errors cannot populate a newer account.

## Verification

Verification uses the existing locked dependencies and synthetic transport/configuration. Build copies exclude the checkout's `.env`; its contents were not read, copied or changed. Release builds use public `.example.invalid` settings and establish compilation only.

- New unit/widget cases cover aggregate totals, sorting/null timestamps, colliding channel UUIDs, independent pagination/frontiers, stale/partial/denied/offline/throttled states, overlapping requests, read/send invalidation, background races, account changes and consent. Widgets exercise all four tabs, header actions, filters/thread navigation, badge semantics, 48px controls and 320/390/600/800/1024/1440px layouts with enlarged text.
- Adjacent checks include Phase 4 contracts/thread/widgets, Shop-context controller/recovery/widgets, media, session cleanup, header focus/draft resizing and the existing responsive matrix. The landscape accessibility harness now scrolls the focused field into the resized viewport before measuring semantics, avoiding measurement of a clipped portion of the Address type control. The pre-change address-form comparison and focused corrected case were run separately.
- Commands/results and synthetic browser evidence are recorded with the final implementation entry in [Progress](../PROGRESS.md). Analyzer configuration, package pins, media adapters, uncertainty/replay rules and server consent authority are preserved.

## Executed checks

- `flutter pub get --offline --enforce-lockfile`: pass in the isolated build copy.
- `flutter analyze --no-pub`: no issues. Changed-file `dart format --output=none --set-exit-if-changed`: 31 files, zero changes.
- The command below passes all 219 cases, including 40 new tests. Final log: ignored `build/verification/messages/final-tests.log`.

```sh
flutter test --no-pub --reporter expanded \
  test/features/message_center_test.dart \
  test/features/message_center_widgets_test.dart \
  test/core/message_updates_test.dart \
  test/core/marketplace_chrome_test.dart \
  test/features/phase_4_messaging_test.dart \
  test/features/phase_4_contract_test.dart \
  test/features/phase_4_widgets_test.dart \
  test/core/foreground_visibility_test.dart \
  test/features/shop_context_controller_test.dart \
  test/features/shop_context_recovery_test.dart \
  test/features/shop_context_widgets_test.dart \
  test/core/chat_media_test.dart \
  test/core/private_media_test.dart \
  test/core/session_controller_test.dart \
  test/features/responsive_layout_test.dart
```

- `flutter build web --no-pub` and `flutter build apk --release --no-pub`: pass with synthetic public configuration; APK 95.8 MB. Existing SDK XML/Java deprecation warnings remain. SHA-256 comparisons match all 225 Dart source/manifests/lockfiles against the build copy.
- `python3 tool/browser_message_center.py`: six synthetic layouts at localhost:8766 pass (320/390/600/800/1024/1440px), plus foreground unread 3→6, channel filters/thread navigation and partial failure/retry. All API calls are intercepted before sign-in. Reviewed 320/1440px captures; screenshots and `report.json` are ignored under `build/verification/messages/`. Temporary browser/server processes were stopped.
- Python compilation of the two affected browser scripts, `PYTHONDONTWRITEBYTECODE=1 python3 tool/verify_bundle_test.py` (four cases), `PYTHONDONTWRITEBYTECODE=1 python3 tool/verify_bundle.py` and `git diff --check`: pass. Revised Customer specs remain 227/230/228/229 physical lines.

## Skills

Applied `uncodixfy`, `dart-flutter:flutter-add-widget-test`, `dart-flutter:dart-add-unit-test` and `dart-flutter:dart-run-static-analysis`. Existing AISLEY light-only branding/design takes precedence over conflicting generic visual guidance. Tests reuse repository fakes; analysis fixes stay within this change. The custom Buyer audit/report workflow was not invoked for this direct feature request.

## Remaining acceptance

Controlled deployed/live counterpart exchange, real network reconnect/CORS/Retry-After behavior, installed Android/TalkBack and production signing remain open. No Android device was attached during verification. Foreground polling is not native push or guaranteed immediate/background delivery. Synthetic tests, browser captures and builds do not close [integration/release gates](integration-gaps.md).

## B14 — refresh supersedes active pagination — 2026-10-28

The shared `ConversationInboxController` now allows an explicit first-page refresh to start while a page append is pending. An accepted refresh advances the request epoch and clears the paging flag, so late append success, failure and completion cannot replace or clear refreshed state. Initial first-page loads remain deduplicated, append requests remain serialized, and automatic first-page refresh stays blocked while paging. A retained, nonempty first page merges rows by conversation ID and leaves both the new first-page bridge and older cursor frontier reachable. The refreshed unread total is marked fresh only if no invalidation occurred during the request. Existing session-generation and account/consent cleanup guards remain in place.

The regression adds two combined-screen widget scenarios for delayed append success and 422 failure across Shop, Logistics and Courier. They exercise automatic-refresh suppression, the actual pull gesture, fresh unread totals, retained rows/cursor frontiers, obsolete response rejection and consent cleanup. The shared test harness accepts an optional request deadline; its 200 ms default is unchanged, while these delayed-page cases use one minute. Bounded fake-time pumps wait for append and bridge requests. Existing assertions remain, including combined conversation-state checks for virtualized rows.

The first independent focused run passed `list_recovery_test.dart` 100/100, including all six original B14 cases. Its initial `message_center_test.dart` run was 19 passed / 2 failed: both new widget cases stopped before the drag because `runAsync` real-time waiting did not advance the fake-zone Dio queue, leaving no cursor request recorded (TEST-B14-WIDGET-1, a low/moderate test-harness verification gap). After explicit user approval, the Implementor corrected only test timing; its safe-copy run passed 2/2. An original-guard countercheck restored the former unconditional busy guard and removed the paging reset in a temporary copy: both new cases then failed as expected at the refresh-request assertion (6 requests instead of 9), confirming the tests detect B14. The checkout product guard was not changed for this countercheck.

Independent verification on the corrected snapshot passed. The full suite used standard test assets and no exclusions: `flutter --suppress-analytics test --no-pub --concurrency=1 --reporter expanded --timeout 60s` — 960 passed, 42 intentional skips, 0 failed in 3:23. The log is `/tmp/buyer-b14-verify.1sHWIw/full-suite.log`. Focused `message_center_test.dart` passed 23/23; focused list recovery passed 100/100. Changed-Dart formatting covered three files with zero changes, and `flutter analyze --no-pub` reported no issues in 5.4 seconds.

Synthetic-configuration builds passed earlier: web in 117.3 seconds and release APK in 171.4 seconds (64.0 MB). Product source did not change after those builds; they establish compilation, not production signing or device acceptance. Final parity across 404 safe tracked source inputs passed with SHA-256 `82029e8e162fe98f7bfc7725919ec974c8f0d5c8fad26e09d2975e4006f49b9e`.

This is a local Flutter paging/recovery correction. It changes no API route or payload, backend adoption, product UI, dependency or deployment configuration. Backend adoption remains `1858785e` plus the recorded feature slices; the deployed revision remains unknown. No live API, browser, installed Android/TalkBack or production-signing check was run for B14; those acceptance gates remain open.
