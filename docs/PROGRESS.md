# Progress

Short, dated log for the standalone Buyer Flutter project. Append implementation and actual verification here after copying the bundle. Preserve history; archive complete logs after 150 physical lines.

Current status:

- General Buyer API baseline remains `57e9eb20e569321b1c7ab7ae22265a3e5cbd7c50`; shipping now adopts `22b0a48f9575ead182d03c35ab87345711c23b90`. Supplied webapp review is `0a6aaa8096196e2c26822ac0281d5d30675511a8`; deployed revision is unidentified. G25 live/device gates and G26 media adoption remain open.
- Buyer Phases 1–5 and MapLibre address pinning with Geoapify lookup/tiles are implemented with partial acceptance. Live-account/provider credentials, installed Android/GPS/TalkBack and production signing gates remain open.
- Current shipping analysis, full Flutter suite (341 passed/42 opt-in skipped), provider accessibility, synthetic browser choice/review and Android/web release builds pass. See [shipping verification](references/shipping-selection-verification.md); older MapLibre/checkout evidence remains dated history.

Format:

```text
## YYYY-MM-DD
- Change, backend baseline, checks actually run, remaining gates.
```

---

## 2026-10-08

- Archived the complete progress log, including the MapLibre implementation and verification entry, in [PROGRESS-2026-10-08.md](logs/PROGRESS-2026-10-08.md). No historical entry was rewritten or omitted.


## 2026-10-08

- Added the [archive evidence index](logs/README.md) and taught bundle validation to resolve only dated verbatim progress archives from their original `docs/` base. Missing targets and ordinary-document links still fail validation. All eleven Python tooling tests and final bundle/spec/PSGC/Android validation pass; historical archive bytes remain unchanged.


## 2026-10-08

- Verified the user-supplied Geoapify key on `test/geoapify-live-address-maps` using only its `.env` entry under the user's explicit authorization; no key or other environment values were printed, committed or added to source. Laravel baseline remains `57e9eb20e569321b1c7ab7ae22265a3e5cbd7c50`; no application/backend/wire/dependency changes.
- Live public-landmark geocoding and raster tiles returned HTTP 200 with valid Philippine coordinates/PNG without browser headers. Isolated initial HTTP 401 rejection to `Origin: http://localhost:8766`; referrer alone succeeded. After the user added the exact allowed origin, the same Origin/referrer tile request and full live browser smoke passed.
- Added opt-in `--live-geoapify` to the existing MapLibre browser harness. Actual provider lookup/tiles, raster content without SDK errors, tap/drag, candidate recentering, retained resizing, Cancel renderer disposal and Retry pass with accessibility enabled; quota failure remains intentionally injected. Default synthetic mode also passes and blocks provider traffic. Laravel replies remain synthetic, with only the synthetic login writing to the intercepted API; no real account/private address or Laravel write was used.
- Web release build with ignored public-key configuration passed in 98.0 seconds; eleven Python tooling tests and syntax checks pass. No attached Android device was available, so native rendering/GPS/TalkBack, production key restrictions/quotas and real-account CRUD/shipping gates remain open. See [live provider evidence](references/geoapify-live-verification.md). Temporary key configuration is removed after verification; progress remains below the archive threshold.

## 2026-10-09 — Selective webapp documentation sync

