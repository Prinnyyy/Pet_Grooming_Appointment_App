# Current State

Update this only when project state meaningfully changes. Keep it as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-08
- Updated by: Codex
- Latest completed task: T-176 Entrypoint and branch fact-source alignment.
- Current task: none active; T-157 APNs deployment remains externally blocked.
- Next task ID: use T-177 unless the user resumes T-157 after Apple Developer Program upgrade.

## Fast Path

- Task source of truth: `docs/06_tasks/TASK_LEDGER.md`.
- Managed roadmap: `docs/06_tasks/ROADMAP.md`.
- Recent closeouts: `docs/00_memory/WORKLOG.md`.
- Canonical decision log: `docs/07_decisions/DECISION_LOG.md`.
- Feature routing: `docs/00_memory/FEATURE_INDEX.md`.
- Workflow: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Context/recovery/budgets: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`.
- Tooling/validation/remote writes: `docs/05_workflow/TOOLING_POLICY.md`.
- Git/GitHub rules: `docs/05_workflow/GITHUB_RULES.md`.
- Context hygiene command: `node scripts/context-hygiene-check.mjs`.
- Frozen archive guide: `docs/09_frozen/README.md`.

Frozen history lives under `docs/09_frozen/`.

## Branch and Baseline

- Current branch baseline: `codex/pet-fit-structure-cleanup`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.
- Continue implementation, documentation, commit, and push work from this branch unless the user explicitly names another branch.
- Do not treat `main` as the current work baseline. T-173 reviewed main-only commit `2fddf7b`; it is superseded and must not be merged back into this branch.
- Do not commit, push, create PRs, seed, cleanup, migrate, or make remote writes without explicit user approval.

## Validation Baseline

- Last iOS build: `./scripts/ios-build.sh` passed on 2026-07-07 during T-162 closeout.
- Last full iOS test attempt: `./scripts/ios-test.sh` on 2026-07-07 failed the known T-153 `CustomerNotificationsStoreTests.markAllReadReplacesNotificationsWithRepositoryResult()` same-timestamp ordering assertion; UI smoke tests passed 3/3, and targeted `AuthenticationStoreTests` passed afterward.
- Last Supabase migration apply: authorized `supabase db push --linked` applied `20260707191034_t160_account_deletion.sql` to project `lqmasbuqzvcvtawonjlb` on 2026-07-07.
- Last Supabase live post-apply validation: T-160 migration list confirmed local/remote parity for `20260707191034`; metadata SQL verified account deletion table/RLS/grants/RPCs; security/performance advisors ran; `supabase functions deploy delete-account` and `supabase functions list` confirmed `delete-account` is ACTIVE with JWT verification on. Post-apply `supabase db push --linked --dry-run` and `supabase db lint --linked` could not rerun because `SUPABASE_DB_PASSWORD` is not configured for direct Postgres CLI connections.
- Prepared unapplied Supabase migration: none known by `supabase migration list --linked`; post-apply dry-run requires `SUPABASE_DB_PASSWORD`.
- Last TestOps unit validation: T-145 `./scripts/testops-unit.sh` passed 24 Node tests.
- Last remote TestOps run: T-155 authorized `matching_baseline` run `TESTOPS-T155-MATCH-20260706-*` passed 8/8 and cleanup left zero tagged request/match residue.
- Last docs/workflow validation: T-176 entrypoint/fact-source update, `git diff --check`, and context hygiene passed on 2026-07-08.
- Known validation failure: full `./scripts/ios-test.sh` is currently blocked by the existing T-153 customer notification same-timestamp ordering test, not by T-162 cancellation repost work.

## Active Product State

- MVP marketplace flow is complete at the current contract level: customer request -> groomer offers -> customer accepts -> booking/chat -> groomer completes -> customer reviews.
- Production uses real Supabase Auth, authoritative profile loading, and customer/groomer role separation. No production path fabricates a session/profile.
- Implemented iOS areas include Auth, role onboarding, customer pets, customer requests/offers, customer in-app notifications, groomer requests/offers, groomer submitted-offer tracking, bookings, text chat, groomer profile/services/portfolio, Customer Account profile settings, Debug Console, and TestOps support.
- Customers can create a new request from cancelled requests and cancelled bookings. The flow reuses the existing request wizard at Review, pre-fills from the original request, and creates a new request id on publish.
- Groomly UI adaptation is complete for implemented MVP screens. Future UI work is screenshot-driven and must map screenshot modules to existing SwiftUI/Store/repository/model paths or stop for new-feature approval.

## Active Workflow State

- Default context model is L0-L4 in `CONTEXT_AND_RECOVERY.md`.
- Startup reads stay minimal: `AGENTS.md`, then targeted current-state/task-ledger sections only when needed.
- Periodic documentation-governance reviews use `docs/06_tasks/META_REVIEW_TEMPLATE.md` every 10 completed tasks or weekly.
- Last meta-review: T-175 on 2026-07-08.
- Changes to `AGENTS.md`, `CLAUDE.md`, or `docs/05_workflow/**` must be standalone numbered tasks with a decision-log entry and context hygiene.
- Main reconciliation: `2fddf7b` is reviewed/superseded. Future alignment should carry this branch's governed docs forward or cherry-pick only explicitly reviewed non-stale changes.
- Decision log is an active index backed by frozen snapshots. The pre-T-174 full text lives in `docs/09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.
- Default `rg` searches honor `.rgignore`; do not use broad `rg --files -g '*.md'` as the default Markdown inventory.
- Do not read full `WORKLOG.md`, full `TASK_LEDGER.md`, frozen archives, Groomly HTML/export, or T-129 seed tables by default.
- After durable memory, ledger, workflow, or coordination-doc changes, run `node scripts/context-hygiene-check.mjs`; it now checks budgets plus last-verified freshness, migration mirror count, ROADMAP/ledger evidence, Feature Index paths, fail-closed current facts, meta-review cadence, and ledger row length.

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
- The original root product/engineering brief, old Groomly design task prompt, pre-slim design notes, removed memory pointer, removed generic/lightweight templates, old Claude reference snapshots, and external agent audit drafts are archived under `docs/09_frozen/`; use `docs/06_tasks/ROADMAP.md`, `docs/01_product/PRODUCT_BRIEF.md`, `docs/01_product/DESIGN_SYSTEM.md`, `docs/08_design/UI_IMPLEMENTATION_NOTES.md`, `docs/07_decisions/DECISION_LOG.md`, `CLAUDE.md`, and active workflow/task docs as entrypoints. External agent reports are review input only and must not reset branch, task ID, validation, or product status.
- T-129 seed profile Markdown files are machine-readable parser inputs and excluded from default search. Do not reformat or archive them without updating scripts/tests.
- Deferred features remain out of scope unless explicitly requested: public directory, direct booking, payments, realtime chat, attachments, maps/calendar integrations, moderation/disputes, and admin tooling. Customer in-app notifications are active, and the T-157 APNs database/iOS foundation is remotely applied, but push dispatch is not deployed until paid Apple Developer credentials and APNs secrets exist.
- Large Swift context risks remain `CustomerRequestsView.swift` and `GroomerProfileManagementView.swift`; split only in a dedicated Standard refactor task.
- Recent applied backend/app tasks T-153 through T-162 are recorded in `TASK_LEDGER.md`, `WORKLOG.md`, migrations, and source. Active cross-task risks to remember: known T-153 notification ordering test failure, T-157 APNs deployment block, T-160 App Store Privacy Policy/Support URL blockers, and T-162 cancelled-booking repost dependency on loading the original request.
- Current-remote advisors report baseline `customer_push_tokens` RLS/no-policy INFO, Auth leaked-password protection WARN, existing performance INFOs, and expected fresh-index INFO for T-160. Public authenticated `SECURITY DEFINER` RPC warnings are cleared.

## Next Recommended Task

- Use T-177 next unless resuming T-157 after Apple Developer credentials. Suggested governance candidate: batch D cleanup/ROADMAP DoD expansion from the archived review fix plan; product candidate remains realtime chat.
