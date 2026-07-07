# Current State

Update this only when project state meaningfully changes. Keep it as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-07
- Updated by: Codex
- Latest completed task: T-159 Private RPC lint cleanup.
- Current task: T-157 Customer APNs push notification foundation remains blocked until paid Apple Developer Program access provides APNs credentials.
- Next task ID: use T-160 for new non-APNs work, unless the user resumes T-157 after Apple Developer Program upgrade.

## Fast Path

- Task source of truth: `docs/06_tasks/TASK_LEDGER.md`.
- Recent closeouts: `docs/00_memory/WORKLOG.md`.
- Canonical decision log: `docs/07_decisions/DECISION_LOG.md`.
- Feature routing: `docs/00_memory/FEATURE_INDEX.md`.
- Workflow: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Context/recovery/budgets: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`.
- Tooling/validation/remote writes: `docs/05_workflow/TOOLING_POLICY.md`.
- Context hygiene command: `node scripts/context-hygiene-check.mjs`.
- Frozen archive guide: `docs/09_frozen/README.md`.

Key frozen archive families: current-state snapshots, worklogs, task ledgers, backend contracts, backend policies, feature indexes, design prompts, design notes, product briefs, memory pointers, workflow templates, task templates, historical task records, and archived workflow docs under `docs/09_frozen/`.

## Branch and Baseline

- Current branch baseline: `codex/pet-fit-structure-cleanup`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.
- Continue implementation, documentation, commit, and push work from this branch unless the user explicitly names another branch.
- Do not treat `main` as the current work baseline until the user explicitly asks to reconcile it.
- Do not commit, push, create PRs, seed, cleanup, migrate, or make remote writes without explicit user approval.

## Validation Baseline

- Last iOS build: `./scripts/ios-build.sh` passed on 2026-07-07 during T-158 closeout.
- Last full iOS test: `./scripts/ios-test.sh` passed on 2026-07-06 during T-154 local implementation. T-155 attempted `./scripts/ios-test.sh` on 2026-07-06; it failed one unrelated T-153 `CustomerNotificationsStoreTests.markAllReadReplacesNotificationsWithRepositoryResult()` same-timestamp ordering assertion after 229/230 tests passed.
- Last Supabase migration apply: authorized `supabase db push --linked` applied `20260707183427_t159_private_rpc_lint_cleanup.sql` to project `lqmasbuqzvcvtawonjlb` on 2026-07-07.
- Last Supabase live post-apply validation: T-159 migration list/dry-run, public/private RPC metadata SQL, `supabase db lint`, and advisors ran on 2026-07-07.
- Prepared unapplied Supabase migration: none; sequential `supabase db push --linked --dry-run` reported the remote database is up to date after T-159.
- Last TestOps unit validation: T-145 `./scripts/testops-unit.sh` passed 24 Node tests.
- Last remote TestOps run: T-155 authorized `matching_baseline` run `TESTOPS-T155-MATCH-20260706-*` passed 8/8 and cleanup left zero tagged request/match residue.
- Last docs/workflow validation: T-158 `git diff --check` and `node scripts/context-hygiene-check.mjs` passed on 2026-07-07.
- Known live failing behavior: none currently recorded.

## Active Product State

- MVP marketplace flow is complete at the current contract level: customer request -> groomer offers -> customer accepts -> booking/chat -> groomer completes -> customer reviews.
- Production uses real Supabase Auth, authoritative profile loading, and customer/groomer role separation. No production path fabricates a session/profile.
- Implemented iOS areas include Auth, role onboarding, customer pets, customer requests/offers, customer in-app notifications, groomer requests/offers, groomer submitted-offer tracking, bookings, text chat, groomer profile/services/portfolio, Customer Account profile settings, Debug Console, and TestOps support.
- Groomly UI adaptation is complete for implemented MVP screens. Future UI work is screenshot-driven and must map screenshot modules to existing SwiftUI/Store/repository/model paths or stop for new-feature approval.

## Active Workflow State

- Default context model is L0-L4 in `CONTEXT_AND_RECOVERY.md`.
- Startup reads stay minimal: `AGENTS.md`, then targeted current-state/task-ledger sections only when needed.
- Default `rg` searches honor `.rgignore`; do not use broad `rg --files -g '*.md'` as the default Markdown inventory.
- Do not read full `WORKLOG.md`, full `TASK_LEDGER.md`, frozen archives, Groomly HTML/export, or T-129 seed tables by default.
- After durable memory, ledger, workflow, or coordination-doc changes, run `node scripts/context-hygiene-check.mjs` and archive old content immediately if budgets are exceeded.

## Supabase and TestOps Guardrails

- Authorized Supabase project: `Pet Groomer Marketplace`, ref `lqmasbuqzvcvtawonjlb`.
- Legacy ref `swdiiyypysyxbnfrxxsv` is out of scope; do not inspect or mutate it.
- Linked Supabase CLI commands must run sequentially.
- `SUPABASE_DB_PASSWORD` is not currently needed for normal local linked CLI use while saved credentials remain valid.
- `SUPABASE_SECRET_KEY=sb_secret_...` is not a CLI PAT, DB password, JWT, or Bearer token.
- TestOps accepts either legacy `SUPABASE_SERVICE_ROLE_KEY=eyJ...` or modern `SUPABASE_SECRET_KEY=sb_secret_...`; modern secrets are sent as `apikey` only. Seed scripts still expect JWT-shaped legacy service-role keys.

## Current Known Risks

- Active memory/task files are intentionally concise. Do not expand them into full history.
- Backend policy files are now current-rule indexes; use migrations or frozen pre-trim snapshots for detailed historical trace.
- The original root product/engineering brief, old Groomly design task prompt, pre-slim design notes, removed memory pointer, removed generic lightweight templates, and external agent audit drafts are archived under `docs/09_frozen/`; use `docs/01_product/PRODUCT_BRIEF.md`, `docs/01_product/DESIGN_SYSTEM.md`, `docs/08_design/UI_IMPLEMENTATION_NOTES.md`, `docs/07_decisions/DECISION_LOG.md`, and active workflow/task docs as entrypoints. External agent reports are review input only and must not reset branch, task ID, validation, or product status.
- T-129 seed profile Markdown files are machine-readable parser inputs and excluded from default search. Do not reformat or archive them without updating scripts/tests.
- Deferred features remain out of scope unless explicitly requested: public directory, direct booking, payments, realtime chat, attachments, maps/calendar integrations, moderation/disputes, and admin tooling. T-157 APNs database foundation is remotely applied, but push dispatch is not deployed until APNs secrets exist.
- Large Swift context risks remain `CustomerRequestsView.swift` and `GroomerProfileManagementView.swift`; split only in a dedicated Standard refactor task.
- T-155 installed private reusable request-match insertion plus backfill triggers for groomer activation and availability-related changes.
- T-154 installed `pg_cron` 1.6.4 and scheduled `groomly_expire_grooming_requests` every 5 minutes to call `app_private.expire_grooming_requests(250)`.
- T-156 added durable customer booking handoff acknowledgement read state with `UserDefaults` fallback and applied the backing table/RLS/RPC migration.
- T-157 applied customer APNs token registration tables/RPCs, push delivery state, new-offer/new-message notification event triggers, and corrective token-validation migrations. The user currently has a free Apple Developer account, so APNs Auth Key / Push Notifications capability is not available yet; `dispatch-customer-push-notifications` is not deployed.
- T-158 moved advisor-flagged public authenticated `SECURITY DEFINER` RPCs behind public `SECURITY INVOKER` wrappers and private `app_private` helpers.
- T-159 rebuilt `app_private.accept_groomer_offer(uuid)` and `app_private.complete_booking(uuid)` without the unread PL/pgSQL variables previously flagged by `supabase db lint`.
- Security advisor currently reports only Auth leaked-password protection. Public authenticated `SECURITY DEFINER` RPC warnings are cleared, and `supabase db lint` reports no schema errors.

## Next Recommended Task

- Use T-160 for the next non-APNs task the user selects. Continue T-157 APNs deployment only after Apple Developer Program credentials are available.
