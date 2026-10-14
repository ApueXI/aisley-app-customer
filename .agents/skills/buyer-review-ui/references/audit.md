# Audit workflow

Use this reference for `buyer-review-ui audit [scope]` and omitted-mode requests. Apply the entrypoint's project-reading, privacy and tool-discovery rules first. The deliverable is a new actionable report; application code remains unchanged.

## Inventory and evidence

Capture current time with timezone, active branch, full HEAD commit and working-tree/index state before inspection. Identify adopted backend revisions by feature from current progress/contracts; keep inspected and deployed versions distinct and mark unknown deployment revisions explicitly.

Resolve the requested scope against actual routes, screens, dialogs, shared widgets and existing tests. Start with `lib/app/router.dart`, `lib/app/communication_routes.dart`, `lib/app/router_guard.dart`, `lib/app/shell_screen.dart`, `lib/app/theme.dart`, `lib/core/ui/`, `lib/features/*/presentation/` and relevant `test/` files, checking whether these paths still exist. Trace controllers/repositories where loading, capability or state ownership affects the UI. Do not infer implementation from a specification, endpoint inventory or backend test alone.

For a full audit, inventory all implemented authentication/approval/recovery, policies/consent, discovery/search/Shops/Product, account/password/photo/preferences, addresses/maps, saved/history, Cart/Checkout/vouchers/results, Orders/tracking/correction, separate message channels/media, notifications, Q&A/reviews and support screens. Include secondary forms, sheets, dialogs and shared navigation/components. Mark planned/unavailable destinations as excluded with reasons. A feature-scoped audit includes its entry/exit navigation and shared components, without becoming a full unrelated audit.

Inspect available runtime targets and existing synthetic fixtures. The current project offers `docs/api/examples/`, widget tests and `tool/browser_smoke.py`/`tool/browser_synthetic.py` with recovery/accessibility variants. Read their arguments and setup guidance before use. Prefer isolated synthetic sessions for state coverage. Existing tests may be run; audit must not create or change tests, previews, application code or configuration.

An unattached runtime does not prevent a report. Continue source review and available read-only checks, documenting exactly what could not be examined. Source logic can confirm a defect when the failing conditions are provable, but source-only layout concerns must not be described as visually reproduced or device-tested. Historical runtime evidence retains its date/revision and does not become a current observation.

## Examine each applicable area

Use `docs/design-buyer.md` as the presentation standard and feature contracts as behavior authority. Make each check specific to a screen/state and a user task.

| Area | Checks |
| --- | --- |
| Visual hierarchy | Titles, product imagery, price/total, primary and secondary actions; consistent typography, spacing, neutral surfaces, brand/accessible colors, corners and components |
| Shopping navigation | Discoverability of search and next action, phone/desktop shell, separate channels, safe returns, browser/Android Back, dialog Cancel and changed-form discard |
| Form usability | Labels/help/errors, required/read-only fields, autofill/input actions, first invalid field, preserved safe input, double-submit prevention, keyboard reachability |
| Responsive layout | All required widths/text settings, bounded forms/content, long names/full prices, wrapping cards/actions, grids/rails/galleries, short heights, landscape, safe areas, keyboard insets |
| Accessibility | 48×48 logical-pixel targets, semantic names/roles/order, meaningful images, contrast, non-color status, visible keyboard focus, Tab/Enter/Escape, reachable purchase/composer/dialog controls, reduced motion |
| Honest states | Applicable initial/loading/success/empty, validation, offline/timeout/stale/partial, retry, throttled, forbidden/consent, unavailable/read-only and uncertain mutations; no failed request disguised as empty/success |
| State continuity | Drafts, focus/selection, scroll, gallery page, variants, Cart/provider/voucher selection, mounted breakpoint transitions and navigation; no repeated requests/writes from resize |

Compare the current documented light-only theme and marketplace patterns, including width/text-dependent navigation, 560-pixel forms, 1200-pixel shopping bounds and reachable controls. Read current requirements instead of imposing an unrelated design system.

Exercise safe state continuity across resizing and recoverable navigation/errors. Preserve server-required cleanup on logout, account switch, identity loss and renewed consent; private drafts surviving their required cleanup boundary are a defect, not a preservation improvement. For read-only threads, stock/provider failures, stale quotes and uncertain operations, verify the explanation and only contract-supported next actions. Map/file-picker denial should retain documented manual alternatives.

## Record the actual coverage matrix

Plan widths **320, 390, 600, 800, 1024 and 1440 logical pixels**, normal and doubled text (1× and 2×). Include landscape/small heights and keyboard-open forms/composers/dialogs; record actual height and inset instead of assuming width alone represents a viewport. Check mounted resizing across navigation/detail breakpoints and a return through Back/Cancel. Focus on applicable states and record every skipped combination rather than asserting exhaustive coverage.

