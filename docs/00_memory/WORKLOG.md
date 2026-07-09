# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-08
Task: T-175 - Context hygiene v4 failure-mode checks.
Files changed: context hygiene script/tests, meta-review template, decision log, roadmap, task ledger/archive, worklog/archive, current state, and structure log.
Checks: RED/GREEN `node --test tests/docs/context-hygiene-check.test.mjs`; `node scripts/context-hygiene-check.mjs`; `git diff --check`.
Result: Hygiene now falls back to `git ls-files` when `rg` is unavailable, fails closed on missing current fact patterns, checks meta-review cadence by completed-task distance, and fails on ledger table rows over 700 characters. T-157 ledger row is compressed while preserving APNs unlock variables.
Risks: Docs/workflow tooling only. No iOS source, Supabase command, migration, runtime behavior, simulator, push, or remote write changed. T-174 was committed locally as `d708db5` before starting this batch; T-175 is not yet committed or pushed.
Next: Use T-176 for batch C entrypoint/fact-source alignment unless the user chooses a different task.
```

```text
Date: 2026-07-08
Task: T-174 - Decision log prearchive and governance review intake.
Files changed: decision log, frozen decision snapshot, frozen external review plan, frozen indexes, roadmap, task ledger/archive, worklog/archive, current state, and structure log.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; decision-log word count; archive path checks; `git log` checks for `01c80e4` and `6d1da33`.
Result: Batch A from the governance review fix plan is applied. `01c80e4` and `6d1da33` are recorded as a one-time historical exception, the active decision log is trimmed below 1500 words with a verbatim frozen snapshot, and the adopted root review plan is archived as external input.
Risks: Docs/governance only. No history rewrite, commit, push, branch switch, iOS source, Supabase command, migration, runtime behavior, or simulator changed.
```

```text
Date: 2026-07-08
Task: T-173 - Main governance divergence reconciliation.
Files changed: GitHub rules, decision log, roadmap, task ledger/archive, worklog/archive, current state, and structure log.
Checks: read-only `git show`/branch containment/ancestor checks for `2fddf7b`; `git diff --check`; `node scripts/context-hygiene-check.mjs`; targeted divergence search.
Result: Main-only commit `2fddf7b` is reviewed and marked superseded. It should not be merged back because it resets docs to a T-049/T-050-era architecture, deletes active `GITHUB_RULES.md`, and reorganizes archives differently from the current governed model.
Risks: Docs/git-governance only. No branch switch, merge, commit, push, iOS source, Supabase command, migration, runtime behavior, or simulator changed.
```

```text
Date: 2026-07-08
Task: T-172 - Rule-change process.
Files changed: AGENTS/Claude/workflow rules, stop conditions, decision log, roadmap, task ledger/archive, worklog/archive, and current state.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; targeted rule search.
Result: Changes to `AGENTS.md`, `CLAUDE.md`, or `docs/05_workflow/**` now require a standalone numbered task, a decision-log entry, and context hygiene. Non-rule tasks must stop rather than make incidental rule edits.
Risks: Docs/workflow only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
```

```text
Date: 2026-07-08
Task: T-171 - Periodic meta-review template.
Files changed: meta-review template, task/docs indexes, roadmap, task ledger/archive, worklog/archive, and current state.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Adds `docs/06_tasks/META_REVIEW_TEMPLATE.md`, requiring a documentation-governance review every 10 completed tasks or weekly. The template keeps scope to active Markdown, context hygiene, task/roadmap consistency, root drafts, and rule friction.
Risks: Docs/workflow only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
```

```text
Date: 2026-07-08
Task: T-170 - Context hygiene v3 fact checks.
Files changed: context hygiene script/tests, Feature Index, Supabase contract, migration rules, context workflow, roadmap, task ledger/archive, worklog/archive, current state, decision log, and structure log.
Checks: RED/GREEN `node --test tests/docs/context-hygiene-check.test.mjs`; `node scripts/context-hygiene-check.mjs`; `git diff --check`.
Result: Hygiene now verifies last-verified freshness, local migration mirror count, ROADMAP-to-ledger task evidence/status, and Feature Index read-first path coverage. Backend fast path records 55 local migration mirrors.
Risks: Docs/workflow tooling only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
```

```text
Date: 2026-07-08
Task: T-169 - Active document structure reduction.
Files changed: reorganization log, Claude guide/archive, task/docs/frozen indexes, roadmap, task ledger/archive, worklog/archive, current state.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; targeted stale-reference searches.
Result: Active structure history is now a compact index backed by a frozen full snapshot. Old `CLAUDE_reference/` snapshots and generic handoff/review templates moved to frozen, and active ledger/worklog windows rolled forward.
Risks: Docs/workflow only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
```

```text
Date: 2026-07-07
Task: T-168 - Testing and migration workflow rules.
Files changed: preflight script/test, iOS testing docs, migration rules, roadmap, task ledger, current state, worklog/archive, decision log, and reorganization log.
Checks: RED/GREEN `node --test tests/scripts/preflight.test.mjs`; `./scripts/preflight.sh`; `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Preflight now runs local migration and Edge Function Node tests when present. Docs require local migration/function tests before authorized remote backend validation and record Edge Function/pg_cron gates.
Risks: Docs/workflow/script only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
```

```text
Date: 2026-07-07
Task: T-167 - Managed ROADMAP adoption.
Files changed: ROADMAP.md, task/docs indexes, AGENTS.md, CONTEXT_AND_RECOVERY.md, task ledger, decision log, current state, worklog archive, context hygiene script/tests.
Checks: RED/GREEN `node --test tests/docs/context-hygiene-check.test.mjs`; `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Adds a governed roadmap that converts external V1.0 drafts into milestone/candidate indexes without copying old task IDs as active IDs. Task numbering remains owned by TASK_LEDGER, and ROADMAP has a hygiene budget.
Risks: Docs/workflow only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
```

```text
Date: 2026-07-07
Task: T-166 - Git/GitHub rules hardening.
Files changed: GITHUB_RULES.md, TOOLING_POLICY.md, root/docs README indexes, decision log, active ledger, frozen ledger archive, current state, and reorganization log.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Git rules now require `T-xxx: <type>: <summary>` commit messages, same-task commit scope, approved checkpoint commits, explicit push/PR/tag gates, branch cleanup rules, and a dedicated `main` reconciliation task for the known 2fddf7b governance divergence.
Risks: Docs/workflow only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
```
