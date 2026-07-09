# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-09
Task: T-184 - Context budget workflow alignment.
Files changed: AGENTS.md, context/recovery workflow rules, decision log/archive, frozen external plan, current state, task ledger, and worklog.
Checks: `node scripts/context-rotate.mjs --apply`; `node scripts/context-hygiene-check.mjs`; `git diff --check`; commit and push.
Result: Implements Batch B of the context-budget redesign. Active workflow rules now use `context-rotate` for rolling-window overflow, define FIXED/WINDOW/INDEX write discipline, treat 95% active Markdown as structural-review signal, and archive the adopted root redesign plan.
Risks: Documentation-only workflow change. No Swift, Supabase, runtime, simulator, PR, tag, merge/rebase/reset, seed, migration, or non-Git remote write changed.
Next: Use T-185 unless resuming T-157 after Apple Developer credentials.
```

```text
Date: 2026-07-09
Task: T-183 - Context budget redesign tooling.
Files changed: context hygiene policy/check scripts, context rotate script, docs tests, decision log/archive, current state, task ledger, and worklog.
Checks: `node --test tests/docs/`; `node scripts/context-rotate.mjs`; `node scripts/context-rotate.mjs --apply`; `node scripts/context-hygiene-check.mjs`; `CONTEXT_HYGIENE_FORCE_NO_RG=1 node scripts/context-hygiene-check.mjs`; `git diff --check`; commit and push.
Result: Implements Batch A of the context-budget redesign: 36k hard total, no 85% warning, 95% structural-review warning, 650-word default active Markdown budget, full budget coverage output, decision-log 8-entry window, shared constants, and deterministic archive rotation.
Risks: Docs/tooling-only change. Workflow text alignment and root plan archival are intentionally deferred to T-184 Batch B. No Swift, Supabase, runtime, simulator, PR, tag, merge/rebase/reset, seed, migration, or non-Git remote write changed.
```

```text
Date: 2026-07-09
Task: T-182 - Active Markdown waterline cleanup rule.
Files changed: AGENTS, workflow rules, decision log, current state, task ledger, worklog, and frozen ledger/worklog archives.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs` with no active Markdown 85% warning; staged diff check; commit and push.
Result: Makes the active Markdown 85% waterline a mandatory cleanup trigger for durable-doc closeout, clarifies unrelated cleanup vs context-hygiene cleanup, and archives older active ledger/worklog rows so current active Markdown is below the warning line.
Risks: Documentation-only rule change. No Swift, Supabase, runtime, PR, tag, merge/rebase/reset, seed, migration, or non-Git remote write changed.
```

```text
Date: 2026-07-08
Task: T-181 - Current-state stale pointer correction.
Files changed: current state, task ledger, worklog, and frozen ledger/worklog archives.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; staged diff check; commit and push.
Result: Corrects stale T-180 next-task, validation-baseline, and active-Markdown-waterline text found during follow-up review. The next non-APNs task is now T-182 in both CURRENT_STATE and TASK_LEDGER.
Risks: Documentation-only correction. No Swift, Supabase, runtime, workflow-rule, PR, tag, merge/rebase/reset, seed, cleanup, or non-Git remote write changed.
```

```text
Date: 2026-07-08
Task: T-180 - Standing Git auto-push authorization.
Files changed: AGENTS.md, workflow Git/tooling rules, decision log, task ledger, worklog, and current state.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; staged diff check; commit and push.
Result: Records the user's standing approval for automatic task-completion commits and pushes. The workflow now commits and pushes the current task's own changes after required validation passes, while keeping PRs, tags, merge/rebase/reset, branch deletion, Supabase writes, seeds, unrelated cleanup, non-Git remote writes, and unrelated user work outside that approval.
Risks: Documentation-only rule change. Future agents must still skip auto Git when validation fails, secrets appear in the diff, the branch is unclear, or unrelated user work would be included.
```

```text
Date: 2026-07-08
Task: T-179 - Active Markdown budget reduction.
Files changed: context hygiene script, structure/product indexes, decision log, roadmap, task ledger/archive, worklog/archive, current state, structure log, and frozen external report.
Checks: `node scripts/context-hygiene-check.mjs`; `CONTEXT_HYGIENE_FORCE_NO_RG=1 node scripts/context-hygiene-check.mjs`; `node --test tests/docs/context-hygiene-check.test.mjs`; `git diff --check`.
Result: Lowers active rolling windows to 8 worklog entries and 12 ledger rows, tightens decision/structure budgets, trims active index prose, and archives the adopted watch-items plan. Active Markdown is below the 85% waterline.
Audit: Kept current facts; compressed routing/index prose in project structure, screen inventory, navigation, UX, and current risks; archived older rolling-window rows verbatim. No referenced active file was deleted.
Risks: Docs/workflow tooling only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, push, or remote write changed.
```
