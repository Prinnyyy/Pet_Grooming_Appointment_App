# Current State

Current facts for task startup and recovery. Historical task narrative belongs in `WORKLOG.md`, frozen snapshots, or domain documents.

## Task Baseline

- Date: 2026-09-10
- Latest completed task: T-385 Local functional reliability acceptance (WP-14 and final WP-00 disposition).
- Current task: T-386 governance plan drafted at the user's request; implementation has not started. See [lean governance plan](../superpowers/plans/2026-09-10-lean-governance-plan.md). T-385 completion `c24ca4f3` is pushed; physical devices/signing/store distribution and timezone-settings changes remain outside scope.
- Next task ID: T-387 for the next explicitly adopted task; T-386 is already reserved for the proposed governance work.
- Current branch baseline: `codex/pet-fit-structure-cleanup`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.

## Active Work

WP-12 accepted: real delivered email/SDK recovery and two-account cleanup, final integration (587 Swift tests/59 suites plus rendering; UI four executed/six fixture skips), build and preflight pass. See [T-383 evidence](../06_tasks/sql_reviews/T-383_PASSWORD_RECOVERY_ACCEPTANCE.md). Exact recovery allowlist append preserves the old callback/Site URL/SMTP; no schema change. Simulator callback qualification remains WP-14; the recorded governance cadence exception remains explicit.

| Item | State | Next Condition |
|---|---|---|
| T-385 / WP-14 | completed | Dual-Simulator lifecycles, actual result interruption/restart, reconnect/OS reminders, keyboard/callback, full regression/build/preflight and exact cleanup accepted. |
| T-384 / WP-13 | completed | Fixed measurements, optional isolation, stale-state guards, full regression/build/runtime/preflight passed. |
| T-383 / WP-12 | completed | Recovery accepted; original WP-13 follows. |
| T-382 / WP-11 | completed | Deployed owned snapshot; full regression/build/runtime/access/cleanup passed. |
| T-381 / WP-10 | completed implementation | Deployed routes/retry accepted; dual-Simulator qualification remains WP-14. |
| T-380 / WP-09 | completed | Accepted bounded summaries/exact routing; WP-10 follows. |
| T-379 / WP-08 | completed | Accepted nearest/date/exact reads; original WP-09 follows. |
| T-378 / WP-07 | completed | Deployed and accepted; original WP-08 follows. |
| T-377 / WP-06 | completed | Accepted and deployed; original WP-07 follows. |
| T-376 / WP-05 | completed | Versioned consent, complete immutable agreements, deadline/recovery and atomic replacement accepted. |
| T-375 / WP-04 | completed | Deployed; real contention, restoration, scheduled refresh and UI evidence verified. Original WP-05 next. |
| T-374 / WP-03 | completed | Original timing/backend/client requirements accepted; committed/pushed 71ffb595. Release-only limits remain explicit. |
| T-373 / WP-02 | completed | Pet capacity, original receipt/current-state recovery and acceptance refresh session checks verified; see the acceptance evidence. |
| T-371 / WP-01 | completed | SQL rollback/access, concurrent Save and save/acceptance with both orderings, six seeded UI cases, full regression/build passed. Exact fixture rows/revision restored; standalone acceptance record committed with task implementation. |
| T-369 / WP-00 | final disposition completed in T-385 | D-038/D-042...D-052 and final compatibility/legacy matrix resolve all policy/evidence gates; original inspection history remains separate. |
| T-365/T-366 findings documentation | saved; separate closeout pending | T-368 removes the general hygiene blockers without retroactively completing these tasks or committing their drafts. |
| T-367 formal task plan | saved for review; separate closeout pending | User review and decision gates precede package adoption; T-368 removes the general hygiene blockers, not the implementation gates. |
| T-157 APNs dispatch | blocked | Paid Apple Developer access and APNs credentials are required. |
| Q-104 Groomer Dynamic Type/Accessibility | deferred | Resume only when the user restores this scope. |
| Q-93 leaked-password protection | blocked | Supabase Pro-or-higher plan decision and authorization are required. |

The user-authorized [Functional Reliability Task Plan](../superpowers/plans/2026-09-07-functional-reliability-task-plan.md) is locally accepted through WP-14, including final WP-00 disposition. Two independent actual Simulator apps and package-specific server/Store evidence cover the 14 integrated scenarios. Physical devices, signing and store distribution are outside scope under the 2026-09-10 user clarification.

