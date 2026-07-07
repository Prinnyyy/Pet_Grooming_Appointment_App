# Current State

Update this only when project state meaningfully changes. Keep it as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-07
- Updated by: Codex
- Latest completed task: T-161 App Store privacy baseline.
- Current task: none active; T-157 APNs deployment remains externally blocked.
- Next task ID: use T-162 unless the user resumes T-157 after Apple Developer Program upgrade.

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

- Last iOS build: `./scripts/ios-build.sh` passed on 2026-07-07 during T-161 closeout.
- Last full iOS test attempt: `./scripts/ios-test.sh` on 2026-07-07 failed the known T-153 `CustomerNotificationsStoreTests.markAllReadReplacesNotificationsWithRepositoryResult()` same-timestamp ordering assertion; UI smoke tests passed 3/3, and targeted `AuthenticationStoreTests` passed afterward.
- Last Supabase migration apply: authorized `supabase db push --linked` applied `20260707191034_t160_account_deletion.sql` to project `lqmasbuqzvcvtawonjlb` on 2026-07-07.
- Last Supabase live post-apply validation: T-160 migration list confirmed local/remote parity for `20260707191034`; metadata SQL verified account deletion table/RLS/grants/RPCs; security/performance advisors ran; `supabase functions deploy delete-account` and `supabase functions list` confirmed `delete-account` is ACTIVE with JWT verification on. Post-apply `supabase db push --linked --dry-run` and `supabase db lint --linked` could not rerun because `SUPABASE_DB_PASSWORD` is not configured for direct Postgres CLI connections.
- Prepared unapplied Supabase migration: none known by `supabase migration list --linked`; post-apply dry-run requires `SUPABASE_DB_PASSWORD`.
- Last TestOps unit validation: T-145 `./scripts/testops-unit.sh` passed 24 Node tests.
- Last remote TestOps run: T-155 authorized `matching_baseline` run `TESTOPS-T155-MATCH-20260706-*` passed 8/8 and cleanup left zero tagged request/match residue.
- Last docs/workflow validation: T-161 `git diff --check` and context hygiene passed on 2026-07-07.
- Known validation failure: full `./scripts/ios-test.sh` is currently blocked by the existing T-153 customer notification same-timestamp ordering test, not by T-160 account deletion.

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
- T-160 adds account deletion audit/anonymization RPCs, service-role status RPCs, a deployed `delete-account` Edge Function, Account double-confirm delete UI, and local snapshot cleanup. The Edge Function uses authenticated user context and Supabase Auth admin soft delete (`deleteUser(user_id, true)`) after database anonymization.
- T-161 adds `PrivacyInfo.xcprivacy` to the iOS app, documents App Store Connect privacy/support URL blockers, and records the Groomly 1.0 privacy nutrition-label posture. Real production Privacy Policy URL and Support URL remain required before App Store metadata submission.
- Current-remote advisors report baseline security INFO for `customer_push_tokens` RLS-enabled/no-policy, Auth leaked-password protection WARN, and existing performance INFOs for unindexed foreign keys/unused indexes. T-160 also adds a new expected unused-index INFO for `account_deletion_requests_user_status_idx` immediately after creation. Public authenticated `SECURITY DEFINER` RPC warnings are cleared.

## Next Recommended Task

- Use T-162 for the next non-APNs task. Continue T-157 APNs deployment only after Apple Developer Program credentials are available.
