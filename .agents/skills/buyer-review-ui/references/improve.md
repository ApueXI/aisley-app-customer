# Report-driven improvement

Use this reference for `buyer-review-ui improve [report-path] [BUI-IDs...]`. Apply the entrypoint's current-project reading, privacy, tool-discovery and progress rules. The original audit remains unchanged.

## Select the report and findings

Read `docs/PROGRESS.md` first as required by the entrypoint; then open an explicitly supplied report before revalidation. If it is missing, unreadable or not a Buyer UI audit, explain the problem and request a valid report or an audit; do not silently fall back to another report. Restrict report discovery and changes to this repository.

Without a path, inspect Buyer audit reports in `docs/reports/` with the `buyer-ui-audit-*.md` naming pattern. Select by `recorded_at` in report metadata, comparing timezone-aware timestamps as instants. Never select by modification time or filename date alone. Exclude companion improvement reports and unrelated audits. For older reports without this frontmatter, use an unambiguous recorded body date/time/timezone; exclude undated or ambiguous reports with an explanation. Break equal timestamp ties deterministically by repository-relative path and announce the choice. If no usable report exists, request an audit first and stop implementation.

Announce the chosen report and selected finding IDs. Without IDs, select all **confirmed, actionable** findings, highest severity first. Exclude unverified concerns and aesthetic suggestions from default implementation. With IDs, validate every requested ID before editing and restrict scope to them plus necessary shared fixes. An unknown ID requires correction; do not substitute a similar ID or broaden scope. Explicitly selected concerns still require confirmation by current evidence before implementation.

For default selection, list items already identified in the audit as blocked by unavailable contracts/required approvals separately with reasons; they are excluded from `selected_ids`. A selected item that becomes blocked during current revalidation stays selected and receives a `blocked` disposition. Report/ID selection failures stop before any new report or progress record; a valid selection proceeds to a companion report even when revalidation leaves no actionable fixes.

Read the report, current guidance and complete affected feature/prerequisite specifications, including consumers of shared fixes. Reinspect current source, routes, controllers and relevant tests before changing anything. Treat report evidence as a historical snapshot; do not blindly apply its proposed patch.

For each selected finding record current reproduction/evidence and a disposition:

- Still confirmed and actionable: define the smallest correction and acceptance checks.
- Already corrected or feature removed: `no longer applicable`, with current evidence; no redundant change.
- Backend/contract, required approval or external prerequisite prevents correction: `blocked`, with the specific dependency and next gate.
- Evidence cannot establish the defect: `unverified`, with the missing check; do not guess a fix.

Continue other selected actionable findings when one is blocked. Do not reinstall tooling, enable unavailable flows or change the backend to clear a blocker. If no findings are actionable, create a companion report and required progress record documenting dispositions; make no application changes.

## Branch and implement

Record active branch/HEAD and working-tree/index state. Before the first implementation change create and switch to a new branch **from the active branch**, such as `feature/buyer-ui-improve-YYYY-MM-DD-HHMMSS`; use a unique suffix on collision. Preserve unrelated staged, unstaged and untracked work. Do not reset, clean, stash or commit another person's changes by inference. Documentation-only disposition follows current project git rules.

Order fixes by severity, accounting for shared-component dependencies. Reuse the current theme, `lib/core/ui/` components, feature controllers and tests. Use relevant discovered Flutter skills for responsive/constraint issues and meaningful regression checks; optional previews/integration tooling must be supported and justified. Preserve file responsibility and project modularity limits; shared widgets cannot depend on feature-private controllers or repositories.

Preserve the existing light-only marketplace, identity/consent gates, authoritative totals/capabilities, typed API/repository boundaries, approved adapters and three separate message channels. Layout changes must retain safe drafts, focus, selection, scroll/gallery state and pending-mutation ownership across resizing/navigation, while maintaining required private cleanup. Avoid duplicate reads/writes introduced by remounting. Keep errors, retry, read-only and uncertainty visible and contract-correct.

Only extend shared changes to other consumers when necessary for the selected correction or to avoid regressions; record the connection to the selected ID. Report unrelated defects without implementing them. Additional dependencies or changes to the established stack require the approval prescribed by current project instructions, unless already authorized in the session. Prefer an existing-stack solution and continue unaffected work while a prerequisite remains open.

Reconcile actual behavior/contract conflicts through the integration-gap register; leave unsupported actions unavailable. If a selected fix requires a specification revision, follow `docs/features/customer/rule.md`: read it fully, preserve WHAT/MUST/HOW and 200–230 physical lines, evidence-backed criteria and filenames. Do not rewrite specs merely to justify a visual preference or mark unperformed acceptance complete.

## Verify against the finding

For actual UI improvements, run configured formatting, **`flutter analyze`**, relevant regression/widget tests and affected runtime checks. Inspect current setup/tooling for exact commands and approved SDK/lockfile. Examples, adjusted to real affected paths:

