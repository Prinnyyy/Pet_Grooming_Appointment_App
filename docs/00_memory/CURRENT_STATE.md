# Current State

Update this only when project state meaningfully changes. Keep this file as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-02
- Updated by: Codex
- Latest completed task: T-145 TestOps modern Supabase secret support and authorized remote matching run.
- Next task ID: T-146, unless the user explicitly names another task ID or branch.

## Fast Path

- Current task source of truth: `docs/06_tasks/TASK_LEDGER.md`.
- Recent closeouts: `docs/00_memory/WORKLOG.md`.
- Canonical decision log: `docs/07_decisions/DECISION_LOG.md`.
- Full pre-trim worklog archive: `docs/09_frozen/worklogs/WORKLOG_2026-06-20_to_2026-07-01.md`.
- Historical task ledger archive: `docs/09_frozen/task_ledgers/TASK_LEDGER_T-000_TO_T-127_2026-07-01.md`.
- Full pre-trim current-state snapshot: `docs/09_frozen/current_state_snapshots/CURRENT_STATE_2026-07-01_PRE_CONTEXT_TRIM.md`.
- Full pre-trim backend contract snapshot: `docs/09_frozen/backend_contracts/SUPABASE_CONTRACT_2026-07-01_PRE_FAST_PATH_TRIM.md`.
- Detailed historical task records T-001 through T-088 and workflow task records: `docs/09_frozen/task_records_2026-06-26/`.
- Context/recovery access tiers: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`.
- Tooling and validation policy: `docs/05_workflow/TOOLING_POLICY.md`.

## Branch and Baseline

- Current branch baseline: `codex/pet-fit-structure-cleanup`.
- Continue new implementation, bugfix, documentation, commit, and push work from this branch unless the user explicitly names a different branch.
- Remote `origin`: `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App.git`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.
- Do not commit, push, or make remote writes without explicit user approval.

## Build and Validation Baseline

- Last iOS build: `./scripts/ios-build.sh` passed on 2026-07-01 during T-137 using `generic/platform=iOS Simulator`.
- Last full iOS test: `./scripts/ios-test.sh` passed on 2026-07-01 during T-137, including TestOps launch smoke coverage.
- Last docs/workflow validation: T-142 `git diff --check`, active Markdown link check, decision-log reference checks, `.rgignore` behavior checks, seed parser dry-runs, archive path checks, and word-count checks passed.
- Last TestOps unit validation: T-145 `./scripts/testops-unit.sh` passed 24 Node tests covering core, edge, matching evaluation, modern `sb_secret` service credentials, and Auth token normalization.
- Last Supabase CLI readiness: T-139 confirmed sequential `supabase projects list`, `supabase migration list --linked`, and `supabase db push --linked --dry-run` succeed from this checkout.
- Known live failing behavior: none currently recorded.

## Active Product State

- MVP marketplace flow is complete at the current contract level: Customer publishes an open request -> matched groomers make offers -> customer accepts one offer -> booking and chat are created -> groomer completes booking -> customer leaves a review.
- Production routing uses real Supabase Auth, authoritative profile loading, and customer/groomer role separation. No production path fabricates a session/profile.
- Implemented iOS areas include Auth, role onboarding, customer pets, customer requests/offers, groomer requests/offers, bookings, participant text chat, groomer profile/services/portfolio, Customer Account profile settings, Debug Console, and TestOps support.
- Groomly UI adaptation is complete for implemented MVP screens and archived as historical context. Future Groomly UI changes are screenshot-driven rework tasks that must map screenshot modules to existing SwiftUI/Store/repository/model paths or stop for new-feature approval.
- Bulk remote test resources exist in Supabase project `lqmasbuqzvcvtawonjlb`: 50 groomer accounts, 50 customer accounts, and 100 customer pet profiles from T-134/T-135. TestOps `smoke5` lifecycle passed remotely during T-137 and cleaned tagged rows.

## Active Workflow State

- Lightweight single-agent workflow is active at `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Default reads are tiered: read `AGENTS.md`, then only targeted sections of current-state/task/workflow/domain docs required for the task.
- Default `rg` searches honor `.rgignore`, which skips frozen archives, generated artifacts, T-129 seed profile tables, and Groomly HTML. Use `rg --no-ignore` only when an ignored path is explicitly required.
- Do not read full `WORKLOG.md`, full `TASK_LEDGER.md`, Groomly HTML, frozen archives, or machine-readable seed profile tables by default. Use `rg` and narrow `sed -n` reads first.
- After any task that updates durable memory, run the context hygiene check in `docs/05_workflow/CONTEXT_AND_RECOVERY.md`; if limits are exceeded, archive old content before final reporting.
- Completion gates are adaptive by task mode and risk: Micro tasks stay lightweight; Quick docs/workflow tasks usually run only `git diff --check`; Standard app/UI tasks run build validation and simulator launch for visible app changes; Deep tasks require an explicit validation plan.
- Task closeout, durable memory updates, and simulator launch are not required for every small task. They are required when app behavior changes, future runs need the state, screenshot UI work is implemented, the user asks for inspection, or a standalone task file was explicitly requested.
- Screenshot analysis must ignore any long oval Customer/Groomer toggle located above the visible app screen frame; treat it as an external prototype/control annotation, not an app module to map, classify, or implement.

