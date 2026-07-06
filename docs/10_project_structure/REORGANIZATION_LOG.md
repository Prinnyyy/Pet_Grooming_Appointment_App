# Reorganization Log

## 2026-07-06 - T-049 Markdown information architecture repair

Goal: reduce default AI context and prevent stale historical documents from being treated as active task guidance.

Moved to frozen archive:

- T-001 through T-048 task records and workflow task records.
- Full pre-trim task ledger, worklog, and current-state snapshots.
- Old subagent workflow, agent reports, and obsolete workflow policy files.
- Old Fresh Brief, Codex workspace initialization plan, Groomly design task prompt, Claude incremental plan, Superpowers historical plans/specs, and external agent audit drafts.

Active replacements:

- L0/L1/L2/L3/L4 access model in `docs/05_workflow/CONTEXT_AND_RECOVERY.md`.
- Compact `docs/00_memory/CURRENT_STATE.md`, `docs/00_memory/WORKLOG.md`, and `docs/06_tasks/TASK_LEDGER.md`.
- `scripts/context-hygiene-check.mjs` for active Markdown budgets, stale active links, and local link checks.
