# Context Recovery Protocol

## Purpose

This protocol is used when Codex context is compressed, lost, interrupted, or restarted.

Durable repository memory is the source of truth.

---

## Default Startup / Recovery Order

When starting or resuming a task, read these files first:

1. `AGENTS.md`
2. `docs/00_memory/CURRENT_STATE.md`
3. `docs/06_tasks/TASK_LEDGER.md` if present
4. the active task intake file

Read project memory, feature indexes, architecture/backend docs, long Briefs, decisions, or historical reports only when the active task directly needs them.

---

## Interrupted Task Recovery

If a task was interrupted:

1. Find the active task in `TASK_LEDGER.md`.
2. Read its intake and latest final/handoff report if present; do not read every historical report by default.
3. Check Git status and the current diff.
4. Determine whether the previous run:
   - did not start implementation,
   - partially changed files,
   - completed implementation but did not validate,
   - completed validation but did not update memory,
   - completed fully.
5. Continue from the smallest safe next step within the selected mode's validation budget.

---

## Context Compression Safety

If the main agent notices that context may be stale or compressed:

1. Stop implementation.
2. Re-read this recovery protocol.
3. Read only the active intake and the report needed to recover the next action.
4. Re-state the current task, scope, and stop condition.
5. Continue only if the next action is clear.

---

## Durable Memory Rule

Anything important for future runs must be written to repository memory, not left only in chat.

Minimum durable updates after meaningful work:

- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `docs/07_decisions/DECISION_LOG.md` if a durable architecture/product decision changed
