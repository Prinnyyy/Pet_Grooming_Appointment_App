# Frozen Archives

This directory contains historical material that should not be part of the active daily search path.

Use these files only for recovery, comparison, or historical workflow context.

Archived files may contain old TODOs, old paths, old branch/task references, or then-current next-task notes. Do not treat those as current project state. Current branch, task numbering, workflow, product, architecture, and backend facts live in the active `docs/00_memory/`, `docs/01_product/`, `docs/02_architecture/`, `docs/03_backend/`, `docs/05_workflow/`, and `docs/06_tasks/` files.

## Archives

- `pre_groomly_ui_2026-06-21/`: snapshot from before the Groomly UI phase.
- `groomly_ui_completed_2026-06-22/`: completed Groomly UI phase archive marker.
- `agent_team_archive_2026-06-24/`: disabled historical `.codex` role cards and agent definitions.
- `workflow_archive_2026-06-24/`: superseded subagent workflow docs and old agent reports.
- `task_records_2026-06-26/`: detailed historical T-001 through T-088 and workflow policy task records. Current task state lives in `docs/06_tasks/TASK_LEDGER.md`.
- `superpowers_2026-06-26/`: historical Superpowers plans/specs moved out of the active docs tree.
- `workflow_docs_2026-06-26/`: superseded context, recovery, tool, MCP, Superpowers, and Codex workflow docs consolidated into active workflow entrypoints.
- `workspace_initialization_2026-06-24/`: original workspace initialization prompt.
- `current_state_snapshots/`: pre-trim snapshots of active `CURRENT_STATE.md` before context-footprint cleanup.
- `worklogs/`: verbatim archived worklog entries moved out of active `docs/00_memory/WORKLOG.md`.
- `task_ledgers/`: archived completed task-ledger rows moved out of active `docs/06_tasks/TASK_LEDGER.md`.
- `backend_contracts/`: archived long-form `docs/03_backend/SUPABASE_CONTRACT.md` snapshots moved out of the active fast-path backend contract.
- `backend_policies/`: archived pre-trim backend policy/runbook files such as RLS/RPC, Storage, and migration rules.
- `feature_indexes/`: archived pre-trim feature index snapshots moved out of the active routing index.
- `design_prompts/`: archived historical design-task prompts moved out of active design context.
- `design_notes/`: archived pre-slim design-system and Groomly UI audit notes moved out of active design context.
- `product_briefs/`: archived original product/engineering briefs moved out of active root context.
- `memory_pointers/`: removed compatibility pointers that no longer need active paths.
- `workflow_templates/`: removed low-use workflow templates whose rules now live in active workflow docs.
- `task_templates/`: removed generic task templates superseded by ledger/worklog rules and the screenshot task template.

## Rule

Do not search this directory by default. `.rgignore` excludes it from ordinary `rg` searches. Read it only when the current task explicitly needs historical context, using a targeted direct read or `rg --no-ignore`.
