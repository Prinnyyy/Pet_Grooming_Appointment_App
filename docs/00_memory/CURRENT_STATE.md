# Current State

Update this only when project state meaningfully changes. Keep it as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-09
- Updated by: Codex
- Latest completed task: T-216 State-machine edge tests.
- Current task: none; T-157 APNs remains externally blocked.
- Next task ID: use T-217 unless the user resumes T-157 after Apple Developer Program upgrade.

## Fast Path

- Task source of truth: `docs/06_tasks/TASK_LEDGER.md`.
- Managed roadmap: `docs/06_tasks/ROADMAP.md`.
- Roadmap execution queue: `docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md`.
- Closeouts: `docs/00_memory/WORKLOG.md`.
- Decisions: `docs/07_decisions/DECISION_LOG.md`.
- Feature routing: `docs/00_memory/FEATURE_INDEX.md`.
- Workflow: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Context/recovery: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`.
- Tooling/validation/remote writes: `docs/05_workflow/TOOLING_POLICY.md`.
- Git/GitHub rules: `docs/05_workflow/GITHUB_RULES.md`.
- Context hygiene command: `node scripts/context-hygiene-check.mjs`.
- Frozen archives: `docs/09_frozen/README.md`.

## Branch and Baseline

- Current branch baseline: `codex/pet-fit-structure-cleanup`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.
- Continue implementation, docs, commit, and push work from this branch unless the user names another branch.
- Do not treat `main` as the current work baseline. T-173 reviewed main-only commit `2fddf7b`; it is superseded and must not be merged back into this branch.
- Standing Git approval is active: after required validation passes, commit and push each completed task's own changes on this branch automatically.
- PRs, tags, branch deletion, merge/rebase/reset, seeds, migrations, Supabase writes, repository settings, and other non-Git remote writes require approval.

## Validation Baseline

- Last iOS build/test: `./scripts/ios-build.sh` and `./scripts/ios-test.sh` passed on 2026-07-09 during T-216 state-machine edge tests.
- Last focused iOS validation: T-216 AppointmentReminderPlan tests covered duplicate booking rows and idempotent reminder planning by stable reminder identifier.
- Last backend contract focused validation: T-213 time-boundary tests covered request-day matching, availability, time-off/advance/daily-capacity gates, expiry edges, and service size-band limits.
- Last Supabase migration apply: T-160 applied `20260707191034_t160_account_deletion.sql` to `lqmasbuqzvcvtawonjlb` on 2026-07-07 and confirmed parity/RLS/grants/RPCs/advisors/deployment.
- Prepared unapplied Supabase migration: T-203 `20260709073051_t203_groomer_notifications.sql` is local-only until explicit remote migration authorization.
- Last TestOps unit validation: T-201 `./scripts/testops-unit.sh` passed 24 Node tests.
- Last TestOps dry-run validation: T-201 `doctor --dry-run`, marketplace `smoke5` dry-run, matching baseline dry-run, and TestOps launch smoke passed without remote writes.
- Last release readiness dry run: T-201 recorded local/read-only evidence; advisors had only the known Auth leaked-password protection WARN.
- Last remote TestOps run: T-155 authorized `matching_baseline` passed 8/8 and cleanup left zero tagged request/match residue.
- Recent focused validations: T-206 offer, T-208 notification, T-209 reminder, T-210 chat/badge, T-214 decode/cache, T-215 republish, and T-216 reminder idempotence tests passed.
- Last docs validation: T-216 context hygiene and `git diff --check` passed on 2026-07-09.
- Known iOS validation failure: none currently recorded; full `./scripts/ios-test.sh` passed during T-201.

## Active Product State

- MVP marketplace flow is complete at the current contract level: customer request -> groomer offers -> customer accepts -> booking/chat -> groomer completes -> customer reviews.
- Production uses real Supabase Auth, authoritative profile loading, and role separation. No production path fabricates a session/profile.
- Auth email/deep-link design is documented; Q-07 waits for production auth domain and SMTP credentials.
- Implemented iOS areas include auth/role onboarding, customer pets/requests/offers/notifications, groomer requests/offers, bookings/reviews, foreground chat, profile/account surfaces, privacy/support links, private images, Debug Console, ops evidence, accessibility/copy checks, and TestOps.
- Customer/groomer tab roots load shared notification/chat badge sources. Customer Home, Messages, and groomer Alerts display badges; chat unread state is local/session-scoped and clears on thread open.
- Customer request UI and groomer profile UI were split into focused SwiftUI files in T-211/T-212.
- Private Storage images use authenticated `.download(path:)` through `PrivateImageLoader`; cache hashes paths, retries transient downloads once, and clears on local account cleanup.
- Customers can create a new request from cancelled requests/bookings via explicit republish. Republish tolerates missing request photos and expired preferred windows. Unpublished wizard drafts are sheet-ephemeral.
- Groomly UI adaptation is complete for implemented MVP screens. Future UI work is screenshot-driven and must map modules to existing SwiftUI/Store/repository/model paths or stop for approval.

## Active Workflow State

- Default context model is L0-L4 in `CONTEXT_AND_RECOVERY.md`.
- Startup reads stay minimal: `AGENTS.md`, then targeted current-state/task-ledger sections only when needed.
- Periodic documentation-governance reviews use `docs/06_tasks/META_REVIEW_TEMPLATE.md` every 10 completed tasks or weekly.
- Last meta-review: T-207 on 2026-07-09.
- V1.0 ideal-operation packages are adopted in `docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md`; Q-16...Q-28 are complete, and sequencing continues at Q-29.
- Changes to `AGENTS.md`, `CLAUDE.md`, or `docs/05_workflow/**` must be standalone numbered tasks with a decision-log entry and context hygiene.
- T-180 records standing user approval for task-completion Git commit and push. This approval is limited to current-task changes after validation passes; T-186 requires stopping without auto pull/rebase/merge/reset/force-push if the push fails or is rejected.
- T-184 keeps active Markdown under a 36k hard limit, 95% structural-review warning, and deterministic `node scripts/context-rotate.mjs` archive rotation.
- Main reconciliation: `2fddf7b` is reviewed/superseded. Future alignment should carry this branch's governed docs forward or cherry-pick only explicitly reviewed non-stale changes.
- Decision log is an active index backed by frozen snapshots. The pre-T-174 full text lives in `docs/09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.
- Default `rg` searches honor `.rgignore`; do not use broad `rg --files -g '*.md'` as the default Markdown inventory.
- Do not read full `WORKLOG.md`, full `TASK_LEDGER.md`, frozen archives, Groomly HTML/export, or T-129 seed tables by default.
- After durable memory, ledger, workflow, or coordination-doc changes, run `node scripts/context-hygiene-check.mjs`; if it reports rolling-window overflow, run `node scripts/context-rotate.mjs --apply` and rerun hygiene. A 95% active-Markdown warning schedules structural review instead of immediate compression.

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
- Historical briefs, Groomly prompts, pre-slim notes, removed pointers/templates, Claude snapshots, and external audits are frozen under `docs/09_frozen/`. T-185 moved remaining root external drafts into `docs/09_frozen/external_agent_reports/`. Active entrypoints are ROADMAP, PRODUCT_BRIEF, DESIGN_SYSTEM, UI_IMPLEMENTATION_NOTES, DECISION_LOG, CLAUDE, and workflow/task docs. External reports are review input only.
- T-129 seed profile Markdown files are machine-readable parser inputs and excluded from default search. Do not reformat or archive them without updating scripts/tests.
- Deferred unless explicitly requested: public directory, direct booking, payments, chat attachments/read receipts, maps/calendar integrations, moderation/disputes, admin tooling.
- Customer in-app notifications are active. T-157 APNs database/iOS foundation is remotely applied; push dispatch waits for Apple Developer credentials and APNs secrets.
- Large Swift context risks `CustomerRequestsView.swift` and `GroomerProfileManagementView.swift` were split in T-211/T-212.
- Active cross-task risk: T-157 APNs deployment remains blocked.
- Current linked advisors: T-201 security shows only Auth leaked-password protection WARN; performance shows no issues. Public authenticated `SECURITY DEFINER` RPC warnings are cleared.

## Next Recommended Task

- Use T-217 next. Recommended package is Q-29 free-tier email verification/deep link. T-203 migration remains local-only until explicit remote apply authorization. Q-90...Q-92 remain blocked on Apple/APNs/release or production SMTP credentials.
