---
name: buyer-review-ui
description: Audit the Buyer Flutter UI against its repository design and feature contracts, write prioritized evidence-based reports, and implement selected report findings. Use for buyer-review-ui audit/improve requests or a Buyer UI review with report-driven fixes.
---

# Buyer UI Review

Review implemented Buyer screens and shared UI, then make report-driven improvements when requested. Creating or updating this skill does not itself authorize an application audit or redesign.

## Route the request

Recognize both `$buyer-review-ui` and plain `buyer-review-ui` instructions:

```text
$buyer-review-ui audit
$buyer-review-ui audit checkout
$buyer-review-ui improve docs/reports/<audit-report>.md
$buyer-review-ui improve docs/reports/<audit-report>.md BUI-001 BUI-004
buyer-review-ui audit
buyer-review-ui improve
```

- Omitted mode means `audit`. An omitted audit scope means all implemented Buyer screens and shared UI.
- For `audit <scope>`, resolve the feature name, route or source area against current code and `docs/features/README.md`. Include shared UI and prerequisites that affect that scope; record exclusions. Ask for clarification only if the scope cannot be resolved reasonably.
- For `improve [report-path] [BUI-IDs...]`, read [references/improve.md](references/improve.md). Without a path, select the newest Buyer UI audit by its recorded timestamp and announce the path before proceeding. If none exists, request an audit first; do not silently change modes.
- For audit, read [references/audit.md](references/audit.md). Audit may write reports, sanitized evidence and required progress records; it must not change application code or apply automatic fixes.
- Finding IDs restrict improvement work to those IDs and necessary shared fixes. Without IDs, address all confirmed, actionable findings in severity order. Keep concerns and optional aesthetic suggestions outside automatic implementation.

## Establish current project authority

Read `docs/PROGRESS.md` first on every invocation. Identify actual Buyer implementation, adopted backend slices and remaining acceptance gates; do not freeze versions from this skill.

Then read applicable `AGENTS.md` files, `docs/README.md`, `docs/requirements.md`, `docs/workspace.md`, `docs/architecture.md`, `docs/setup.md`, `docs/design-buyer.md`, `docs/verification.md`, `docs/references/integration-gaps.md` and `docs/references/source-provenance.md`. Read `docs/features/customer/rule.md`, the complete applicable feature specifications and prerequisites. Use the feature index to find the existing `spec.md` or `specs.md` paths. Full audit covers specifications for every implemented feature inspected; improvement covers every affected feature, including consumers of shared fixes.

Read the applicable API authentication, endpoint, contract, field-index and messaging guides. Registration/approval needs `docs/references/user-registration-requirements.md` and current registration guidance; uploads need `docs/references/file-upload-requirements.md` and `docs/flutter-file-uploads.md`; maps/PSGC need `docs/maps-location-api.md`. Consent changes need `docs/features/shared/policy-viewing-consent/spec.md`. Local specifications, typed operations and synthetic examples supply authority without an upstream Laravel checkout. Record actual contract conflicts in the integration-gap register before enabling affected behavior.

Resolve `docs/...`, `lib/...` and `test/...` from the repository root. Resolve this skill's reference links from the skill directory. Inspect current code and tests; historical screenshots and passing commands are dated evidence, not new verification.

## Preserve Buyer boundaries

- Follow the existing light-only marketplace design. Reuse the current Material theme, typography, components and dependencies; make corrections traceable to design requirements and user impact. Avoid arbitrary redesigns or invented promotions.
- Preserve the established Flutter/Dart architecture, state ownership, routes, typed repositories, native/web adapters and backend contracts. Additional libraries, SDK/plugin installation or stack replacement require the project's prescribed approval; existing authorization still applies.
- Keep shopping behind verified `/me` identity and required consent. Preserve server-owned capabilities, prices, quotes, retry/reconciliation rules and account-scoped cleanup. Never bypass a gate to obtain an audit screenshot.
- Keep Shop, Logistics and Courier channels separate. Buyer UI work grants no other-role API, Laravel, database, deployment or other-checkout authority.
- Do not read secret-bearing `.env` files. Keep passwords, tokens, reset/OTP secrets, private chat content, complete addresses, file bytes and device credentials out of reports, logs, fixtures, screenshots and commits. Use existing synthetic data; sanitize evidence before persistence.
- Preserve previous reports and unrelated working-tree/index changes. Reports and documentation alone establish no runtime, live API or installed-device acceptance.

## Discover Flutter support when invoked

Use the current session's skill catalog and tool discovery to find Flutter plugin skills and Dart MCP capabilities. Resolve each skill through its current advertised location; never hardcode a versioned plugin installation path or make an optional MCP tool a required dependency.

Read and apply relevant available skills as needed:

| Skill | Use |
| --- | --- |
| `flutter-build-responsive-layout` | Width, text, keyboard and layout adaptation |
| `flutter-fix-layout-issues` | Constraint/overflow diagnosis and scoped correction |
| `flutter-add-widget-test` | Meaningful rendering, interaction and state-preservation regressions |
| `flutter-add-integration-test` | Justified cross-screen/device flows within existing approved tooling |
| `dart-fix-runtime-errors` | Runtime stack inspection and verification of affected behavior |
| `dart-run-static-analysis` | Analysis; automatic fixes only in improvement mode and within scope |
| `flutter-add-widget-preview` | Only if supported by the current SDK/project and useful |

In audit, use only read-only diagnostic portions of these skills. Do not run `dart fix --apply`, create tests/previews, edit drivers/configuration, or add dependencies. Inspect tool support for runtime errors, widget inspection, LSP, analysis and hot reload. Use analysis/inspection when available; after improvement changes reload/restart an attached app as supported and recheck affected runtime errors. Do not mutate a shared runtime with a pending user operation.

When MCP or an attached runtime is unavailable, use source review, available project CLI checks, existing widget tests and synthetic browser fixtures. Record each unavailable tool/check and its coverage consequence; do not install plugins or dependencies automatically. Buyer browser testing uses `http://localhost:8766`. Inspect harness flags before running; keep synthetic interception active before startup and prevent synthetic writes/credentials from reaching Laravel.

## Finish a completed audit or improvement

If report or finding-ID selection fails, explain the needed input and stop without creating placeholder reports, progress entries or application changes. A valid selected report with no actionable findings still gets the disposition report described in the improvement workflow.

Write the mode's new report, link any sanitized evidence, and state findings/statuses, commands/outcomes, blockers and remaining acceptance. Distinguish source review, automated tests, synthetic runtime, controlled live API and installed Android/TalkBack results.

Append a dated entry to `docs/PROGRESS.md` with scope, report, adopted baseline, verification and remaining gates. After each append, count physical lines. If the file exceeds 150, preserve the complete post-append file unchanged in a new `docs/logs/PROGRESS-YYYY-MM-DD.md` (unique numeric suffix on collision). Start a fresh standard header with current backend/Flutter status and a dated archive link; never overwrite an archive or rewrite history.

Follow current project branch/commit instructions, staging only relevant verified changes and reports. Do not mark implemented fixes as verified when their acceptance checks have not passed. Keep live API, installed Android/GPS/TalkBack, production signing and release gates open unless actually performed.
