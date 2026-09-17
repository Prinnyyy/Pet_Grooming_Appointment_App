# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md

Date archived: 2026-07-09

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
