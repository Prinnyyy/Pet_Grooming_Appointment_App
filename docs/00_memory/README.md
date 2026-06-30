# Memory Directory Guide

This directory holds compact project memory for current work and recovery. It is not a dumping ground for every historical fact.

## File Ownership

| File | Owns | Does Not Own |
|---|---|---|
| `CURRENT_STATE.md` | Current branch, latest task, active blockers, latest validation state, current high-level product/iOS/backend facts, live risks, next task guidance | Detailed task history, per-feature implementation timelines, long migration notes |
| `WORKLOG.md` | Reverse-chronological closeout history and checkpoints | Current instructions from old `Next:` lines, task numbering authority |
| `FEATURE_INDEX.md` | Feature-to-doc/code lookup and feature status summaries | Current branch/build status, detailed task closeouts |
| `PROJECT_MEMORY.md` | Highest-level project identity and permanent constraints | Current task status, detailed feature or backend facts |

Durable product and architecture decisions live in `docs/07_decisions/DECISION_LOG.md`.

## Update Rules

- Update `CURRENT_STATE.md` only when a future run needs a changed current fact.
- Append to `WORKLOG.md` only for meaningful implementation, workflow, product, or recovery checkpoints.
- Update `FEATURE_INDEX.md` only when a feature is added, removed, relocated, or materially changes ownership.
- Update `PROJECT_MEMORY.md` only when a permanent high-level project fact changes.
- Keep history out of `CURRENT_STATE.md`; link to `WORKLOG.md`, `TASK_LEDGER.md`, archived task records, or domain docs instead.

## Conflict Rules

- Task ID, task status, and next task number: `docs/06_tasks/TASK_LEDGER.md` wins.
- Current branch, current baseline, current blockers, latest validation: `CURRENT_STATE.md` wins.
- Detailed evidence for what happened in a task: newest relevant `WORKLOG.md` entry wins.
- Durable architecture/product decision: `docs/07_decisions/DECISION_LOG.md` wins.
- Domain truth: product docs, architecture docs, backend docs, iOS docs, or source code win over old memory summaries.

## Size Rule

Keep `CURRENT_STATE.md` short enough to scan during startup. When it starts reading like a changelog, move the old detail into `WORKLOG.md`, `FEATURE_INDEX.md`, or the relevant domain document.
