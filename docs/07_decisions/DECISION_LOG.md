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
Decision ID: D-011
Date: 2026-07-08
Decision: Keep branch baseline as a single active fact in CURRENT_STATE.
Context: `AGENTS.md`, `TASK_LEDGER.md`, and `CURRENT_STATE.md` all named the branch baseline, but hygiene checked only the latter two.
Consequences: `AGENTS.md` now points to `CURRENT_STATE.md` for branch baseline. `TASK_LEDGER.md` keeps its task-numbering baseline and remains checked against CURRENT_STATE by hygiene. Claude's entry map includes ROADMAP, Git rules, and this decision log for planning and rule review.
Linked files: AGENTS.md, CLAUDE.md, docs/00_memory/CURRENT_STATE.md, docs/06_tasks/TASK_LEDGER.md, docs/07_decisions/DECISION_LOG.md
```

```text
Decision ID: D-010
Date: 2026-07-08
Decision: Track meta-review cadence by completed-task distance, not wall-clock age.
Context: The review plan requires a marker for "every 10 completed tasks or weekly" so hygiene can catch missed governance reviews. Calendar-only failures would turn red while the project is idle.
Consequences: `CURRENT_STATE.md` records `Last meta-review: T-### on YYYY-MM-DD.` Context hygiene fails when the marker is missing or 10+ completed tasks behind the latest completed task. Weekly cadence remains a human reminder in `META_REVIEW_TEMPLATE.md`.
Linked files: docs/00_memory/CURRENT_STATE.md, docs/06_tasks/META_REVIEW_TEMPLATE.md, scripts/context-hygiene-check.mjs
```

```text
Decision ID: D-009
Date: 2026-07-08
Decision: Record the T-163 through T-173 batch commits as a one-time historical exception.
Context: Commits `01c80e4` and `6d1da33` landed the docs-governance sequence in two user-authorized batches while the one-task-per-commit rule was being introduced and then hardened.
Consequences: Do not rewrite, amend, rebase, revert, or force-push those commits for formatting alone. From T-174 onward, commits must follow `T-xxx: <type>: <summary>` and should contain one primary task, including governance tasks.
Linked files: docs/05_workflow/GITHUB_RULES.md, docs/06_tasks/TASK_LEDGER.md
```

```text
Decision ID: D-008
Date: 2026-07-08
Decision: Treat `main` commit `2fddf7b` as reviewed and superseded by this branch's governance architecture.
Context: The commit exists only on `main`/`origin/main`, is not an ancestor of `codex/pet-fit-structure-cleanup`, and resets docs to a T-049/T-050-era architecture.
Consequences: Do not merge `2fddf7b` into this branch. Future `main` reconciliation should carry this branch's governed docs forward or cherry-pick only explicitly reviewed non-stale changes.
Linked files: docs/05_workflow/GITHUB_RULES.md, docs/00_memory/CURRENT_STATE.md, docs/06_tasks/TASK_LEDGER.md
```

```text
Decision ID: D-007
Date: 2026-07-08
Decision: Workflow-rule file changes must be standalone governed tasks.
Context: Changes to `AGENTS.md`, `CLAUDE.md`, and active workflow docs alter future agent behavior.
Consequences: Any change to those files must use its own `T-###`, update this log, and run context hygiene before closeout.
Linked files: AGENTS.md, CLAUDE.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/STOP_CONDITIONS.md
```

```text
Decision ID: D-006
Date: 2026-07-08
Decision: Treat context hygiene as the machine check for active-doc fact drift.
Context: Manual review alone missed budget drift, stale verification dates, roadmap evidence gaps, and Feature Index path drift.
Consequences: Key indexes carry `Last verified` markers, backend docs record migration mirror count, ROADMAP task IDs need ledger evidence, and Feature Index read-first paths must resolve.
Linked files: scripts/context-hygiene-check.mjs, tests/docs/context-hygiene-check.test.mjs, docs/06_tasks/ROADMAP.md, docs/00_memory/FEATURE_INDEX.md
```

```text
Decision ID: D-005
Date: 2026-07-07
Decision: Make preflight the local gate for migration and Edge Function static tests.
Context: `tests/migrations/` and `tests/functions/` existed, but preflight did not run them.
Consequences: Backend tasks should add or update local Node tests before authorized remote validation. Preflight does not replace migration list, dry-run, apply, metadata, advisors, or deploy checks.
Linked files: scripts/preflight.sh, tests/scripts/preflight.test.mjs, docs/04_ios/IOS_BUILD_AND_TESTING.md, docs/03_backend/MIGRATION_RULES.md
```

```text
Decision ID: D-004
Date: 2026-07-07
Decision: Use `docs/06_tasks/ROADMAP.md` as the only managed roadmap index.
Context: External V1.0 drafts were useful review input but carried stale task numbers.
Consequences: External drafts stay frozen. ROADMAP may hold milestones, DoD, candidate work, and completed mapping, but task numbering/status remains owned by `TASK_LEDGER.md`.
Linked files: docs/06_tasks/ROADMAP.md, docs/06_tasks/TASK_LEDGER.md, AGENTS.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md
```

```text
Decision ID: D-003
Date: 2026-07-07
Decision: Require task-prefixed Git/GitHub operations for new commits and release actions.
Context: Governance review found mixed commit-message styles, no task prefix requirement, no release tag rule, and no explicit `main` reconciliation boundary.
Consequences: New commits use `T-xxx: <type>: <summary>`. Tags and `main` reconciliation remain explicit user-approved tasks.
Linked files: docs/05_workflow/GITHUB_RULES.md, docs/05_workflow/TOOLING_POLICY.md, docs/06_tasks/TASK_LEDGER.md
```

```text
Decision ID: D-002
Date: 2026-07-07
Decision: Treat root governance plans as external review input, not active project fact.
Context: External plans can lag active branch, task numbering, validation, or product state.
Consequences: Preserve adopted plans under `docs/09_frozen/external_agent_reports/`; execute compatible improvements through active ledger tasks.
Linked files: docs/09_frozen/external_agent_reports/, AGENTS.md, docs/06_tasks/TASK_LEDGER.md, docs/00_memory/CURRENT_STATE.md
```

```text
Decision ID: D-001
Date: 2026-07-07
Decision: Promote customer notification work from deferred concept to approved scoped product behavior through T-153 and T-157.
Context: T-153 implemented customer in-app notifications and T-157 applied the APNs database/iOS foundation, while dispatch remains blocked by Apple Developer credentials.
Consequences: Active docs may reference customer in-app notifications and the blocked APNs foundation as current facts. New push behavior still requires explicit user approval.
Linked files: docs/01_product/PRODUCT_BRIEF.md, docs/05_workflow/STOP_CONDITIONS.md, docs/06_tasks/TASK_LEDGER.md
```

## Archived Decision Index

Full text for the entries below is preserved in `../09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.

