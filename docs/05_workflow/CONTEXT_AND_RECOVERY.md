# Context And Recovery

## Layered Access Model

| Layer | Default Rule | Files |
|---|---|---|
| L0 | Minimal startup | `AGENTS.md`; targeted top of `docs/00_memory/CURRENT_STATE.md`; targeted top of `docs/06_tasks/TASK_LEDGER.md` |
| L1 | Task-type index | `docs/README.md`, `docs/00_memory/FEATURE_INDEX.md`, `docs/03_backend/SUPABASE_CONTRACT.md`, `docs/04_ios/IOS_BUILD_AND_TESTING.md`, `docs/10_project_structure/README.md` |
| L2 | Domain manual | Targeted product, architecture, backend, iOS, workflow, or design sections |
| L3 | Historical recovery | Targeted `docs/00_memory/WORKLOG.md`, `docs/07_decisions/DECISION_LOG.md`, `docs/10_project_structure/REORGANIZATION_LOG.md` |
| L4 | Frozen archive | `docs/09_frozen/**`; default forbidden unless a specific recovery/comparison reason exists |

## Startup Budget

Before editing, read only:

1. `AGENTS.md`.
2. `CURRENT_STATE.md` Fast Path when branch/current state/risk matters.
3. `TASK_LEDGER.md` top rows when task numbering/status matters.
4. At most one L1 index for the task type.

Expand context only after explaining why. Use `rg` to locate facts, then read the smallest useful line range.

## Forbidden Default Reads

Do not full-read or broad-search by default:

- `docs/09_frozen/**`
- generated artifacts and build output
- full Groomly HTML exports
- seed tables or large machine-generated Markdown
- old task files
- migration directories for non-backend tasks
- large SwiftUI files unrelated to the task

Default searches must honor `.rgignore`. Do not use broad `rg --files -g '*.md'` as a Markdown inventory.

## Compaction Recovery

After interruption or context compression:

1. Read `AGENTS.md`.
2. Read the top of `docs/00_memory/CURRENT_STATE.md`.
3. Read the top of `docs/06_tasks/TASK_LEDGER.md`.
4. Run `git status --short` and `git diff --stat`.
5. If the next step is unclear, use targeted search in `docs/00_memory/WORKLOG.md`.

Before `/compact`, write a checkpoint with task ID/status, changed files, validation, risks, and next context.

## Hygiene Budgets

Targets for active files:

- `AGENTS.md`: <= 1,000 words.
- `docs/00_memory/CURRENT_STATE.md`: <= 1,200 words.
- `docs/00_memory/WORKLOG.md`: <= 2,500 words.
- `docs/06_tasks/TASK_LEDGER.md`: <= 1,800 words.
- `docs/00_memory/FEATURE_INDEX.md`: <= 1,200 words.

After durable memory or task-ledger edits, run:

```sh
node scripts/context-hygiene-check.mjs
```

If a budget is exceeded, archive older rows immediately and leave an archive pointer.
