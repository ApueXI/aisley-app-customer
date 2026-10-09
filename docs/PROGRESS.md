# Progress

Short, dated log for the standalone Buyer Flutter project. Append implementation and actual verification here after copying the bundle. Preserve history; archive complete logs after 150 physical lines.

Current status:

- Adopted Buyer API baseline remains `57e9eb20e569321b1c7ab7ae22265a3e5cbd7c50`; the supplied webapp documentation reviews Laravel `0a6aaa8096196e2c26822ac0281d5d30675511a8` separately. Shipping/media adoption remains G25/G26; running/deployed revision is unidentified.
- Buyer Phases 1–5 and MapLibre address pinning with Geoapify lookup/tiles are implemented with partial acceptance. Live-account/provider credentials, installed Android/GPS/TalkBack and production signing gates remain open.
- MapLibre analysis, focused tests, synthetic browser interaction and Android/web release builds pass. The full suite retains one pre-existing desktop checkout accessibility failure; see [verification](references/maplibre-verification.md).

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
