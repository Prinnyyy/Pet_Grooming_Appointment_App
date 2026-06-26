# Project Documentation Index

This folder is the durable project memory and coordination layer for Codex.

Use it to avoid relying on long conversation context.

## Sections

- `00_memory/`: current state, worklog, feature index, project memory, and decision log
- `01_product/`: product definition, user roles, flows, design system
- `02_architecture/`: iOS/client architecture and module boundaries
- `03_backend/`: Supabase schema, RLS, RPC, storage, migrations
- `04_ios/`: Swift, SwiftUI, build, testing, accessibility rules
- `05_workflow/`: active lightweight single-agent workflow, context/recovery guide, tooling policy, and stop rules
- `06_tasks/`: active task ledger, templates, handoff notes, review template
- `07_decisions/`: ADRs and decision templates
- `08_design/`: Groomly prototype, normalized screenshots, design prompt, implementation notes, and extracted design tokens
- `09_frozen/`: frozen historical snapshots, detailed task records, disabled agent roles, archived workflow docs/reports, and setup prompts
- `10_project_structure/`: current path map and reorganization history

## Quick Path Lookup

- Current structure map: `10_project_structure/README.md`
- Structure change log: `10_project_structure/REORGANIZATION_LOG.md`
- Task folder guide: `06_tasks/README.md`
- Reviewed SQL task drafts: `06_tasks/sql_reviews/`
- Design screenshots: `08_design/screenshots/`
- Frozen archive guide: `09_frozen/README.md`
- Frozen detailed task records: `09_frozen/task_records_2026-06-26/`
- Frozen Superpowers plans/specs: `09_frozen/superpowers_2026-06-26/`
- Frozen consolidated workflow docs: `09_frozen/workflow_docs_2026-06-26/`
- Frozen workflow archive: `09_frozen/workflow_archive_2026-06-24/`
- Frozen disabled agent archive: `09_frozen/agent_team_archive_2026-06-24/`
- Deployed/prepared Supabase migration mirrors: `../supabase/migrations/`
- SwiftUI source root: `../ios/PetGroomerMarketplace/PetGroomerMarketplace/`

## Current Baseline

Use these active files first:

- Current state and branch baseline: `00_memory/CURRENT_STATE.md`
- Task numbering and status source: `06_tasks/TASK_LEDGER.md`
- Workflow rules: `05_workflow/SINGLE_AGENT_WORKFLOW.md`
- Context/recovery access tiers: `05_workflow/CONTEXT_AND_RECOVERY.md`
- Tooling and validation policy: `05_workflow/TOOLING_POLICY.md`
- Project structure map: `10_project_structure/README.md`

The canonical work branch is `codex/pet-fit-structure-cleanup` unless the user explicitly names another branch. New bugfix and iteration work should use the next available task ID from the ledger instead of reopening completed task records.

Detailed task records T-001 through T-088 were merged out of the active task directory and archived under `09_frozen/task_records_2026-06-26/`. Use `06_tasks/TASK_LEDGER.md` as the single active task-status and task-numbering record.

The Groomly UI foundation and completion sequences are completed for implemented MVP screens; their detailed historical records are in the task-record archive.

No active next Groomly UI, pet-fit, availability, backend, or screenshot task is currently defined. Start new work only from an explicit user request and the next available task ID.

Read active docs progressively. Start with the files above, then open product, architecture, backend, iOS, design, workflow, or frozen files only when the task requires that domain.

T-022 remains completed, but its post-MVP next-task suggestions are frozen and must not auto-start. Use `09_frozen/pre_groomly_ui_2026-06-21/` only to recover or compare pre-Groomly context.
