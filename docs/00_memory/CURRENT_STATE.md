# Current State

Update this only when project state meaningfully changes. Keep it as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-09
- Updated by: Codex
- Latest completed task: T-235 remote TestOps lifecycle and matching evidence.
- Current task: none; T-157 APNs remains externally blocked.
- Next task ID: use T-236 unless the user resumes T-157 after Apple Developer Program upgrade.

## Fast Path

- Task source of truth: `docs/06_tasks/TASK_LEDGER.md`.
- Managed roadmap: `docs/06_tasks/ROADMAP.md`.
- Roadmap execution queue: `docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md`.
- Closeouts: `docs/00_memory/WORKLOG.md`.
- Decisions: `docs/07_decisions/DECISION_LOG.md`.
- Feature/workflow routing: `docs/00_memory/FEATURE_INDEX.md`, `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`, `docs/05_workflow/CONTEXT_AND_RECOVERY.md`, `docs/05_workflow/TOOLING_POLICY.md`, `docs/05_workflow/GITHUB_RULES.md`.
- Context hygiene command: `node scripts/context-hygiene-check.mjs`.
- Frozen archives: `docs/09_frozen/README.md`.

## Branch and Baseline

- Current branch baseline: `codex/pet-fit-structure-cleanup`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.
- Continue implementation, docs, commit, and push work from this branch unless the user names another branch.
- Do not treat `main` as the current work baseline. T-173 reviewed main-only commit `2fddf7b`; it is superseded and must not be merged back into this branch.
- Standing Git approval is active: after required validation passes, commit and push each completed task's own changes on this branch automatically.
- PRs, tags, branch deletion, merge/rebase/reset, seeds, migrations, Supabase writes, repository settings, and other non-Git remote writes require approval. Authorization covers queued Q-35, Q-36, Q-37, and Q-42; it excludes future work and Q-92/Q-93 prerequisites.

## Validation Baseline

- T-235 TestOps units/doctor/dry-runs, remote lifecycle 5/5, matching 8/8, artifact safety scans, and zero-residue checks passed.
- Recent focused coverage: T-224 customer request test split; T-225 groomer profile test split; T-226 groomer profile store split; T-230 four request/offer pagination retry/dedupe/end cases.
- Last Supabase migration apply: T-234 `20260709214425_t234_add_evidence_backed_fk_indexes.sql` applied to `lqmasbuqzvcvtawonjlb` on 2026-07-09; parity, catalog, forced plans, and advisor delta were verified.
- Last Edge Function deploy: `delete-account` version 2 is active with JWT verification and service-role Storage API cleanup across six user-prefixed image buckets.
- Last TestOps unit validation: T-222 `./scripts/testops-unit.sh` passed 24 Node tests.
- Last TestOps dry-run: T-222 doctor, marketplace `smoke5`, and matching baseline passed without remote writes.
- Last release readiness dry run: T-222 recorded final local/read-only ideal-operation evidence with Auth/APNs and index-tuning advisor findings.
- Last remote TestOps run: T-155 authorized `matching_baseline` passed 8/8 and cleanup left zero tagged request/match residue.
- Latest remote TestOps evidence: T-235 `smoke5` passed 5/5 and `matching_baseline` passed 8/8; both R2 run families left zero tagged requests and only redacted local artifacts.
- Known iOS validation failure: none currently recorded.

## Active Product State

- MVP marketplace flow is complete at the current contract level: customer request -> groomer offers -> customer accepts -> booking/chat -> groomer completes -> customer reviews.
- Production uses real Supabase Auth, authoritative profile loading, and role separation. No production path fabricates a session/profile.
- Auth email/deep-link design is documented. T-217 implements the local iOS custom-scheme callback path; Supabase Auth redirect allow-list, production auth domain, SMTP credentials, HTTPS universal links, and associated domains still require explicit remote/config authorization.
- Implemented iOS areas include auth/onboarding, marketplace flow, notifications, foreground chat, profile/account surfaces, privacy/support links, private images, Debug Console, ops evidence, accessibility/copy checks, and TestOps.
- Customer/groomer tab roots load shared notification/chat badge sources. Customer Home, Messages, and groomer Alerts display badges; chat unread state is local/session-scoped and clears on thread open.
- Customer request UI and groomer profile UI were split into focused SwiftUI files in T-211/T-212.
- Request, offer, booking, message, and notification repositories use bounded first-page list reads with a shared limit+1 page contract. Customer requests/offers and groomer requests/offers now expose explicit shared Load More controls with retry, dedupe, and terminal-page state; booking, notification, and chat UI paging remain queued.
- Private Storage images use authenticated `.download(path:)` through `PrivateImageLoader`; cache hashes paths, retries transient downloads once, and clears on local account cleanup.
- Customers can create a new request from cancelled requests/bookings via explicit republish. Republish tolerates missing request photos and expired preferred windows. Unpublished wizard drafts are sheet-ephemeral.
- Groomly UI adaptation is complete for implemented MVP screens. Future UI work is screenshot-driven and must map modules to existing SwiftUI/Store/repository/model paths or stop for approval.

## Active Workflow State

- Default context model is L0-L4 in `CONTEXT_AND_RECOVERY.md`.
- Startup reads stay minimal: `AGENTS.md`, then targeted current-state/task-ledger sections only when needed.
- Periodic documentation-governance reviews use `docs/06_tasks/META_REVIEW_TEMPLATE.md` every 10 completed tasks or weekly.
- Last meta-review: T-229 on 2026-07-09.
- V1.0 ideal-operation Q-16...Q-38 are complete. Q-39...Q-41 remain local work; dependent Q-42 retains remote authorization.
- Changes to `AGENTS.md`, `CLAUDE.md`, or `docs/05_workflow/**` must be standalone numbered tasks with a decision-log entry and context hygiene.
- T-180 records standing user approval for task-completion Git commit and push. This approval is limited to current-task changes after validation passes; T-186 requires stopping without auto pull/rebase/merge/reset/force-push if the push fails or is rejected.
- T-184 keeps active Markdown under a 36k hard limit, 95% structural-review warning, and deterministic `node scripts/context-rotate.mjs` archive rotation.
- Main reconciliation: `2fddf7b` is reviewed/superseded; carry this branch's governed docs forward.
- Decision log is an active index backed by frozen snapshots. The pre-T-174 full text lives in `docs/09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.
- Default `rg` searches honor `.rgignore`; do not use broad `rg --files -g '*.md'` as the default Markdown inventory.
- Do not read full `WORKLOG.md`, full `TASK_LEDGER.md`, frozen archives, Groomly HTML/export, or T-129 seed tables by default.
- After durable memory, ledger, workflow, or coordination-doc changes, run context hygiene; rotate active records if the rolling-window caps fail.

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
- T-234 applied the 2 T-228-evidenced FK indexes; the remaining 10 FK advisor findings already have usable indexes, and no unused index is safe to remove. Auth/APNs findings remain Q-93/excluded.

## Next Recommended Task

- Use T-236 for Q-39 booking and notification pagination.
