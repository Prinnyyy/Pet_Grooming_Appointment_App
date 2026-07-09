# Decision Log

Use this for durable architecture/product/workflow decisions. Keep active entries compact; full historical text lives in frozen snapshots.

Full pre-T-174 snapshot: `../09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.

## Format

```text
Decision ID:
Date:
Decision:
Context:
Consequences:
Linked files:
```

## Active Decisions

```text
Decision ID: D-018
Date: 2026-07-09
Decision: Use a bounded roadmap execution queue between ROADMAP candidates and task-ledger work.
Context: The user asked to plan and create a series of tasks from `docs/06_tasks/ROADMAP.md`. ROADMAP is the governed milestone index and explicitly must not allocate future task IDs.
Consequences: `ROADMAP_EXECUTION_QUEUE.md` now lists adoptable packages Q-01 through Q-15 derived from R-005 through R-015. Future execution still receives the next `T-###` from `TASK_LEDGER.md`, one primary package per run, with blocked packages staying inactive until blockers clear.
Linked files: docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md, docs/06_tasks/TASK_LEDGER.md
```

```text
Decision ID: D-017
Date: 2026-07-08
Decision: Remove stale 85% active-Markdown execution rules and stop on rejected automatic pushes.
Context: T-183/T-184 replaced the 85% cleanup trigger with hard active-Markdown limits, 95% structural-review warnings, and deterministic rolling-window rotation, but older T-182 stop/closeout wording remained active. T-180 standing Git approval also did not define what to do when a push fails or is rejected.
Consequences: Active workflow rules now use `node scripts/context-rotate.mjs --apply` for rolling-window overflow, treat 95% active-Markdown warnings as review scheduling rather than compression targets, and stop only on hard-limit failures that cannot be resolved in scope. If a task-completion push fails or is rejected, Codex must stop and report without auto pull, rebase, merge, reset, force-push, or remote reconciliation.
Linked files: AGENTS.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/STOP_CONDITIONS.md, docs/05_workflow/TOOLING_POLICY.md, docs/05_workflow/GITHUB_RULES.md
```

```text
Decision ID: D-016
Date: 2026-07-09
Decision: Adopt the structural context-budget workflow in active agent rules.
Context: T-183 implemented the 36k active Markdown hard limit, default 650-word budgets, 95% structural-review warning, and deterministic rotation. The active workflow still described the older 85% cleanup trigger.
Consequences: `AGENTS.md` and `CONTEXT_AND_RECOVERY.md` now direct agents to use `node scripts/context-rotate.mjs --apply` for rolling-window overflow, treat active Markdown percentage as a structural signal rather than a compression target, keep WINDOW files bounded, use replacement semantics for INDEX files, and compress FIXED files only by owner-pointer, single-source, frozen-history, or frozen-example criteria. This supersedes D-014's 85% cleanup-trigger rule.
Linked files: AGENTS.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, scripts/context-hygiene-check.mjs, scripts/context-rotate.mjs
```

```text
Decision ID: D-015
Date: 2026-07-09
Decision: Replace the active Markdown 85% cleanup trigger with structural context-budget tooling.
Context: D-012 allowed a one-time total-limit increase only after repeated high-water reviews found no safe reduction path. T-181/T-182 showed the 85% warning had become a recurring closeout target instead of a useful signal, and the adopted redesign pairs the 36k limit with default per-file budgets, mechanical rotation, and a 95% structural-review warning.
Consequences: Context hygiene reports actual active Markdown percentage against 36k, fails only above the hard limit, applies a 650-word default to unlisted active Markdown, and checks fixed ledger/worklog/decision windows. `scripts/context-rotate.mjs` handles deterministic archive rotation; Batch B must align workflow text in a separate rule-change task.
Linked files: scripts/context-hygiene-check.mjs, scripts/context-hygiene-policy.mjs, scripts/context-rotate.mjs, tests/docs/
```

```text
Decision ID: D-014
Date: 2026-07-09
Decision: Superseded by D-016/D-017: treat the active Markdown 85% waterline as a cleanup trigger.
Context: T-181 showed context hygiene could pass while active Markdown stayed above the 85% warning line, causing repeated noisy closeouts.
Consequences: Historical context only while this entry remains active before rotation. Current rules use hard active-Markdown limits, 95% structural-review warnings, and rolling-window rotation instead of an 85% cleanup trigger.
Linked files: AGENTS.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/STOP_CONDITIONS.md
```

```text
Decision ID: D-013
Date: 2026-07-08
Decision: Treat task-completion commit and push as standing user-authorized Git actions.
Context: The user explicitly asked that every completed task be automatically authorized for commit and push. Prior workflow text required explicit per-task approval for both operations.
Consequences: After required validation passes, Codex should commit and push the current task's own changes on the current work branch. This does not authorize PRs, tags, branch deletion, merge/rebase/reset, Supabase writes, seeds, unrelated cleanup, unrelated user work, or any non-Git remote write.
Linked files: AGENTS.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/TOOLING_POLICY.md, docs/05_workflow/GITHUB_RULES.md
```

```text
Decision ID: D-012
Date: 2026-07-08
Decision: Reduce active Markdown before raising the 32k total budget.
Context: After T-178, active Markdown was about 92% of the 32k limit, and the watch-items review found no single giant file. The risk is slow long-tail growth across many indexes.
Consequences: T-179 lowers rolling windows to 8 worklog entries and 12 ledger rows, tightens old decision/structure budgets, and trims active indexes first. A one-time increase to 36,000 words is allowed only if two consecutive meta-reviews both find total active Markdown above 90% and no safe reduction item remains.
Linked files: scripts/context-hygiene-check.mjs, docs/00_memory/WORKLOG.md, docs/06_tasks/TASK_LEDGER.md, docs/10_project_structure/README.md
```

```text
Decision ID: D-011
Date: 2026-07-08
Decision: Keep branch baseline as a single active fact in CURRENT_STATE.
Context: `AGENTS.md`, `TASK_LEDGER.md`, and `CURRENT_STATE.md` all named the branch baseline, but hygiene checked only the latter two.
Consequences: `AGENTS.md` now points to `CURRENT_STATE.md` for branch baseline. `TASK_LEDGER.md` keeps its task-numbering baseline and remains checked against CURRENT_STATE by hygiene. Claude's entry map includes ROADMAP, Git rules, and this decision log for planning and rule review.
Linked files: AGENTS.md, CLAUDE.md, docs/00_memory/CURRENT_STATE.md, docs/06_tasks/TASK_LEDGER.md, docs/07_decisions/DECISION_LOG.md
```


## Archived Decision Index

Full text for the entries below is preserved in `../09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.