[App functional design findings](../06_tasks/APP_FUNCTIONAL_DESIGN_FINDINGS.md) records 15 findings, 3 simplification candidates, and 4 lifecycle policy questions. All 22 have specific evidence/dispositions in the T-385 final matrix. No perfect-reliability, production-performance or arbitration-service claim is made.

## Validation Baseline

- T-385: [final acceptance](../06_tasks/sql_reviews/T-385_RELEASE_CHECKPOINT.md) records 83 aligned migrations, unchanged RLS, actual Realtime participant isolation, two order lifecycles, keyboard and callback, committed-result interruption/restart, stopped-client cancellation/reminder reconciliation, exact fixture restoration and zero residue. Quote Debug forwarding and explicit notification bulk-read fix are included.
- T-374: full `/tmp/beckon-t374-final-integration.log`, build `/tmp/beckon-t374-final-build.log`, final preflight and focused `/tmp/beckon-t374-broad-window-vectors.log` pass. The full default UI suite executes three cases and skips six environment-gated cases; targeted changed-flow evidence is separate. No production changes after this integration run.

- T-371 evidence: 457 Swift cases including 47 Store cases passed; default UI three executed/six skipped, supplemented by six authorized seeded UI cases without skips. Preflight passes 85 migration and 10 function tests. Both migrations are deployed; 72 histories align. Rollback/access, concurrent Save and save/acceptance with both orderings passed; exact fixtures were restored. Advisors retain only Q-93. See [acceptance evidence](../06_tasks/sql_reviews/T-371_AVAILABILITY_ACCEPTANCE.md). Compatible-client distribution remains WP-14.

- Latest app/full regression: T-382 serial full regression passes (580 Swift tests/58 suites plus rendering; default UI three executed/six environment-gated skips), build and preflight pass. See [T-382 acceptance](../06_tasks/sql_reviews/T-382_REMINDER_ACCEPTANCE.md).
- T-368 validation: 57 governance tests and unified closeout passed, including checkpoint handling, warning/strict freshness branches, and preservation of another pending task's active plan. General backend freshness is advisory; backend work still requires verified evidence under Tooling Policy. The T-365 through T-367 failures below are historical, not current general-hygiene blockers. Git closeout remains deferred to avoid mixing earlier uncommitted drafting work in shared memory files.
- T-365 documentation closeout: initial diff check passed; the closeout precheck failed because Supabase Contract (2026-07-14) and Migration Rules (2026-07-09) exceed the 45-day verification window. No verification dates were changed and no commit/push was attempted.
- T-366 documentation validation: tracked diff check passed; context hygiene failed on the same two stale backend dates and a completed-task mismatch (Current State T-364 versus blocked Worklog checkpoint T-366). The checker treats the newest Task entry as completed without consulting its blocked status. No task was falsely marked completed and no checker rule was changed. The register preserves the preceding review's 22 passing SQL-contract tests and isolated Swift probe, not new app/backend validation.
- T-367 plan checks passed: metadata, 22 register items, 15 packages, eight self-review corrections, acyclic dependencies, 114 local links, new-document whitespace, and tracked diff. Context hygiene still fails only on the two existing backend freshness gates and T-364/T-367 checkpoint mismatch. No application, migration, remote test, or runtime validation was run for planning.
- Latest backend validation: T-385 has 83 aligned versions/empty dry run, actual participant Realtime isolation and exact cleanup. Existing Q-93 remains separately owned.
- Latest client validation: T-385 serial full regression passes: 603 Swift tests/60 suites reported (one environment-gated skip), XCTest 22/one email-bridge skip, UI 10/six fixture skips. Skips have separately cited prior/actual evidence. Simulator build and preflight (3 brand/116 migration/10 function tests) pass. Initial parallel run failed a 50ms test scheduling assumption; bounded wait for actual portfolio-read entry fixes it without changing production loading.
- Known iOS validation failure: none currently recorded.
- No app-owned compiler warning remains in the latest app build. The AppIntents metadata-skipped message remains classified as toolchain information while Beckon has no App Intents dependency.
- Focused test compilation currently reports three pre-existing unused-result warnings in `BeckonAddressEditorTests` and `GroomerProfileFeatureTests+FitSignals`; these do not occur in the app target build.

## Product Baseline

