# Current State

Update this only when project state meaningfully changes. Keep it as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-06
- Updated by: Codex
- Latest completed task: T-151 active Markdown baseline recheck and AGENTS hardening.
- Next task ID: T-152, unless the user explicitly names another task ID or branch.

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

- Last iOS build: `./scripts/ios-build.sh` passed on 2026-07-01 during T-137.
- Last full iOS test: `./scripts/ios-test.sh` passed on 2026-07-01 during T-137.
- Last TestOps unit validation: T-145 `./scripts/testops-unit.sh` passed 24 Node tests.
- Last remote TestOps run: T-145 authorized `matching_baseline` passed 8/8 and cleanup left zero tagged request residue.
- Last docs/workflow validation: T-151 `git diff --check` and `node scripts/context-hygiene-check.mjs` passed before closeout.
- Known live failing behavior: none currently recorded.

## Active Product State

- MVP marketplace flow is complete at the current contract level: customer request -> groomer offers -> customer accepts -> booking/chat -> groomer completes -> customer reviews.
- Production uses real Supabase Auth, authoritative profile loading, and customer/groomer role separation. No production path fabricates a session/profile.
- Implemented iOS areas include Auth, role onboarding, customer pets, customer requests/offers, groomer requests/offers, bookings, text chat, groomer profile/services/portfolio, Customer Account profile settings, Debug Console, and TestOps support.
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
- Deferred features remain out of scope unless explicitly requested: public directory, direct booking, payments, realtime chat, attachments, push notifications, maps/calendar integrations, moderation/disputes, and admin tooling.
- Large Swift context risks remain `CustomerRequestsView.swift` and `GroomerProfileManagementView.swift`; split only in a dedicated Standard refactor task.

## Next Recommended Task

- No active next executable product task is defined. Wait for the user to choose the next bugfix, screenshot UI task, TestOps task, backend task, or code-context refactor.
