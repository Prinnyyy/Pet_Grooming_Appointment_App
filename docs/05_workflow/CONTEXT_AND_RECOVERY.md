# Context and Recovery

Use this file to decide what to read, when to expand context, how to recover after interruption, and how to keep active Markdown small.

## Access Layers

| Layer | Default Read Rule | Files |
|---|---|---|
| L0 Minimal startup | Read only for the current task; every run starts here | `AGENTS.md`; targeted top sections of `docs/00_memory/CURRENT_STATE.md`; targeted top rows of `docs/06_tasks/TASK_LEDGER.md`; an active task file only when explicitly provided/requested |
| L1 Task index | After classifying the task, read one index for that domain | `docs/README.md`; `docs/00_memory/FEATURE_INDEX.md`; `docs/06_tasks/ROADMAP.md` for planning tasks; `docs/03_backend/SUPABASE_CONTRACT.md`; `docs/04_ios/testops/README.md`; `docs/10_project_structure/README.md` |
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

Budget limits and fact checks live in `scripts/context-hygiene-check.mjs`. Do not copy the numeric table here; run the script to see current budgets, active Markdown percentage, rolling-window status, last-verified dates, migration count, ROADMAP/ledger evidence, and Feature Index path checks.

Active Markdown is structured as three file classes:

- FIXED: rules, contracts, and product docs. These have per-file word budgets and change only when their owner fact changes.
- WINDOW: `TASK_LEDGER.md`, `WORKLOG.md`, and `DECISION_LOG.md`. These grow by entries and stay bounded by rotation.
- INDEX: `CURRENT_STATE.md`, ROADMAP, feature and archive indexes. Updates replace stale facts or pointers instead of appending history.

Closeout writing discipline: ordinary tasks add one task-ledger row and one worklog entry; `CURRENT_STATE.md` uses replacement semantics; `DECISION_LOG.md` changes only for durable decisions; unrelated active Markdown stays untouched.

If hygiene reports a rolling-window overflow, run:

```sh
node scripts/context-rotate.mjs --apply
node scripts/context-hygiene-check.mjs
```

If the script is unavailable, do the equivalent manually: move oldest eligible completed ledger rows, oldest worklog entries, or oldest complete decision blocks into the matching `docs/09_frozen/` family verbatim, leave active indexes/pointers, and rerun hygiene.

Do not treat the active Markdown percentage as a compression target. A 95% warning means schedule a structural review for category mismatch, window drift, or index-as-log misuse; only a hard-limit failure blocks closeout.

Compress FIXED files only under these criteria: replace repeated facts with a pointer to the owner file, keep each fact in one source of truth, move narrative history to frozen archives, and move long examples or explanations to frozen references. Do not compress outside those criteria.

After creating a new archive family or path, update the relevant active pointers and archive indexes in the same task.

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
