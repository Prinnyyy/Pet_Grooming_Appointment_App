# Current State

Current facts for task startup and recovery. Historical task narrative belongs in `WORKLOG.md`, frozen snapshots, or domain documents.

## Task Baseline

- Date: 2026-07-28
- Latest completed task: T-358 Request publish idempotency and recovery.
- Current task: none.
- Next task ID: T-359 for the next new task.
- Current branch baseline: `codex/pet-fit-structure-cleanup`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.

## Active Work

| Item | State | Next Condition |
|---|---|---|
| R-042 Customer Request Journey | ready | Execute Q-122 next. |
| T-157 APNs dispatch | blocked | Paid Apple Developer access and APNs credentials are required. |
| Q-104 Groomer Dynamic Type/Accessibility | deferred | Resume only when the user restores this scope. |
| Q-93 leaked-password protection | blocked | Supabase Pro-or-higher plan decision and authorization are required. |

No roadmap package is automatically active. R-042 is adopted as Q-121 through Q-125, but each package starts only from an explicit user request and the next task ID in `docs/06_tasks/TASK_LEDGER.md`.

## Validation Baseline

- Latest app validation: T-358 passed focused Customer Request tests, the complete iOS suite, and `./scripts/ios-build.sh`.
- Latest full iOS regression: T-358 passed the complete iOS suite and build.
- Latest documentation/backend validation: T-358 passed 81 migration tests, TestOps coverage, preflight, linked rollback-only replay/authorization validation, and security/performance advisors.
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
- Current UI work must reuse the existing DesignSystem, Store, repository, model, and backend boundaries. New persistence, navigation, role capability, or remote behavior requires separate approval.

## Operational Guardrails

- Authorized Supabase project: Beckon, ref `lqmasbuqzvcvtawonjlb`; the legacy project is out of scope.
- Linked Beckon migration history is aligned through `20260728215928_t358_request_publish_idempotency.sql`.
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
