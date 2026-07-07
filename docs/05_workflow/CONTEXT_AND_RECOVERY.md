# Context and Recovery

Use this file to decide what to read, when to expand context, how to recover after interruption, and how to keep active Markdown small.

## Access Layers

| Layer | Default Read Rule | Files |
|---|---|---|
| L0 Minimal startup | Read only for the current task; every run starts here | `AGENTS.md`; targeted top sections of `docs/00_memory/CURRENT_STATE.md`; targeted top rows of `docs/06_tasks/TASK_LEDGER.md`; an active task file only when explicitly provided/requested |
| L1 Task index | After classifying the task, read one index for that domain | `docs/README.md`; `docs/00_memory/FEATURE_INDEX.md`; `docs/03_backend/SUPABASE_CONTRACT.md`; `docs/04_ios/testops/README.md`; `docs/10_project_structure/README.md` |
| L2 Domain rules | Read only targeted sections needed for implementation or validation | Product docs, architecture docs, backend policy docs, iOS/TestOps runbooks, active workflow policy files |
| L3 Trace/history | Search first, then read line ranges | `docs/00_memory/WORKLOG.md`; `docs/00_memory/PROJECT_MEMORY.md`; `docs/07_decisions/DECISION_LOG.md`; `docs/10_project_structure/REORGANIZATION_LOG.md` |
| L4 Frozen/heavy | Default prohibited; use only with a specific recovery, comparison, seed, design-source, or migration-trace reason | `docs/09_frozen/**`; Groomly HTML/export; T-129 seed tables; generated artifacts; broad migration scans |

## Expansion Rules

- Start with L0.
- Add at most one L1 index before deciding the specific domain context.
- Expand to L2 only when the task cannot be implemented or validated from L0/L1.
- Use L3 only for traceability, recovery, or resolving a current conflict.
- Use L4 only when the user asks for historical context or the task explicitly needs ignored/heavy material.

Search before reading:

```sh
rg -n "<task id|keyword>" <target directory>
sed -n '<start>,<end>p' <file>
```

Default searches must honor `.rgignore`. Do not use broad `rg --files -g '*.md'` as a default Markdown inventory because `-g` can re-include ignored seed Markdown files. Use plain `rg --files`, targeted directories, or explicit exclude patterns. Add `--no-ignore` only when the ignored path is required.

## Do Not Read By Default

- Full `WORKLOG.md`.
- Full `TASK_LEDGER.md` when only task ID/status is needed.
- Full `FEATURE_INDEX.md` or `SCREEN_INVENTORY.md`.
- All workflow policy files.
- Task templates when no template work is being done.
- Frozen archives and current-state/worklog/task-ledger snapshots.
- Groomly HTML/export; prefer `UI_IMPLEMENTATION_NOTES.md`, `design_tokens.json`, and screenshots.
- T-129 seed profile tables; use their README unless parser/test work needs table content.
- Root original brief and Claude reference files.

## Stop Conditions For Context

Stop and report before continuing when:

- The task needs L4 context but the purpose is unclear.
- Current docs conflict with source code or script behavior.
- Memory docs are missing a critical current fact.
- A broad read would be needed to continue safely.
- User work in the target files would be overwritten.
- The task has expanded into multiple primary tasks.

## Durable Memory

Update durable memory only when future runs need the changed fact.

Single sources of truth:

- Task ID/status/next number: `docs/06_tasks/TASK_LEDGER.md`.
- Current branch/latest validation/current risks: `docs/00_memory/CURRENT_STATE.md`.
- Recent closeout evidence: `docs/00_memory/WORKLOG.md`.
- Durable decisions: `docs/07_decisions/DECISION_LOG.md`.
- Feature-to-doc/code routing: `docs/00_memory/FEATURE_INDEX.md`.
- Tooling, credential, remote-write rules: `docs/05_workflow/TOOLING_POLICY.md`.
- TestOps commands: `docs/04_ios/testops/RUNBOOK.md`.

Do not store secrets, full source files, generated logs, large diffs, or unverified assumptions in memory files.

## Context Hygiene

Run the context hygiene check at the end of any task that updates durable memory, task ledgers, workflow rules, or active coordination docs:

```sh
node scripts/context-hygiene-check.mjs
```

Budget limits live in `scripts/context-hygiene-check.mjs`. Do not copy the numeric table here; run the script to see the current per-file budgets, active Markdown total budget, worklog entry limit, and task-ledger row limit.

If a file exceeds its limit, do the smallest safe rolling archive before final reporting:

- `CURRENT_STATE.md`: snapshot to `docs/09_frozen/current_state_snapshots/`, then keep only current facts and pointers.
- `WORKLOG.md`: keep newest 8-10 closeout entries active; move older verbatim entries to `docs/09_frozen/worklogs/`.
- `TASK_LEDGER.md`: keep active, blocked, and latest 12-15 rows active; move older completed rows to `docs/09_frozen/task_ledgers/`.
- Decision/backend/product indexes: archive the pre-trim file under the matching `docs/09_frozen/` family, then keep the active file as an index/current-rule document.

After creating a new archive family or path, update `docs/README.md`, `docs/10_project_structure/README.md`, `docs/09_frozen/README.md`, and any active pointer that references the family.

Do not run iOS build or simulator launch for context hygiene alone.

## Recovery

After interruption, stale context, or compaction:

1. Read `AGENTS.md`.
2. Read the relevant top section of `docs/00_memory/CURRENT_STATE.md`.
3. Read only the top/recent section of `docs/06_tasks/TASK_LEDGER.md` if task status or numbering matters.
4. Read the active task file only if the user explicitly provided or requested one.
5. Run `git status --short`.
6. Run `git diff --stat`.
7. Search `WORKLOG.md` or frozen archives only if the next step remains unclear.
8. Separate partial changes from unrelated user work.
9. Choose the next smallest safe step.

Do not reconstruct archived subagent state, load old report chains, repeat completed validation automatically, or revert changes without explicit user approval.

## Compaction

Prefer compaction at task boundaries.

- Below 30% context used: usually continue if the next task is small.
- 30% to 50%: compact before medium, risky, or file-heavy tasks.
- At or above 50%: write a checkpoint, then compact before starting the next task.

Minimum checkpoint fields: task ID/status, files changed or inspected, validation attempted/deferred, key decisions or evidence, known risks, next context needed.