For every examined combination record screen/route, state/fixture, width×height, text scale, orientation, keyboard/safe-area insets, check type, evidence and result. Explicitly identify each unverified required combination; grouped rows are acceptable only when their exact members share evidence and result. Mark a state `not applicable` only with a contract reason.

Use separate source, automated and runtime columns; a test pass does not imply visual observation:

| Screen/route and state | Viewport / scale / orientation / insets | Source-reviewed | Automated check | Runtime-observed / target | Unverified / result / evidence |
| --- | --- | --- | --- | --- | --- |
| Actual screen and fixture | Exact measured settings, or N/A for source-only | Paths and lines reviewed | Command/result, or not run | Synthetic browser, live browser, installed device, or none | Missing checks and evidence link |

Runtime checks must name the platform/browser/device and distinguish synthetic interception from a controlled live backend. Screenshots alone do not prove focus, semantics, TalkBack order, mutation recovery or state retention. Do not claim contrast was measured unless it was; list measured foreground/background pairs and result when available. Preserve privacy when collecting screenshots, console/runtime errors and interaction evidence.

## Prioritize findings

Assign stable report-local IDs `BUI-001`, `BUI-002`, etc. Keep those IDs unchanged in follow-up reports; identify a finding by the original audit path plus ID across audits. Group repeated symptoms under their shared cause, naming every affected consumer and acceptance check.

Classify severity by user impact:

| Severity | User impact |
| --- | --- |
| Critical | Exposes private data, bypasses identity/consent, or enables a harmful/duplicated commerce action |
| High | Blocks a core shopping/authentication task or makes essential actions inaccessible under supported conditions |
| Medium | Creates recoverable task friction, confusing feedback, state loss or a material accessibility/consistency defect |
| Low | Minor usability/presentation inconsistency with limited task impact |

Separate **confirmed defects**, **unverified concerns**, and **optional aesthetic suggestions**. Evidence and confidence are independent from severity; do not upgrade a suspicion because the potential impact is serious. For concerns, state what verification would establish the defect. Optional suggestions must remain grounded in the current design and cannot silently authorize redesign.

Every finding, including IDs assigned to concerns or optional suggestions, must include the fields below. For unverified items, explicitly mark unavailable observations/conditions as unverified or not applicable with reasons; do not replace the finding record with a shorthand paragraph.

- Stable ID, concise title, category, severity and evidence/confidence.
- Affected screens/routes/components and current source file/line or symbol; link sanitized runtime evidence where present.
- Reproduction preconditions, state, exact viewport/text/inset settings and steps; for source-only evidence explain the provable path or the assumption needing runtime verification.
- Observed/expected behavior, user impact and the exact violated design/spec requirement with a document location.
- A concrete proposed correction that reuses the current architecture/components/contracts.
- Measurable acceptance checks for the reproduction, affected states, resize/state continuity and shared consumers; state the checks still needing runtime/device access.
- Dependencies, contract conflicts/gap IDs, blockers and any prerequisite owner decision. A backend gate cannot be solved by enabling an unsupported client action.

Sort confirmed defects by severity and impact; list concerns and suggestions separately. A report with no confirmed findings is valid; do not manufacture defects to fill a quota.

## Write the audit

Create `docs/reports/buyer-ui-audit-YYYY-MM-DD-HHMMSS.md` using actual report time in the recorded timezone. Never replace an existing path: on a same-second collision append a unique numeric suffix. Keep the `buyer-ui-audit-` prefix even though this skill is named `buyer-review-ui`.

Use this frontmatter so improvement can select a report by its recorded time:

```yaml
---
report_type: buyer-ui-audit
recorded_at: "YYYY-MM-DDTHH:MM:SS+08:00"
timezone: "Asia/Manila"
branch: "actual-active-branch"
commit: "full-HEAD-hash"
working_tree: "clean or concise dirty-state summary before audit"
scope: "all implemented Buyer screens and shared UI, or resolved feature scope"
backend_baseline: "adopted per-feature revisions; deployed revision unknown if unverified"
---
```

Use the actual timezone/offset, not a copied timestamp. In the body include:

1. Scope, implementation/baseline context, inventory, exclusions and concise prioritized outcome.
2. Coverage matrix and precise runtime/tool/data limitations, including unverified viewport/state combinations.
3. Confirmed findings with all required fields and stable IDs.
4. Unverified concerns and optional suggestions, clearly separated.
5. Dependencies/contract conflicts/blockers, prioritized correction order and remaining live/device acceptance.
6. Verification ledger: actual commands/tools, target, outcome and evidence; identify inspected tests that were not executed.

Relative links in a report resolve from `docs/reports/`. Persist only sanitized evidence at unique report-associated locations, honor ignore rules and keep previous reports intact. Record newly established contract conflicts in the existing integration-gap register when project rules require it; this is documentation, not backend or application repair.

Review the diff for accidental application changes or sensitive evidence, check links, append/archive progress and commit relevant verified documentation under project rules. Return the report path, highest-impact findings and coverage limitations. Leave open all live/device/release gates without actual acceptance evidence.
