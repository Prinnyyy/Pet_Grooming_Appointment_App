# Memory Directory Guide

This directory holds compact project memory for current work and recovery. It is not a dumping ground for every historical fact.

## File Ownership

| File | Owns | Does Not Own |
|---|---|---|
| `CURRENT_STATE.md` | Current branch, latest task, active blockers, latest validation state, current high-level product/iOS/backend facts, live risks, next task guidance | Detailed task history, per-feature implementation timelines, long migration notes |
| `WORKLOG.md` | Recent reverse-chronological closeout history and checkpoints | Full historical worklog archives, current instructions from old `Next:` lines, task numbering authority |
| `FEATURE_INDEX.md` | Feature-to-doc/code routing and compact current status | Current branch/build status, detailed task closeouts, task-by-task timelines |
| `PROJECT_MEMORY.md` | Highest-level project identity and permanent constraints | Current task status, detailed feature or backend facts |

Durable product and architecture decisions live in `docs/07_decisions/DECISION_LOG.md`.

## Update Rules

- Update `CURRENT_STATE.md` only when a future run needs a changed current fact.
- Append to `WORKLOG.md` only for meaningful implementation, workflow, product, or recovery checkpoints.
- Update `FEATURE_INDEX.md` only when a feature is added, removed, relocated, or materially changes ownership.
- Update `PROJECT_MEMORY.md` only when a permanent high-level project fact changes.
- Update `docs/07_decisions/DECISION_LOG.md` when a durable architecture/product decision changes.
- Keep history out of `CURRENT_STATE.md`; link to `WORKLOG.md`, `TASK_LEDGER.md`, archived task records, or domain docs instead.
- Keep task-by-task timelines out of `FEATURE_INDEX.md`; route to the smallest active domain docs/code area instead.
- After any task that updates durable memory, run `node scripts/context-hygiene-check.mjs` and roll older history into `docs/09_frozen/` if active files exceed their limits.
- Whole-file state snapshots taken before a coordinated reset live under `docs/09_frozen/active_state_snapshots/`; they are recovery evidence, never startup context.

## Conflict Rules

- Task ID, task status, and next task number: `docs/06_tasks/TASK_LEDGER.md` wins.
- Current branch, current baseline, current blockers, latest validation: `CURRENT_STATE.md` wins.
- Detailed evidence for what happened in a task: newest relevant `WORKLOG.md` entry wins.
- Durable architecture/product decision: `docs/07_decisions/DECISION_LOG.md` wins.
- Domain truth: product docs, architecture docs, backend docs, iOS docs, or source code win over old memory summaries.

## Size Rule

Keep `CURRENT_STATE.md`, `WORKLOG.md`, and `TASK_LEDGER.md` short enough to scan during startup. `CURRENT_STATE.md` replaces stale facts, while Worklog/Ledger retain bounded recent entries. When any file starts reading like a changelog, preserve the source under the matching `docs/09_frozen/` family and keep only current/recent facts active.
