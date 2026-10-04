# Buyer Flutter documentation bundle

Historical baseline: **`7b1a08a0c89d7983a0e0503c5e8d322d2c2fa2a0`**. New contract inspection before editing: **2026-10-03**, checkout **`57e9eb20e569321b1c7ab7ae22265a3e5cbd7c50`**. Buyer Flutter implementation: **Phases 1–4 implemented; live/device acceptance remains partial**. See [Phase 4 evidence](references/phase-4-verification.md), [Phase 3 evidence](references/phase-3-verification.md), [Phase 2 evidence](references/phase-2-verification.md) and [Phase 1 evidence](references/phase-1-verification.md).

This portable bundle defines a new standalone Flutter/Dart Customer app targeting Android, with the same application tested in a local browser. Laravel, Sanctum, PostgreSQL, and configured blob storage remain the platform backend. `customer` is the only persisted/API role; Buyer is product terminology.

Read in this order:

1. [Progress](PROGRESS.md), [agent instructions](AGENTS.md), and [Customer specification rules](features/customer/rule.md).
2. [Requirements](requirements.md), [shopping workflows](workspace.md), and [feature index](features/README.md).
3. [Fresh setup](setup.md), [architecture](architecture.md) and [Buyer design](design-buyer.md).
4. [Authentication](api/authentication.md), [endpoint inventory](api/endpoints.md), [DTOs and requests](api/contracts.md), [exact operations](api/operations.md), [typed wire models](api/field-index.md), [synthetic examples](api/examples/README.md), [errors](api/errors.md) and [messaging](api/messaging.md).
5. [Registration requirements](references/user-registration-requirements.md), [upload policy](references/file-upload-requirements.md), [Flutter upload transport](flutter-file-uploads.md), and [addresses/maps](maps-location-api.md).
6. [Integration gaps](references/integration-gaps.md), [verification](verification.md), [source provenance](references/source-provenance.md), and the specification for the feature being built.

## Delivery phases

Phase 5 local-readiness tooling and the acceptance runbook are implemented. See
[Phase 5 evidence and retained gates](references/phase-5-verification.md). Controlled
authenticated, installed-device and distribution acceptance remains open.

| Phase | Deliverables | Exit boundary |
| --- | --- | --- |
| 1 — Foundation/authentication | App composition, typed network client, configuration, secure token storage, login/register/recovery, session restoration, policy reading/consent, protected navigation | Android and fixed-origin local web compile; active Customer restoration and denial/consent cleanup verified |
| 2 — Discovery/account | Homepage, Products/Shops search, Shop browsing, Product Detail, profile/password/photo, Address Book, Wishlist, Recently Viewed | Public/private cache separation, PSGC fallback, authenticated photos, account history and account switching verified |
| 3 — Cart/checkout/orders | Cart configuration, Buy Now, quotes, voucher usage, COD placement/results, Orders/tracking, cancellation/address correction | Server totals and serviceability, immutable snapshots, uncertain placement reconciliation and same-key retries verified |
| 4 — Communication/reviews/support | Separate Shop/Logistics/Courier inboxes, notifications/preferences, Q&A, verified reviews/photos, support tickets | Cross-role replies, read markers, read-only transitions, partial uploads and safe retries verified |
| 5 — Integration/release | Live development API, installed Android, local browser, security/accessibility/permission and recovery checks | Evidence recorded against backend commit; open release gates explicitly resolved or retained |

Bazaar and MoneyFest remain deferred placeholders. Native push, payment gateways, returns/refunds, live Courier GPS, and features without an implemented API are outside the initial delivery. An available backend endpoint does not establish a Flutter screen or verified integration.

## Copying to a Flutter repository

Copy **this directory's complete contents** into the standalone repository's `docs/`. If root `AGENTS.md` is absent, copy `docs/AGENTS.md` there. If it exists, selectively merge Buyer instructions while retaining repository-specific rules; do not overwrite it. Keep the docs copy as the portable record. Its links are relative to this bundle and require no monorepo checkout.

The [documentation validation record](references/documentation-validation.md) records completed checks and their limits.

The handoff includes complete feature contracts, a concrete stable SDK/package blueprint, synthetic examples and all nineteen unchanged PSGC reference assets with attribution/checksums. The original documentation handoff included no Flutter implementation, credentials or server configuration; this repository now implements Phases 1–4 under lib/ and Phase 5 local verification tooling. Copy the assets using [setup](setup.md). Local documents supply implementation authority; upstream source paths/hashes are optional audit provenance. A missing monorepo checkout is not an implementation dependency.

Configured backend origins, approved test accounts, localhost CORS/header visibility and suitable public map credentials remain external deployment inputs. Validate live integration against the deployed backend; record material differences and actual Flutter results in Progress without rewriting the historical baseline.

This standalone repository tracks the bundle at `docs/`. Upstream relocation to
`docs/docs-mobile-buyer/` in `c5ce0cc` and the original ignored `docs/cabigan/`
location remain historical provenance. Copy the complete bundle when handing it off.

## Customer specification maintenance

Read [Customer rules](features/customer/rule.md) before creating or revising a Customer spec, including authentication. New or revised specs use WHAT/MUST/HOW and contain 200–230 physical lines; this local rule overrides the feature-spec skill's shorter length preference. All 22 Customer specs now meet the length requirement and define requests, types, states, replay and tests. Shared consent is also complete. Phases 1–4 implementation evidence is recorded separately; controlled authenticated and installed-device acceptance gates stay open.


The Buyer marketplace now adapts to Android phones/tablets and desktop browsers in the
same Flutter app. See [design](design-buyer.md) and [marketplace evidence](references/marketplace-verification.md).
