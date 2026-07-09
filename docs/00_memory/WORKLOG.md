# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-08
Task: T-179 - Active Markdown budget reduction.
Files changed: context hygiene script, structure/product indexes, decision log, roadmap, task ledger/archive, worklog/archive, current state, structure log, and frozen external report.
Checks: `node scripts/context-hygiene-check.mjs`; `CONTEXT_HYGIENE_FORCE_NO_RG=1 node scripts/context-hygiene-check.mjs`; `node --test tests/docs/context-hygiene-check.test.mjs`; `git diff --check`.
Result: Lowers active rolling windows to 8 worklog entries and 12 ledger rows, tightens decision/structure budgets, trims active index prose, and archives the adopted watch-items plan. Active Markdown is below the 85% waterline.
Audit: Kept current facts; compressed routing/index prose in project structure, screen inventory, navigation, UX, and current risks; archived older rolling-window rows verbatim. No referenced active file was deleted.
Risks: Docs/workflow tooling only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, push, or remote write changed.
Next: Use T-180 for the next non-APNs task; product candidate remains private image rendering unless the user chooses otherwise.
```

```text
Date: 2026-07-08
Task: T-178 - Context hygiene v5 path checks.
Files changed: context hygiene script/tests, structure log, task ledger/archive, worklog/archive, current state, and roadmap.
Checks: RED/GREEN `node --test tests/docs/context-hygiene-check.test.mjs`; `node scripts/context-hygiene-check.mjs`; `CONTEXT_HYGIENE_FORCE_NO_RG=1 node scripts/context-hygiene-check.mjs`; `git diff --check`.
Result: Hygiene now checks inline backtick paths, reports the checked count, warns when active Markdown total is at or above 85% of the 32k limit, and uses English failure text for fact-extraction failures. The new check caught two stale removed-template source references in the structure log; they now point only to frozen targets.
Risks: Docs/workflow tooling only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, push, or remote write changed. Active Markdown remains above the 85% warning line; T-179 should execute the planned budget-reduction batch.
```

```text
Date: 2026-07-08
Task: T-177 - ROADMAP DoD and ignore cleanup.
Files changed: `.rgignore`, `.gitignore`, roadmap, task ledger/archive, worklog/archive, current state, and structure log.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; targeted ignore/root-draft checks.
Result: Removes the dead `DOCS_GOVERNANCE_OPTIMIZATION_PLAN.md` ignore entry, expands V1.0 DoD into a checklist, and reorders ROADMAP candidate rows by R ID. Root `APP_STATUS_OVERVIEW.md` and `V1.0_RELEASE_TASK_PLAN.md` remain ignored live drafts; frozen 2026-07-06 copies remain adopted review snapshots.
Risks: Docs/governance only. No iOS source, Supabase command, migration, runtime behavior, simulator, push, or remote write changed. T-177 is not yet committed or pushed.
```

```text
Date: 2026-07-08
Task: T-176 - Entrypoint and branch fact-source alignment.
Files changed: AGENTS.md, CLAUDE.md, decision log, roadmap, task ledger/archive, worklog/archive, current state, and structure log.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: `AGENTS.md` no longer hardcodes the branch baseline and now points to CURRENT_STATE for that fact. `CLAUDE.md` now routes planning/milestone review to ROADMAP and rule/scope review to DECISION_LOG/Git rules.
Risks: Docs/rules only. No iOS source, Supabase command, migration, runtime behavior, simulator, push, or remote write changed. T-176 is not yet committed or pushed.
```

```text
Date: 2026-07-08
Task: T-175 - Context hygiene v4 failure-mode checks.
Files changed: context hygiene script/tests, meta-review template, decision log, roadmap, task ledger/archive, worklog/archive, current state, and structure log.
Checks: RED/GREEN `node --test tests/docs/context-hygiene-check.test.mjs`; `node scripts/context-hygiene-check.mjs`; `git diff --check`.
Result: Hygiene now falls back to `git ls-files` when `rg` is unavailable, fails closed on missing current fact patterns, checks meta-review cadence by completed-task distance, and fails on ledger table rows over 700 characters. T-157 ledger row is compressed while preserving APNs unlock variables.
Risks: Docs/workflow tooling only. No iOS source, Supabase command, migration, runtime behavior, simulator, push, or remote write changed. T-174 was committed locally as `d708db5` before starting this batch; T-175 is not yet committed or pushed.
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
