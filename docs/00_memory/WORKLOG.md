# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-08
Task: T-173 - Main governance divergence reconciliation.
Files changed: GitHub rules, decision log, roadmap, task ledger/archive, worklog/archive, current state, and structure log.
Checks: read-only `git show`/branch containment/ancestor checks for `2fddf7b`; `git diff --check`; `node scripts/context-hygiene-check.mjs`; targeted divergence search.
Result: Main-only commit `2fddf7b` is reviewed and marked superseded. It should not be merged back because it resets docs to a T-049/T-050-era architecture, deletes active `GITHUB_RULES.md`, and reorganizes archives differently from the current governed model.
Risks: Docs/git-governance only. No branch switch, merge, commit, push, iOS source, Supabase command, migration, runtime behavior, or simulator changed.
Next: Use T-174 unless the user resumes T-157 after Apple Developer Program upgrade.
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

```text
Date: 2026-07-07
Task: T-165 - Context hygiene v2 truth checks.
Files changed: context hygiene script/tests, CONTEXT_AND_RECOVERY.md, frozen worklog archive, memory docs.
Checks: RED/GREEN `node --test tests/docs/context-hygiene-check.test.mjs`; `node scripts/context-hygiene-check.mjs`; `git diff --check`.
Result: Hygiene now detects branch/latest/next task drift, rolling-window overflow, active Markdown total budget, expanded file budgets, and missing `rg` without TypeError.
Risks: Docs/workflow tooling only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
```

```text
Date: 2026-07-07
Task: T-164 - Backend contract catch-up.
Files changed: SUPABASE_CONTRACT.md, RLS_RPC_POLICY.md, memory docs.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; targeted migration-object reference search.
Result: Active backend contract indexes now cover T-153 through T-160 customer notification, handoff, APNs foundation, account deletion, automation, Edge Function, and controlled/service-role RPC facts.
Risks: Docs-only. No Supabase remote command, migration, iOS source, runtime behavior, simulator, commit, or push changed.
```
