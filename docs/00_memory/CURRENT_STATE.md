# Current State

Current facts for task startup and recovery. Historical task narrative belongs in `WORKLOG.md`, frozen snapshots, or domain documents.

## Task Baseline

- Date: 2026-07-14
- Latest completed task: T-355 Chat counterpart avatar hydration and access.
- Current task: none.
- Next task ID: T-356 for the next new task.
- Current branch baseline: `codex/pet-fit-structure-cleanup`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.

## Active Work

| Item | State | Next Condition |
|---|---|---|
| T-157 APNs dispatch | blocked | Paid Apple Developer access and APNs credentials are required. |
| Q-104 Groomer Dynamic Type/Accessibility | deferred | Resume only when the user restores this scope. |
| Q-93 leaked-password protection | blocked | Supabase Pro-or-higher plan decision and authorization are required. |

No roadmap package is automatically active. New work starts from an explicit user request and the next task ID in `docs/06_tasks/TASK_LEDGER.md`.

## Validation Baseline

- Latest app validation: T-355 passed focused Chat tests, the complete iOS suite, and `./scripts/ios-build.sh`.
- Latest full iOS regression: T-355 passed the complete iOS suite and build.
- Latest documentation/backend validation: T-355 passed preflight, 77 migration tests, 10 Edge Function tests, linked rollback authorization SQL, final remote dry-run, advisor checks, UI audit checks, and context hygiene.
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
- Current UI work must reuse the existing DesignSystem, Store, repository, model, and backend boundaries. New persistence, navigation, role capability, or remote behavior requires separate approval.

## Operational Guardrails

- Authorized Supabase project: Beckon, ref `lqmasbuqzvcvtawonjlb`; the legacy project is out of scope.
- Linked Beckon migration history is aligned through `20260714072728_t355_chat_counterpart_avatar_access.sql`.
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

- Last meta-review: T-350 on 2026-07-13.
- Run `node scripts/context-hygiene-check.mjs` after durable memory, ledger, workflow, or coordination-document changes.
- Update this file by replacing stale facts. Do not append task timelines, full validation narratives, credential explanations, or future-task recommendations.
