# Buyer Flutter Progress

Short, dated implementation log. Append entries; archive complete logs after 150 physical lines. Preserve historical reports and distinguish local verification from deployed/device acceptance.

## Current status

- Buyer Phases 1–4/Phase 5 tooling, MapLibre/PSGC addresses, per-Shop shipping, voucher collection/wallet, Order/Checkout thumbnails and private chat images/received MP4/documents are implemented locally. Voucher names/pairing, Order coordinates and Shop-context adoption have explicit remaining gaps.
- Historical adoption slices: General 57e9eb2; shipping 22b0a48; collection 7e89b391; Order/Checkout images 5d55ecf; media 28fc740. Inspected source: Laravel `240eefddd4e2e2eea2f9558beec0292efa2121fe`, Buyer `7924cf06158817a2dcd709ec19a7442e3496dda5`. Inspection does not promote every contract to client adoption; deployed revision remains unidentified.
- Live authenticated/deployed API, private-media runtime and installed Android/accessibility acceptance remain open. Buyer provider configuration and signing gates remain open.
- Historical application test/build/browser results are in the archives and verification reports. This sync runs documentation validation only.

## Historical progress

- [Platform history](logs/PROGRESS-2026-10-12.md): original dated results with their own execution scope.
- [Client history](logs/PROGRESS-2026-10-12-2.md): original dated results with their own execution scope.

## 2026-10-12 — Three-project documentation synchronization

- Reconciled server contracts with current Flutter sources, imported newer client evidence, corrected status summaries and retained explicit adoption/release gaps. Archived the two complete role histories separately with attribution; existing archives remain unchanged.
- Validated portable links/anchors, JSON/examples, endpoint inventory, spec bounds, synchronized copies, preserved archive prefixes and PSGC bytes, plus Git whitespace. See [audit and validation](references/synchronization-2026-10-12.md). No application tests/builds or live/device checks were rerun.

## 2026-10-14 — Email-verified account password changes

- Added current/new passwords → emailed verification code → confirmed password change in Buyer account settings. Typed code requests/confirmation preserve the current bearer, expiry/resend limits, cancellation, account-switch cleanup and uncertain-result sign-in reconciliation. Adopted the new password-code API contract and updated only affected documentation.
- Verification: 27 focused contract/controller/widget tests, Flutter analyzer, web build and Android release APK pass; portable bundle validation passes (988 links, 22 specs, 19 PSGC registrations). Live SMTP/deployed API and installed-device acceptance remain open.

## 2026-10-14 — Email-first registration OTP

- Adopted registration-email contract v1 (2026-10-14): public code/verify APIs, six-digit OTP, required role/email-bound proof, resend/expiry/Retry-After, memory-only secrets, retained registration drafts and existing approval gates. Existing accounts keep their login behavior. Updated typed API models/repositories and native registration UI; no new dependencies.
- Verification: 77 networking/session/OTP/responsive checks and the additional registration-screen draft test, Flutter analyzer, web build and Android release APK pass. Laravel registration/mail enforcement and isolated PostgreSQL concurrency checks pass independently; live SMTP/deployed API and installed-device acceptance remain open. API enforcement requires coordinated client release and the new backend migration/workers.
- Backend implementation: `27a6361`; registration-email contract v1 (2026-10-14).

## 2026-10-14 — B11 password reconciliation lifetime

- SessionController now owns nonsecret pending password/reconciliation and cooldown state across screen disposal/recreation, Back/Cancel and identity/consent revalidation. Confirmation outcomes settle for their originating session after disposal; fresh authentication/identity loss resets recovery and obsolete responses cannot change newer operations. Passwords/codes/challenges stay screen-local. Memory-only state does not survive process restart.
- Updated the password screen feedback/disabled controls and synchronized password API/account specs with the backend documentation bundle; no API, token policy or dependency changes.
- Verification: 18 new lifetime controller/widget tests plus 51 adjacent account/session/contract regressions pass; Flutter analyzer, release web build, Android release APK, affected formatting, whitespace and bundle validator (998 links/22 Customer specs/19 PSGC checks) pass. Tests use synthetic repositories; live API/SMTP, installed Android/TalkBack and deployed acceptance remain open. Existing Android SDK XML warning remains.

## 2026-10-14 — Buyer UI review skill

- Added repository-local [buyer-review-ui](../.agents/skills/buyer-review-ui/SKILL.md) with audit/improve routing, complete finding records, source/runtime coverage, timestamp-based report selection, scoped revalidation, verification and progress/commit rules. Current per-feature backend adoption is read at invocation; this skill creation changes no application behavior or contract adoption.
- Verification: `python3 /home/cred/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/buyer-review-ui`, metadata/reference/project-path checks, `python3 tool/verify_bundle.py` and Git whitespace checks pass. Eight independent scenarios in isolated synthetic repositories exercised full/scoped audits, omitted mode, absent runtime/tools, explicit/automatic reports, selected/stale/blocked/unverified IDs and missing/invalid selection; fixture source and original audits were preserved. Clarified selection-failure completion and known-blocker handling from these checks.
- Only skill/documentation workflows were verified. Application tests/builds and actual UI audits were not run; controlled live API, installed Android/GPS/TalkBack, private-media runtime, provider configuration and signing gates remain open. Progress remains below the 150-line archive threshold.