- Beckon is a request-first iOS marketplace: Customer Request -> Groomer Offer -> Customer Acceptance -> Booking/Chat -> Groomer Completion -> Customer Review.
- Production uses real Supabase Auth, authoritative profiles, role separation, repository boundaries, RLS/RPC controls, and private authenticated image loading.
- Implemented areas include onboarding, Customer and Groomer workspaces, requests/offers/bookings/chat, notifications, profiles, photos, account deletion, privacy/support, diagnostics, and TestOps.
- Customer and Groomer notifications share one DesignSystem page, card row, unread indicator, and Home bell button; role Stores/repositories remain separate and Groomer rows preserve focused routing.
- Customer and Groomer Messages use one conversation-page title, card-row presentation, and counterpart-avatar field; role-aware repository loading hydrates Groomer or Customer images from their dedicated private buckets for both list and thread header.
- Chat is unique per Customer/Groomer pair across bookings. Acceptance and either-party cancellation append a live Booking card followed by actor-authored friendly text; cards open the existing role-specific Booking detail.
- Customer Request publication uses an operation-scoped idempotent v3 RPC. The Store treats RPC creation as authoritative and reports later photo/refresh failures only as recoverable warnings.
- The Customer Request Wizard requires an explicit service, requires useful notes for Custom Request, exposes dates beyond its seven-day quick strip, and uses one truthful Continue interaction state with field-level validation.
- Customer Request Wizard step changes clear stale input focus and reset the shared ScrollView to its top anchor after layout, preventing address-field keyboard positioning from leaving later steps outside the visible viewport.
- Request-specific photos are separate from the Pet avatar, appear as removable previews and a Review count, and retain failed post-create uploads in the shared Customer Request Store for retry from Home or Requests.
- Customer Offer acceptance uses a final confirmation sheet with groomer, appointment, price, location, address, and cancellation context; one guarded acceptance returns a local Booking handoff and routes directly to Booking Detail while backend stale-offer validation remains authoritative.
- Customer Requests exposes a direct New Request entry. Home and Requests render loading, empty, failure, and loaded states distinctly while preserving usable stale content, and both Request carousels expose the visible card position.
- Current UI work must reuse the existing DesignSystem, Store, repository, model, and backend boundaries. New persistence, navigation, role capability, or remote behavior requires separate approval.

## Operational Guardrails

- Authorized Supabase project: Beckon, ref `lqmasbuqzvcvtawonjlb`; the legacy project is out of scope.
- T-385 migration `20260910075314_t385_chat_realtime_publication.sql` is applied; 83 linked versions align and final dry run is empty. Applied migrations are immutable.
- Standing Git approval covers validated task-completion commits and pushes on the current branch only.
- PRs, tags, merge/rebase/reset, branch deletion, seeds, migrations, Supabase writes, deploys, repository settings, and other non-Git remote writes require explicit approval.
- `main` is not the active baseline. The reviewed main-only commit `2fddf7b` is superseded and must not be merged into this branch.

## Recovery Routes

- Task status and numbering: `docs/06_tasks/TASK_LEDGER.md`.
- Recent closeout evidence: `docs/00_memory/WORKLOG.md`.
- Managed direction: `docs/06_tasks/ROADMAP.md` and `docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md`.
- Feature routing: `docs/00_memory/FEATURE_INDEX.md`.
- UI design routing: `docs/01_product/DESIGN_SYSTEM.md`; heavy Figma/inventory access starts at `docs/ui-redesign/README.md`.
- Durable decisions: `docs/07_decisions/DECISION_LOG.md`.
- Task lifecycle and context/recovery: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md` and `docs/05_workflow/CONTEXT_AND_RECOVERY.md`.
- Validation/remote authorization and Git conventions: `docs/05_workflow/TOOLING_POLICY.md` and `docs/05_workflow/GITHUB_RULES.md`.
- Pre-reset source snapshot: `docs/09_frozen/active_state_snapshots/T-345_2026-07-13/` (history only; never default startup context).

## Governance

- Last meta-review: T-372 on 2026-09-07.
- T-385 retains the governance-only cadence exception after T-372; a new review was not inserted into the user's continuous original plan. Retain the true review date and failed cadence result, not a false unified-closeout pass. Safety, freshness, access and functional gates are unchanged.
- Run `node scripts/context-hygiene-check.mjs` after durable memory, ledger, workflow, or coordination-document changes.
- Update this file by replacing stale facts. Do not append task timelines, full validation narratives, credential explanations, or future-task recommendations.
