# Project Documentation Index

This folder is the durable project memory and coordination layer for Codex. Use it to avoid relying on long conversation context.

## Sections

- `00_memory/`: current state, recent worklog, feature routing, and project memory
- `01_product/`: product definition, user roles, flows, screen inventory, UX, and design system
- `02_architecture/`: iOS/client architecture, data flow, boundaries, error handling, and fixtures
- `03_backend/`: Supabase fast-path contract, RLS/RPC policy, Storage policy, and migration rules
- `04_ios/`: Swift, SwiftUI, build/test, Debug Console, accessibility, and TestOps runbooks
- `05_workflow/`: active workflow, context/recovery, tooling, GitHub, and stop rules
- `06_tasks/`: active task ledger, managed roadmap, screenshot/meta-review templates, and reviewed SQL artifacts
- `07_decisions/`: canonical durable decision log and ADR template
- `08_design/`: Beckon implementation notes, screenshots, and tokens; historical prompts and long design audits live in frozen archives
- `09_frozen/`: frozen history and pre-trim snapshots; default searches should not read it
- `10_project_structure/`: current path map and reorganization history

## Access Model

- L0 startup: `../AGENTS.md`, targeted `00_memory/CURRENT_STATE.md`, targeted `06_tasks/TASK_LEDGER.md`.
- L1 task indexes: this file, `00_memory/FEATURE_INDEX.md`, `03_backend/SUPABASE_CONTRACT.md`, `04_ios/testops/README.md`, `10_project_structure/README.md`.
- L2 domain rules: targeted product, architecture, backend, iOS, TestOps, workflow files.
- L3 trace/history: targeted `WORKLOG.md`, `PROJECT_MEMORY.md`, decision log, and reorganization log.
- L4 frozen/heavy: `09_frozen/**`, Beckon HTML/export, T-129 seed tables, generated artifacts. Read only with a specific reason.

Default searches honor `../.rgignore`. Do not use broad `rg --files -g '*.md'` as the default Markdown inventory because it can re-include ignored seed Markdown.

## Quick Path Lookup

- Agent rules: `../AGENTS.md`
- Current state and branch baseline: `00_memory/CURRENT_STATE.md`
- Task numbering/status source: `06_tasks/TASK_LEDGER.md`
- Managed roadmap: `06_tasks/ROADMAP.md`
- Feature routing index: `00_memory/FEATURE_INDEX.md`
- Canonical brand identity: `01_product/BRAND_IDENTITY.md`
- Workflow rules: `05_workflow/SINGLE_AGENT_WORKFLOW.md`
- Context/recovery and budgets: `05_workflow/CONTEXT_AND_RECOVERY.md`
- Tooling and validation policy: `05_workflow/TOOLING_POLICY.md`
- Git/GitHub rules: `05_workflow/GITHUB_RULES.md`
- Stop conditions: `05_workflow/STOP_CONDITIONS.md`
- Context hygiene check: `../scripts/context-hygiene-check.mjs`
- Durable decisions: `07_decisions/DECISION_LOG.md`; frozen full snapshots: `09_frozen/decisions/`
- Project structure map: `10_project_structure/README.md`
- Test resource index: `02_architecture/test_resources/README.md`
- TestOps index: `04_ios/testops/README.md`
- Design screenshots: `08_design/screenshots/`
- Frozen archive guide: `09_frozen/README.md`

## Current Baseline

The canonical work branch is `codex/pet-fit-structure-cleanup` unless the user explicitly names another branch. New bugfix and iteration work should use the next available task ID from `06_tasks/TASK_LEDGER.md`.

Detailed task records T-001 through T-088 are archived under `09_frozen/task_records_2026-06-26/`. Use `06_tasks/TASK_LEDGER.md` as the single active task-status and task-numbering record.

Keep active memory and policy files compact. When a file exceeds the budgets in `05_workflow/CONTEXT_AND_RECOVERY.md`, archive old content under the matching `09_frozen/` family and keep only current facts/indexes active.

This index does not define active work. Start new work only from an explicit user request and the next available task ID in `06_tasks/TASK_LEDGER.md`.
