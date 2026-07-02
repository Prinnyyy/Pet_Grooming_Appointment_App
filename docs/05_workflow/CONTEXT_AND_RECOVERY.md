# Context and Recovery

Use this file to decide what to read, when to update durable memory, and how to recover after compaction or interruption.

## Access Tiers

### Tier 0: Startup

Read these only when they are needed for the current task:

- `AGENTS.md`: operating rules for this repository.
- `docs/00_memory/CURRENT_STATE.md`: fast-path current branch, baseline, risks, and next task when state matters.
- `docs/06_tasks/TASK_LEDGER.md`: active/recent task ID/status source when choosing or updating a task.
- An active task file only when the user explicitly provides or requests one.

Do not read broad product, backend, workflow, or archive files during startup by default.
Do not load historical archives, full frozen task records, or Groomly HTML during startup.

### Tier 1: Task Domain

Read one focused domain set after the task is known:

- Product, role, navigation, or UX work: targeted files under `docs/01_product/`.
- SwiftUI, module, data-flow, or repository work: targeted files under `docs/02_architecture/` and `docs/04_ios/`.
- Supabase, RLS, RPC, Storage, or migrations: targeted files under `docs/03_backend/` plus local migrations.
- Screenshot-driven UI work: `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` and the relevant files under `docs/08_design/`.
- Workflow or tooling changes: targeted files under `docs/05_workflow/`.

Prefer `rg` and narrow file reads over loading a whole section. Default `rg` searches honor `.rgignore`; add `--no-ignore` only when the ignored path is explicitly required.

### Tier 2: Trace and History

Read these only when the task explicitly needs traceability or recovery:

- `docs/00_memory/WORKLOG.md`: recent closeout index only; older entries are in frozen worklog archives.
- `docs/00_memory/FEATURE_INDEX.md`: targeted feature lookup only.
- `docs/00_memory/PROJECT_MEMORY.md`: compressed background only.
- `docs/07_decisions/DECISION_LOG.md`: durable architecture/product decisions only.
- `docs/09_frozen/**`: historical comparison or recovery only.
- Root reference material such as `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`, `CLAUDE.md`, and `CLAUDE_reference/`: original or owner-maintained reference only, not daily startup context.

When using Tier 2, search before reading:

1. Run `rg -n "<task id|keyword>" <target directory>` to find the exact section or file.
2. Open only the relevant line range with `sed -n` or a targeted file read.
3. Avoid full-file reads of archived worklogs, task ledgers, task records, Groomly HTML, or pre-trim current-state snapshots unless the user explicitly asks for full historical context.
4. If the needed file is ignored by `.rgignore`, rerun the targeted search with `rg --no-ignore`; do not broaden the search to the whole repository.

## Do Not Read By Default

Do not load these during ordinary tasks unless directly relevant:

- Full `WORKLOG.md`.
- Full `TASK_LEDGER.md` when only the latest task ID or recent status is needed.
- Full archived worklogs, task ledgers, task records, or current-state snapshots.
- Groomly HTML design exports; prefer `UI_IMPLEMENTATION_NOTES.md`, `design_tokens.json`, and targeted screenshots first.
- Frozen full backend contract snapshots; start with the active fast-path `SUPABASE_CONTRACT.md`.
- Full `SCREEN_INVENTORY.md`.
- Full `FEATURE_INDEX.md`.
- All workflow policy files.
- Task templates when no task/template work is being done.
- Frozen archives.
- Root original brief and Claude reference files.

`.rgignore` also excludes heavy historical and machine-readable paths from ordinary searches. These files still exist and may be read with `rg --no-ignore` or direct file reads when the task requires them.

## Durable Memory

Update durable memory only when future runs need the new fact.

- `CURRENT_STATE.md`: current branch, latest completed task, build/test status, known risks, and active next-task facts.
- `WORKLOG.md`: meaningful implementation history and closeout checkpoints.
- `TASK_LEDGER.md`: task numbering and status.
- `FEATURE_INDEX.md`: added, removed, or materially changed features.
- `docs/07_decisions/DECISION_LOG.md`: durable architecture or product decisions.

Do not store secrets, full source files, generated logs, large diffs, or unverified assumptions in memory files.

## Context Hygiene

Run this check at the end of every task that updates `CURRENT_STATE.md`, `WORKLOG.md`, `TASK_LEDGER.md`, or other durable coordination docs.

```sh
wc -w docs/00_memory/CURRENT_STATE.md docs/00_memory/WORKLOG.md docs/06_tasks/TASK_LEDGER.md
```

Keep active files below these soft limits:

- `CURRENT_STATE.md`: 2,500 words.
- `WORKLOG.md`: 5,000 words.
- `TASK_LEDGER.md`: 4,000 words.

If a file exceeds its limit, do the smallest safe rolling archive before final reporting:

- `CURRENT_STATE.md`: snapshot the pre-trim file to `docs/09_frozen/current_state_snapshots/CURRENT_STATE_<YYYY-MM-DD>_PRE_CONTEXT_TRIM.md`, then keep only current branch, latest task, next task ID, active validation state, guardrails, risks, and pointers.
- `WORKLOG.md`: keep the newest 8-12 closeout entries in the active file and move older verbatim entries to `docs/09_frozen/worklogs/WORKLOG_<YYYY-MM-DD>_to_<YYYY-MM-DD>.md`.
- `TASK_LEDGER.md`: keep active, blocked, and roughly the latest 12 task rows in the active ledger. Move older completed rows to `docs/09_frozen/task_ledgers/TASK_LEDGER_<FIRST_TASK>_TO_<LAST_TASK>_<YYYY-MM-DD>.md`.

After creating a new archive family or path, update the relevant active index:

- `docs/00_memory/CURRENT_STATE.md` for fast-path pointers.
- `docs/README.md` and `docs/10_project_structure/README.md` for discoverability.
- `docs/09_frozen/README.md` for frozen archive ownership.

Do not run iOS build or simulator launch for context hygiene alone. Use docs/workflow validation such as `git diff --check`, word counts, and targeted `rg` reference checks.

## Recovery

After interruption, stale context, or compaction:

1. Read `AGENTS.md`.
2. Read the relevant top section of `docs/00_memory/CURRENT_STATE.md`.
3. Read only the top/recent section of `docs/06_tasks/TASK_LEDGER.md` if task status or numbering matters.
4. Read the active task file only if the user explicitly provided or requested one.
5. Run `git status --short`.
6. Run `git diff --stat`.
7. Search `WORKLOG.md` or frozen archives for the newest relevant closeout only if the next step is unclear.
8. Identify partial changes and separate them from unrelated user work.
9. Choose the next smallest safe step.

Do not reconstruct archived subagent state, load old report chains, repeat completed validation automatically, or revert changes without explicit user approval.

## Compaction

Prefer compaction at task boundaries.

- Below 30% context used: usually continue if the next task is small.
- 30% to 50%: compact before medium, risky, or file-heavy tasks.
- At or above 50%: write a closeout or checkpoint, then compact before starting the next task.

Minimum checkpoint fields:

- task ID and status,
- files changed or inspected,
- validation attempted or deferred,
- key decisions or evidence,
- known risks,
- next context needed.
