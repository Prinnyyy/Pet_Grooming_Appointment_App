# Project Documentation Index

This folder is the durable project memory and coordination layer. It is designed for indexed, minimal reads.

## Access Model

| Layer | Default Rule | Use |
|---|---|---|
| L0 | Read every task | `../AGENTS.md`; targeted top sections of `00_memory/CURRENT_STATE.md` and `06_tasks/TASK_LEDGER.md` only when needed |
| L1 | Read by task type | `00_memory/FEATURE_INDEX.md`, `03_backend/SUPABASE_CONTRACT.md`, `04_ios/IOS_BUILD_AND_TESTING.md`, `05_workflow/README.md`, `10_project_structure/README.md` |
| L2 | Targeted section only | Product, architecture, backend, iOS, TestOps, and workflow manuals |
| L3 | Targeted recovery | `00_memory/WORKLOG.md`, `07_decisions/DECISION_LOG.md`, project structure logs |
| L4 | Default forbidden | `09_frozen/**`, generated artifacts, full design exports, seed tables, old task records |

## Sections

- `00_memory/`: current state, feature index, project memory, recent worklog.
- `01_product/`: product rules, roles, flows, screen inventory, design system.
- `02_architecture/`: iOS architecture, module boundaries, data flow, fixtures.
- `03_backend/`: Supabase contract, RLS/RPC, Storage, migration rules.
- `04_ios/`: Swift, SwiftUI, build, testing, accessibility rules.
- `05_workflow/`: active workflow, context/recovery, tooling, stop rules.
- `06_tasks/`: compact ledger and task templates only.
- `07_decisions/`: durable decision log and ADR template.
- `08_design/`: current visual notes, tokens, and design assets.
- `09_frozen/`: historical archive; use only with a targeted recovery reason.
- `10_project_structure/`: path ownership and reorganization log.

## Current Task State

Use `06_tasks/TASK_LEDGER.md` for task numbering and active/recent status. Detailed T-001 through T-048 task records are archived under `09_frozen/task_records_2026-07-06/`.

Run `node ../scripts/context-hygiene-check.mjs` after durable memory or task-ledger edits.
