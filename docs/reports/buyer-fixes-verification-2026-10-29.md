# Buyer products, Shop vouchers and live chat — 2026-10-29

Branch: `fix/buyer-products-vouchers-live-chat`.

## Implemented behavior

- Discounted Home Product cards retain the struck-through original amount without
  the “Was” prefix. Small Home spacing/label corrections follow the selected Stitch
  reference and keep category words from splitting at normal phone widths.
- Product images retain their card/gallery constraints and fit. The public loader
  also supports the exact external photo host evidenced in the backend catalogue;
  see [the media contract](../api/catalog-media.md). External requests omit bearer
  credentials, browser cookies and redirect following; private media remains limited
  to its existing authenticated API delivery.
- The Shop storefront has one View Shop vouchers row. It opens the dedicated
  `/shops/:slug/vouchers` page using existing Shop-scoped discovery, filters,
  collection/status and pagination. Opening the storefront no longer fetches every
  available voucher. Back preserves the storefront beneath the page.
- Open Shop, Logistics and Courier threads refresh quietly every five seconds
  after the previous read finishes. Failed reads use thirty-second recovery probes;
  focus/resume shares the same guards. Drafts, field feedback, pending keys and
  cursor history survive refreshes. Writes wait for in-flight refreshes and recheck
  the original session before sending. Older readers retain their position; readers
  near the latest message follow new replies automatically. The pinned context has
  its own bounded scrolling area so long labels cannot cover the composer when
  enlarged text and the keyboard reduce available height.
- Combined inbox/header updates retain their fifteen-second cadence, with bounded
  thirty-second reads to recover idle offline channels. Session/consent, scoped
  denial, lifecycle, request overlap and Retry-After remain authoritative gates.
- Conversation presentation uses a compact image/message/Send row, purple outgoing
  bubbles, white incoming bubbles and sender/time above the body. Narrow/large-text
  layouts stack the controls. Image-only sends, upload feedback and exact retry
  remain available. Support retains its expanded composer.

No backend endpoint, schema, dependency or runtime configuration was changed.
Buyer adoption remains `1858785e` plus the recorded feature slices. The catalogue
source inspection at `850a73b43b3c28b058fd1502269e4ed125ca31ed` is evidence for
returned legacy image URLs, not a claim about the deployed backend revision.

## Verification environment

QA uses the existing Flutter 3.47.2 / Dart 3.13.2 SDK. Read-only SDK metadata is
overlaid under `/tmp/buyer-qa-flutter` where needed; isolated project copies separate
test assets from concurrent build output. Build copies exclude original `.env`
files and use newly written synthetic public configuration. No real account,
token, private upload or production environment is required for these checks.

The new regression suites cover foreground scheduling/lifecycle and overlap,
public image origin/MIME/credential/redirect rules, image bounds and replacement,
dedicated Shop voucher navigation and Back, all three channels' quiet refresh and
identity cleanup, and compact 320/390-pixel composers at normal/doubled text size.

The final application source fingerprint is
`09afa74f66728aa32277dc7e3bace45ae1aea4f12c22837ab40a1326e3450b38`.
The lead independently matched it across the checkout and the three test/build
copies (sorted `lib/**/*.dart`, `pubspec.yaml` and `pubspec.lock`, hashing each
relative path and its bytes with NUL separators). The checkout and final test copy
also share the Dart-test fingerprint
`40bff619b7b18bfdae353a1671de57872609f87bf0edf9109ad67a03e88865d6`.

| Check | Result |
| --- | --- |
| Changed/new Dart formatting, `dart format --output=none --set-exit-if-changed` | Pass, all 40 changed/new Dart files; zero formatting changes needed. |
| `flutter --suppress-analytics analyze --no-pub` | Pass, zero issues, 7.0 seconds including the final test changes. |
| Initial focused scheduler/media/shopping/chat regression | 57/57 pass. |
| Final Home/Product/voucher/upload regression | 17/17 pass. |
| Final compact composer, bounded context and upload regression | 11/11 pass, including 320/390 widths, doubled text and keyboard insets. |
| Recheck of affected contract/support/context tests after compiler load ended | 33/33 pass. |
| Full suite | Pass: 1,001 passed, 42 opt-in live tests skipped, zero failures; 2:08, exit 0. |
| `flutter --suppress-analytics build web --no-pub --no-wasm-dry-run` | Pass, 129.2 seconds, terminal exit 0. |
| `flutter --suppress-analytics build apk --release --no-pub` | Pass, 263 seconds, terminal exit 0; 96.4 MB release APK. |
| `python3 tool/verify_bundle.py` | Pass: all 22 Customer spec lengths, local links, nineteen PSGC assets/registration and Android boundaries. |
| `git diff --check` | Pass. |

The final full-suite log/status are `/tmp/buyer-qa-full-complete.log` and
`/tmp/buyer-qa-full-complete.exit`; analysis is retained in
`/tmp/buyer-qa-flutter-analyze-complete.log`.
Exact SDK wrapper commands and isolated-copy details are retained in
`/tmp/buyer-qa-runbook.md`. Final build logs are `/tmp/buyer-qa-web-final.log` and
`/tmp/buyer-qa-apk-final.log`; each has a separate terminal `.exit` record. The APK
is `/tmp/buyer-qa-source/build/app/outputs/flutter-apk/app-release.apk`, SHA-256
`eb07e5dc691640d0c12432348447d4fceadee093d8ce5cbdbaa53e5321803904`.
It uses synthetic public test configuration and certifies compilation only.

Two test assertions were corrected for lazy/duplicate rendering: the Review image
filename was below the viewport, and a context label can occur in both the pinned
card and a message. The final tests inspect the intended selected state/card and
scroll to the lazy filename. The shared communication test harness default read
deadline is five seconds, with explicit overrides still supported; its prior
200 ms wall-clock limit failed under concurrent compiler load. Production deadlines
remain unchanged and timeout behavior has separate explicit tests. No Review,
notification or backend implementation was changed to address these test issues.

The initial full formatter scan also identified the unchanged baseline
`test/core/networking_test.dart`. Its identical HEAD version fails the same format
check; it is preserved. The task's changed/new Dart files pass formatting.

## Design and acceptance boundary

The [independent design report](buyer-fixes-design-2026-10-29.md) records fresh
synthetic screenshots, Stitch comparison, scores and remaining visual differences.
Synthetic screenshots/builds do not establish exact production-photo parity.

Foreground HTTP updates provide automatic in-app delivery; they add no WebSocket,
presence, native push, offline write queue or background delivery promise.
Controlled deployed API/photo/counterpart exchange, installed Android, TalkBack,
real keyboard/device behavior and production signing remain separate open gates.
