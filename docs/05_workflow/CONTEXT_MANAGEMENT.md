# Context Management

## Default Read Budget

Read only:

1. `AGENTS.md`
2. `docs/00_memory/CURRENT_STATE.md`
3. `docs/06_tasks/TASK_LEDGER.md` if present
4. the active task file, if provided

Read briefs, `PROJECT_MEMORY.md`, feature indexes, architecture/backend docs, decisions, and old reports only when directly relevant. Prefer targeted search and narrow reads over repository-wide loading.

## Durable Memory Updates

- Update `CURRENT_STATE.md` only when project state changed.
- Update `WORKLOG.md` only after meaningful implementation.
- Update `TASK_LEDGER.md` only when a tracked task status changed.
- Update `FEATURE_INDEX.md` only when a feature was added, removed, or changed.
- Update `DECISION_LOG.md` only when a durable architecture/product decision changed.

Do not update memory for tiny documentation-only changes unless needed.

## Context Safety

Do not store secrets, full source files, huge diffs, generated logs, or unverified assumptions in memory files. If interrupted, use `INTERRUPTION_RECOVERY.md`; do not reconstruct archived subagent state.
