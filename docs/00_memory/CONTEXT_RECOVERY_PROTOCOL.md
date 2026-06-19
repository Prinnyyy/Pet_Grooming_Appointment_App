# Context Recovery Protocol

## Purpose

This protocol is used when Codex context is compressed, lost, interrupted, or restarted.

Durable repository memory is the source of truth.

---

## Recovery Order

When starting or resuming a task, read these files first:

1. `AGENTS.md`
2. `docs/00_memory/PROJECT_MEMORY.md`
3. `docs/00_memory/CURRENT_STATE.md`
4. `docs/00_memory/AGENT_TEAM_INDEX.md`
5. `docs/00_memory/FEATURE_INDEX.md`
6. `docs/07_decisions/DECISION_LOG.md`
7. Active task file under `docs/06_tasks/`
8. Existing reports under `docs/05_workflow/agent_reports/<TASK_ID>/`

Do not read the whole codebase before checking these files.

---

## Interrupted Task Recovery

If a task was interrupted:

1. Find the latest task ID in `docs/05_workflow/agent_reports/`.
2. Read `00-task-intake.md` and `09-final-run-report.md` if present.
3. Check Git status.
4. Check Git diff.
5. Determine whether the previous run:
   - did not start implementation,
   - partially changed files,
   - completed implementation but did not validate,
   - completed validation but did not update memory,
   - completed fully.
6. Continue from the safest next step.
7. Do not assume completion without validating the diff and build state.

---

## Context Compression Safety

If the main agent notices that context may be stale or compressed:

1. Stop implementation.
2. Re-read this recovery protocol.
3. Re-read the active task reports.
4. Re-state the current task, scope, and stop condition.
5. Continue only if the next action is clear.

---

## Durable Memory Rule

Anything important for future runs must be written to repository memory, not left only in chat.

Minimum memory updates after each meaningful task:

- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `docs/07_decisions/DECISION_LOG.md` if a durable architecture/product decision changed
