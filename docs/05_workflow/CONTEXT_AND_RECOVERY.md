# Context and Recovery

Use this file to decide what to read, when to update durable memory, and how to recover after compaction or interruption.

## Access Tiers

### Tier 0: Startup

Read these only when they are needed for the current task:

- `AGENTS.md`: operating rules for this repository.
- `docs/00_memory/CURRENT_STATE.md`: current branch, baseline, risks, and next task when state matters.
- `docs/06_tasks/TASK_LEDGER.md`: task ID/status source when choosing or updating a task.
- An active task file only when the user explicitly provides or requests one.

Do not read broad product, backend, workflow, or archive files during startup by default.

### Tier 1: Task Domain

Read one focused domain set after the task is known:

- Product, role, navigation, or UX work: targeted files under `docs/01_product/`.
- SwiftUI, module, data-flow, or repository work: targeted files under `docs/02_architecture/` and `docs/04_ios/`.
- Supabase, RLS, RPC, Storage, or migrations: targeted files under `docs/03_backend/` plus local migrations.
- Screenshot-driven UI work: `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` and the relevant files under `docs/08_design/`.
- Workflow or tooling changes: targeted files under `docs/05_workflow/`.

Prefer `rg` and narrow file reads over loading a whole section.

### Tier 2: Trace and History

Read these only when the task explicitly needs traceability or recovery:

- `docs/00_memory/WORKLOG.md`: newest closeout first; older entries are historical.
- `docs/00_memory/FEATURE_INDEX.md`: targeted feature lookup only.
- `docs/00_memory/PROJECT_MEMORY.md`: compressed background only.
- `docs/00_memory/DECISION_LOG.md`: architecture/product decisions only.
- `docs/09_frozen/**`: historical comparison or recovery only.
- Root reference material such as `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`, `CLAUDE.md`, and `CLAUDE_reference/`: original or owner-maintained reference only, not daily startup context.

## Do Not Read By Default

Do not load these during ordinary tasks unless directly relevant:

- Full `WORKLOG.md`.
- Full `SUPABASE_CONTRACT.md`.
- Full `SCREEN_INVENTORY.md`.
- Full `FEATURE_INDEX.md`.
- All workflow policy files.
- Task templates when no task/template work is being done.
- Frozen archives.
- Root original brief and Claude reference files.

## Durable Memory

Update durable memory only when future runs need the new fact.

- `CURRENT_STATE.md`: current branch, latest completed task, build/test status, known risks, and active next-task facts.
- `WORKLOG.md`: meaningful implementation history and closeout checkpoints.
- `TASK_LEDGER.md`: task numbering and status.
- `FEATURE_INDEX.md`: added, removed, or materially changed features.
- `DECISION_LOG.md`: durable architecture or product decisions.

Do not store secrets, full source files, generated logs, large diffs, or unverified assumptions in memory files.

## Recovery

After interruption, stale context, or compaction:

1. Read `AGENTS.md`.
2. Read the relevant top section of `docs/00_memory/CURRENT_STATE.md`.
3. Read `docs/06_tasks/TASK_LEDGER.md` if task status or numbering matters.
4. Read the active task file only if the user explicitly provided or requested one.
5. Run `git status --short`.
6. Run `git diff --stat`.
7. Find the newest relevant closeout or checkpoint in `WORKLOG.md` only if the next step is unclear.
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