| Date | Decision | Current entry point |
|---|---|---|
| 2026-07-02 | Support modern Supabase `sb_secret_...` keys in TestOps as `apikey`-only server credentials. | `../04_ios/testops/RUNBOOK.md`, `../05_workflow/TOOLING_POLICY.md` |
| 2026-07-01 | Separate Supabase CLI credentials from project API keys in local runbooks. | `../05_workflow/TOOLING_POLICY.md`, `../03_backend/MIGRATION_RULES.md` |
| 2026-07-01 | Run linked Supabase CLI commands single-flight and inspect ignored credential files only under explicit authorization. | `../05_workflow/TOOLING_POLICY.md`, `../03_backend/SUPABASE_CONTRACT.md` |
| 2026-07-01 | Treat repository-local migration filenames as canonical and use `supabase db push --linked` as the normal deployment path. | `../03_backend/MIGRATION_RULES.md`, `../03_backend/SUPABASE_CONTRACT.md` |
| 2026-06-25 | Use Supabase CLI for every current and future Supabase task in this repository. | `../05_workflow/TOOLING_POLICY.md`, `../03_backend/MIGRATION_RULES.md` |
| 2026-06-20 | Pin Supabase Swift to 2.46.0 and inject publishable configuration through ignored local xcconfig. | `../03_backend/SUPABASE_CONTRACT.md`, `../../ios/PetGroomerMarketplace/` |
| 2026-06-19 | Treat the existing non-Groomly Supabase project as legacy and use the isolated `Pet Groomer Marketplace` project. | `../00_memory/CURRENT_STATE.md`, `../03_backend/SUPABASE_CONTRACT.md` |
| 2026-06-19 | Use the Fresh Brief open-request marketplace as the product model; fixtures are preview/test-only. | `../01_product/PRODUCT_BRIEF.md`, `../02_architecture/` |