## Supabase and TestOps Guardrails

- Authorized Supabase project: `Pet Groomer Marketplace`, ref `lqmasbuqzvcvtawonjlb`.
- Legacy project `swdiiyypysyxbnfrxxsv` is out of scope; do not inspect or mutate it.
- Linked Supabase CLI commands must run sequentially, never in parallel, to avoid `cli_login_postgres` temporary-login races.
- `SUPABASE_DB_PASSWORD` is not currently needed for normal local linked CLI use while saved credentials remain valid.
- Local `supabase_api_key` / `SUPABASE_SECRET_KEY=sb_secret_...` is not a CLI PAT, not a database password, and not a JWT service-role key. Do not substitute it into scripts that send `SUPABASE_SERVICE_ROLE_KEY` as Bearer auth.
- TestOps accepts either legacy `SUPABASE_SERVICE_ROLE_KEY=eyJ...` or modern `SUPABASE_SECRET_KEY=sb_secret_...` for server verification/cleanup. Modern secret keys are sent as `apikey` only, never Bearer. Seed scripts still expect legacy JWT-shaped service-role keys.
- Matching TestOps is available as `node scripts/testops.mjs run matching --scenario request_matching_eval --matrix matching_baseline`. Dry-run is local/read-only; remote execute creates tagged request rows and still requires explicit authorization, `--execute`, `--cleanup`, and `TESTOPS_REMOTE_WRITE_APPROVED=1`. Authorized T-145 remote matching run passed 8/8 and verified zero tagged request residue.
- Remote data writes, migrations, cleanup, seed execution, commits, pushes, and PRs require explicit user approval.

## Current Known Risks

- Current active context files were trimmed during T-140; use the frozen snapshots when historical detail is genuinely needed.
- `WORKLOG.md`, `TASK_LEDGER.md`, and `CURRENT_STATE.md` are intentionally concise. Do not expand them back into full history.
- `SUPABASE_CONTRACT.md` is now a fast-path backend contract index; use focused backend policy files, migrations, or the frozen pre-trim snapshot only when detailed backend trace is required.
- T-129 seed profile Markdown files are machine-readable inputs for seed/TestOps parsers and are excluded from default `rg` searches. Do not reformat or archive those tables without updating scripts/tests.
- Groomly prototype screens and future uploaded screenshots may show deferred or unsupported ideas. Treat them as visual inspiration unless a separate task authorizes product/backend work.
- Deferred features remain out of scope unless explicitly requested: public directory, direct booking, payments, realtime chat, attachments, push notifications, maps/calendar integrations, moderation/disputes, and admin tooling.
- Large code files remain known future context risks when directly edited: `CustomerRequestsView.swift` and `GroomerProfileManagementView.swift`. Split them only in a dedicated Standard refactor task when touching those surfaces.

## Next Recommended Task

- No active next executable product task is defined. Wait for the user to choose the next bugfix, screenshot UI task, TestOps task, backend task, or code-context refactor.