```sh
dart format <changed-Dart-paths>
dart format --output=none --set-exit-if-changed <changed-Dart-paths>
flutter analyze
flutter test <relevant-test-paths>
python3 tool/verify_bundle.py
git diff --check
```

The angle-bracket arguments above are placeholders, not literal commands. Include relevant unit/contract/controller tests when state or parsing is affected. Tests should verify observable behavior: overflow-free/reachable actions, semantics/targets, navigation, state preservation or correct error/recovery, rather than matching implementation details. Check shared consumers and reproduction conditions from the original audit.

Verify affected layouts at 320, 390, 600, 800, 1024 and 1440 logical pixels with normal and doubled text, plus applicable landscape, keyboard insets and mounted resize/navigation. Record actual screen/state/viewport/scale/height/inset combinations and unperformed checks. Inspect semantic names, 48×48 targets, contrast, keyboard/focus and Back/Cancel for changed controls. State continuity and private cleanup are separate acceptance requirements.

Use Dart MCP inspection/runtime-error/analysis and reload/restart tools when available and applicable. Recheck errors and affected interactions after reload; a successful reload alone does not verify the finding. If unattached, use available CLI/widget checks and existing synthetic browser fixtures, explicitly labeling runtime/device coverage gaps.

Run web/APK builds when appropriate to changed presentation, navigation, adapters or platform behavior, using authorized non-secret configuration from setup:

```sh
flutter build web <approved-public-build-inputs>
flutter build apk --release <approved-public-build-inputs>
```

Record exact executed commands and outcomes; placeholders or HTTPS `.invalid` compilation and debug signing cannot certify live deployment/distribution. Use Buyer `http://localhost:8766` for local browser checks; synthetic fixtures must intercept API calls before startup. Installed Android/GPS/TalkBack, real private media and controlled live API checks remain open unless actually performed.

For failed checks, distinguish a new regression from a reproduced pre-existing failure, with evidence. Fix regressions within scope and rerun affected checks. Missing Flutter/tools/runtime is a verification blocker or limitation, never a passing result; do not automatically install plugins/packages or mark unchecked fixes resolved. Stop application implementation when required validation cannot be obtained safely, record any local unverified edits, and do not commit unverified application changes. Verified report/progress documentation can still be committed independently. Do not broaden testing repeatedly after adequate checks pass unless new evidence warrants it.

## Create the companion report

Write a new `docs/reports/buyer-ui-improvement-YYYY-MM-DD-HHMMSS.md`, with a unique numeric suffix on collision. Link to the original audit and preserve its bytes. Retain each original finding ID; use the audit path plus ID to avoid ambiguity between reports.

Suggested metadata:

```yaml
---
report_type: buyer-ui-improvement
recorded_at: "actual ISO-8601 timestamp with offset"
timezone: "actual timezone"
audit_report: "repository-relative original audit path"
branch: "actual improvement branch"
base_commit: "full HEAD before implementation"
working_tree: "pre-existing changes summary"
backend_baseline: "current adopted per-feature revisions and deployment uncertainty"
selected_ids: ["BUI-001", "BUI-004"]
---
```

Include the selection method, any report/current-baseline differences and a status table covering **every selected ID**:

| Finding | Status | Current evidence and changes | Verification | Remaining acceptance / blocker |
| --- | --- | --- | --- | --- |
| Original BUI ID | One status below | Source/symbols and revalidation | Commands, results and evidence | Specific unperformed checks/dependencies |

Use statuses precisely:

- **fixed**: the defect is corrected and finding-specific acceptance checks passed; describe exactly which evidence verifies it. Independent broader release gates can remain open but must be listed.
- **partially fixed**: only part of the finding's required correction/acceptance is complete; identify remaining behavior and checks.
- **blocked**: a specific prerequisite prevents the required correction or verification; name it and the next action/owner.
- **no longer applicable**: current evidence shows the reported defect is already absent or its feature removed; state what was checked.
- **unverified**: evidence is insufficient to confirm the concern or validate a candidate implementation. Implementation alone never counts as verified resolution.

If a required runtime/device check belongs to this finding and was not performed, the finding cannot be `fixed`; use partial/blocked/unverified as appropriate. Show excluded concerns/suggestions and unknown/stale items with reasons, without silently treating them as completed. Include necessary shared fixes, files changed, safe before/after evidence and any relevant risk.

Add a verification ledger listing actual commands/tools, target/fixture, outcomes and evidence. Separate source review, tests, synthetic runtime, controlled live API and installed-device acceptance. Link sanitized evidence using paths relative to the report; retain original audit and historical reports unchanged.

Review the final diff, report links and privacy; append dated progress and apply the 150-line archive rule from the entrypoint. Follow project instructions to automatically commit only relevant verified changes using a conventional message, for example `fix: improve buyer checkout accessibility`. Preserve unrelated index/worktree content and withhold unverified application changes from the commit. Report the commit/branch, companion report, finding statuses, verification and remaining gates without equating a patch with completed acceptance.