- Compared `cabigan/docs-mobile-buyer-from-webapp/` with local docs on `docs/sync-buyer-webapp-contracts-2026-10-09`. Adopted Buyer API baseline remains `57e9eb20e569321b1c7ab7ae22265a3e5cbd7c50`; the supplied handoff reviews Laravel `0a6aaa8096196e2c26822ac0281d5d30675511a8`, with shipping inspected at `22b0a48` and media dated October 6. No deployed backend revision or runtime adoption is inferred.
- Imported provider options/selections/frozen intent, revised shipping projections/failures and private chat upload/processing/binding/delivery contracts. Updated matching specs, schemas, 103 operation records, 112 typed models, synthetic examples, feature status and G25/G26. Read-only client inspection confirms older shipping parsers and absent attachment actions; current shipping/media Flutter adoption stays pending.
- Preserved original dated entries/archive bytes, root/bundled instructions, SDK/package metadata, verification reports, screenshots and PSGC assets. Retained account-only recency and background session revalidation/page retention; clarified selected-only locality saving and existing live localhost map evidence. Added ordinary archive evidence forwarders and distinguished profile/Review image rules from keyed chat-media uploads.
- Documentation checks pass: all 22 Customer spec lengths/structure, JSON/embedded examples, portable links/anchors, all 103 operations against supplied current routes, 142 synthetic success examples/2,622 typed values, artifact preservation, PSGC checksums/registrations, Android boundaries and diff whitespace. See [local sync evidence](references/webapp-docs-sync-2026-10-09.md) and [validation record](references/webapp-docs-sync-validation-2026-10-09.json). No Flutter tests/builds, dependencies, application/backend edits, live API/provider requests, migrations or device operations ran. Existing installed-device, live-account, media/provider adoption and production gates stay open; Progress remains below 150 lines.

## 2026-10-09 — Checkout address accessibility

- Reproduced the historical 1440×900 checkout failure before presentation changes after isolating an adopted-contract synthetic quote fixture: seven layouts passed, one reported address semantics 824×36px. Inspection showed a 120px tile clipped by test-driven scrolling; the new control regression separately fails on unchanged presentation at 40×40px. See [checkout accessibility evidence](references/checkout-accessibility-verification.md).
- Made address radio targets explicitly padded/standard with a 48px minimum tile, preserving merged labels and native selection/focus semantics. Corrected accessibility viewport handling and moved checkout actions into the page scroll below 500px available height after reproducing keyboard-open landscape/doubled-text clipping. Added two-address, long-text, fallback-label, focus/traversal, disabled-selection, quote-invalidation and keyboard-open/close checks; review never places an order.
- Checks: accessibility plus checkout mount tests pass (38); analysis passes; formatting passes (210 files); bundle validation and diff whitespace pass. Broader checkout behavior tests retain ten shipping-fixture failures, reproduced identically against unchanged HEAD. Adopted backend remains `57e9eb20e569321b1c7ab7ae22265a3e5cbd7c50`; G25/G26, live API, installed Android/TalkBack and visual browser-focus gates remain open. No builds, live/provider requests, backend/dependency/wire changes or secret-file access. Historical reports and the existing unrelated Progress edit are preserved; Progress remains below 150 physical lines.

## 2026-10-09 — Per-Shop shipping selection (G25)

- Implemented on `feature/buyer-shipping-provider-selection`: typed authenticated options discovery, automatic reads after safe input changes, per-Shop choice, implicit single-provider fallback, empty-option blocking and explicit confirmation after a removed choice. Revised Quote/Batch projections and nullable Order provider parsing/display adopt shipping contract `22b0a48`; general baseline remains `57e9eb2`, deployed revision unverified.
- Quote changes require renewed review; frozen placement includes original provider selections/key/quote ID. Exact replay performs no rediscovery, substitution or new-key retry. Current providers/fees appear in review/results/Orders; commercially serviceable `unplanned` promises no route or delivery time. Safe provider/configuration/parcel messages and private lifecycle guards preserve server authority and G21 correction limits.
- Checks: formatting (218 files), analysis, full Flutter suite (341 passed/42 opt-in skipped), shipping/accessibility/recovery scenarios, web release (87.6s), Android release (87.9s, 91.5MB), synthetic Chromium provider-change/review and implicit-fallback journeys at localhost:8766 and bundle validation pass. All API/browser traffic was intercepted; no real commerce, provider traffic or backend changes ran. See [verification](references/shipping-selection-verification.md).
- Broader Python tooling tests retain one pre-existing stale negative-link fixture (10 pass/1 fail): an existing archive forwarder makes its supposedly missing target valid; unchanged validator and actual bundle checks pass. No attached Android target: installed Android/TalkBack, real-account multi-Shop COD/replay, deployment schema/provider configuration, production signing and G25 live/device acceptance remain open; G26 is outside this feature. Historical progress/archive bytes are preserved; Progress remains below 150 physical lines.
