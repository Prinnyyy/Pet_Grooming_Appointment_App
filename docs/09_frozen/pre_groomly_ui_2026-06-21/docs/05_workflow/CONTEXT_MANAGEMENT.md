# Context Management

## Read Budget

Default to the smallest useful read:

- Always read `AGENTS.md`.
- Read the active task file when provided.
- Read targeted `CURRENT_STATE.md` sections when current state, risk, or backend facts matter.
- Read `TASK_LEDGER.md` only to choose, verify, or update task status.
- Read briefs, architecture/backend docs, decisions, feature indexes, and old reports only when directly relevant.

Search only active areas by default. Exclude `docs/05_workflow/archive_subagent_workflow/` and `docs/05_workflow/agent_reports/` unless the user asks for historical workflow context.

## Durable Memory

Update only facts that changed:

- `CURRENT_STATE.md`: project state, build/test status, current risks, next task.
- `WORKLOG.md`: meaningful implementation history.
- `TASK_LEDGER.md`: tracked task status.
- `FEATURE_INDEX.md`: added, removed, or changed features.
- `DECISION_LOG.md`: durable architecture/product decisions.

Do not store secrets, full source files, huge diffs, generated logs, or unverified assumptions in memory files.

## Manual Compaction

Prefer manual compaction at clean boundaries instead of automatic compaction mid-task.

- Below 30% context used: usually continue if the next task is small.
- 30% to 50%: compact before medium, risky, or file-heavy tasks.
- At or above 50%: write a closeout, then compact before starting the next task.

Do not compact while root-cause analysis, required validation, or important temporary evidence is still unwritten.

Minimum closeout/checkpoint fields:
- task ID/status,
- files changed or inspected,
- validation attempted or deferred,
- key decisions/evidence,
- known risks,
- next context needed.
