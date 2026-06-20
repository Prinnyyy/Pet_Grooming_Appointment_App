# Single-Agent Workflow

## Purpose

Default Codex workflow for this repository. It favors limited context, small reversible changes, and one verifiable task per run.

## Core Rules

- One primary task only.
- No adjacent features, broad refactors, commits, pushes, or remote writes unless explicitly requested.
- No subagents or archived agent-team protocol.
- Targeted context reads/searches only.
- One validation attempt by mode.
- Stop after the requested task is complete.

## Context Budget

Startup reads:

1. `AGENTS.md`
2. active task file, if provided
3. targeted `CURRENT_STATE.md` sections when current state or risks matter
4. `TASK_LEDGER.md` only when choosing or updating task status

Avoid broad searches. Do not read or search `docs/05_workflow/archive_subagent_workflow/` or `docs/05_workflow/agent_reports/` unless the task is explicitly about historical workflow state.

## Flow

1. Identify one primary task.
2. Read only the context needed for that task.
3. Write a short plan before non-trivial edits.
4. Implement only that scope.
5. Run the mode-appropriate validation once.
6. Review the current diff briefly.
7. Update durable memory only if project state changed.
8. Write a closeout/checkpoint before manual compaction.
9. Stop.

## Modes

| Mode | Use For | Validation |
|---|---|---|
| Quick | Docs, small scripts, one-file fixes, simple UI text/style | Only when directly needed |
| Standard | Normal iOS feature or bug work | One build attempt by default |
| Deep | Supabase, auth, RLS, migrations, storage, major navigation, high-risk work | Explicit validation plan |

If validation fails, report the first real error and stop unless the user approves a follow-up task.

## Durable Memory

Update only files whose facts changed:

- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/07_decisions/DECISION_LOG.md`

Do not update memory for tiny documentation-only changes unless needed.

## Compaction

Manual compaction belongs at task boundaries. Capture a closeout or debug checkpoint first, then compact when context is high or the next task is unrelated. Detailed thresholds live in `docs/05_workflow/CONTEXT_MANAGEMENT.md`.

## Reporting

Keep final reports concise. Use `LIGHTWEIGHT_FINAL_REPORT_TEMPLATE.md` only when a durable report is useful or explicitly requested.