| Date | Decision | Current entry point |
|---|---|---|
| 2026-07-08 | Track meta-review cadence by completed-task distance, not wall-clock age. | `../09_frozen/decisions/DECISION_LOG_D-010_2026-07-09.md` |
| 2026-07-08 | Record the T-163 through T-173 batch commits as a one-time historical exception. | `../09_frozen/decisions/DECISION_LOG_D-009_2026-07-09.md` |
| 2026-07-08 | Treat `main` commit `2fddf7b` as reviewed and superseded by this branch's governance architecture. | `../09_frozen/decisions/DECISION_LOG_D-008_2026-07-09.md` |
| 2026-07-08 | Workflow-rule file changes must be standalone governed tasks. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-08 | Treat context hygiene as the machine check for active-doc fact drift. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Make preflight the local gate for migration and Edge Function static tests. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Use `docs/06_tasks/ROADMAP.md` as the only managed roadmap index. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Require task-prefixed Git/GitHub operations for new commits and release actions. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Treat root governance plans as external review input, not active project fact. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Promote customer notification work from deferred concept to approved scoped product behavior through T-153 and T-157. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-02 | Support modern Supabase `sb_secret_...` keys in TestOps as `apikey`-only server credentials. | `../04_ios/testops/RUNBOOK.md`, `../05_workflow/TOOLING_POLICY.md` |
| 2026-07-01 | Separate Supabase CLI credentials from project API keys in local runbooks. | `../05_workflow/TOOLING_POLICY.md`, `../03_backend/MIGRATION_RULES.md` |
| 2026-07-01 | Run linked Supabase CLI commands single-flight and inspect ignored credential files only under explicit authorization. | `../05_workflow/TOOLING_POLICY.md`, `../03_backend/SUPABASE_CONTRACT.md` |
| 2026-07-01 | Treat repository-local migration filenames as canonical and use `supabase db push --linked` as the normal deployment path. | `../03_backend/MIGRATION_RULES.md`, `../03_backend/SUPABASE_CONTRACT.md` |
| 2026-06-25 | Use Supabase CLI for every current and future Supabase task in this repository. | `../05_workflow/TOOLING_POLICY.md`, `../03_backend/MIGRATION_RULES.md` |
| 2026-06-20 | Pin Supabase Swift to 2.46.0 and inject publishable configuration through ignored local xcconfig. | `../03_backend/SUPABASE_CONTRACT.md`, `../../ios/PetGroomerMarketplace/` |
| 2026-06-19 | Treat the existing non-Groomly Supabase project as legacy and use the isolated `Pet Groomer Marketplace` project. | `../00_memory/CURRENT_STATE.md`, `../03_backend/SUPABASE_CONTRACT.md` |
| 2026-06-19 | Use the Fresh Brief open-request marketplace as the product model; fixtures are preview/test-only. | `../01_product/PRODUCT_BRIEF.md`, `../02_architecture/` |
