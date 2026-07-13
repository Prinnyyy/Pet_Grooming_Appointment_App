# Worklog

```text
Date: 2026-07-13
Task: T-348 - Workflow source-of-truth consolidation.
Files changed: AGENTS/Claude adapters; five workflow owner files; Meta Review template; root/docs/memory indexes; D-033; hygiene policy/check/tests; frozen source snapshots; task memory.
Checks: 36 docs governance tests, workflow ownership/forbidden-rule searches, local links, word/line telemetry, git diff check, and context hygiene passed.
Result: Seven rule/adapter files fell from 6,517 to 3,149 words. Each concern has one owner; AGENTS/Claude meet enforced 600/250-word ceilings. Meta-review now reserves a fresh session, host telemetry replaces fixed capacity, development RED differs from final validation, Simulator can be user-deferred, host skills are not capped, and incomplete checkpoint Git requires approval.
Risks: The orphan agent-preflight path and automatic completed-artifact rotation remain for the separate closeout-automation task. Existing generic telemetry overages outside workflow are informational.
Next: No automatic follow-up. Use T-349 for the next new task; T-340 remains separately planned.
```

```text
Date: 2026-07-13
Task: T-347 - Heavy UI context routing and design-contract separation.
Files changed: UI redesign routing/ignore rules; core, accessibility, form, and Groomer design contracts; active indexes; frozen source snapshots; context hygiene policy/check/tests; task memory.
Checks: 34 docs governance tests, git diff check, active links, default and fallback heavy-path visibility, word telemetry, and context hygiene passed.
Result: The 31.5k-word UI redesign body remains tracked but is hidden from default context behind one README. DesignSystem is a 660-word core entry; accessibility and form behavior are separate on-demand contracts. Completed Groomer execution history is removed from default feature routes and preserved verbatim in frozen snapshots.
Risks: Heavy evidence can become stale and must be verified against current code. Workflow source ownership, validation conflicts, and closeout automation remain separate tasks.
```

```text
Date: 2026-07-13
Task: T-346 - Roadmap and completed-artifact rotation.
Files changed: Managed Roadmap/Queue; active indexes/contracts; completed Superpowers, address, and brand plans; identity checker/tests; frozen indexes; task memory.
Checks: Brand identity audit/test, 33 docs governance tests, git diff check, active/frozen path checks, word telemetry, and context hygiene passed.
Result: Roadmap and Queue now contain unresolved direction only. Eleven completed Superpowers files and completed address/brand migration plans are frozen; active identity/address rules now live in domain contracts. All active backlinks were updated before the old paths were removed.
Risks: Heavy UI redesign inputs and workflow-rule/tool conflicts remain separate follow-up tasks. Q-104, T-157, Q-91, and Q-93 remain deferred or blocked.
```

```text
Date: 2026-07-13
Task: T-345 - Active-state reset and context reduction.
Files changed: Current State, Worklog, Task Ledger, memory/frozen indexes, and verbatim frozen snapshots/rotated entries.
Checks: Docs governance tests, git diff check, active archive/search checks, word/line telemetry, and context hygiene passed.
Result: Current State now contains only current task, validation, product, operational, and recovery facts. Worklog retains six compact closeouts and Task Ledger retains planned/blocked plus recent rows. Original pre-reset files and removed entries remain frozen and searchable only by explicit historical access.
Risks: Roadmap history, completed Superpowers plans, heavy UI redesign inputs, and workflow-rule conflicts remain separate follow-up tasks.
```

```text
Date: 2026-07-13
Task: T-344 - Direct Customer Request Offers entry and action hierarchy.
Files changed: Customer Request card actions, dedicated Offers destination, Request Detail ownership, focused contracts, spec/plan, and task memory.
Checks: Focused Customer Request tests, iOS build, source/diff/context audits.
Result: Active Request cards expose Detail, status-backed Offers, and full-width Cancel Request actions. Only hasOffers enables the Offers route; the dedicated page owns Offer loading, detail, pagination, and acceptance.
Risks: Offer availability trusts the Request status machine. T-340 retains the known compiler-warning cleanup.
```

```text
Date: 2026-07-13
Task: T-343 - Shared Customer/Groomer Account architecture and Groomer subtree restyle.
Files changed: Shared Account/settings/photo primitives and Customer/Auth/Groomer Account/Profile surfaces.
Checks: Focused DesignSystem test, full iOS tests/build, UI debt ratchet, source/diff/context audits.
Result: Customer and Groomer Account identity, navigation, support, grouped surfaces, dividers, and profile-photo presentation share one DesignSystem path without Store, repository, or backend changes.
Risks: Q-104 Dynamic Type/Accessibility remains deferred; T-340 retains the compiler warnings.
```

```text
Date: 2026-07-13
Task: T-342 - Groomer Profile save RPC null-parameter correction.
Files changed: Shared Profile address RPC encoder and focused address/Feedback tests.
Checks: Runtime trace, focused tests, full iOS tests/build, diff/context audits.
Result: Missing Apple Place IDs encode as explicit JSON null so PostgREST matches the nullable RPC argument. Feedback timing tests now wait on bounded state instead of racing MainActor scheduling.
Risks: No authenticated remote save was performed; no backend or remote state changed.
```

```text
Date: 2026-07-13
Task: T-341 - Customer Home Hero and global Customer palette alignment.
Files changed: Customer Home Hero, semantic Customer color roles, shared primitives, tests, spec/plan, and task memory.
Checks: Focused DesignSystem/Groomer tests, full iOS tests/build, source/diff/context audits, and user visual approval.
Result: Customer surfaces use #333333 plus approved Display P3 accent, soft, subtle, and strong roles while Groomer/status/surface semantics remain independent.
Risks: Q-104 remains deferred; no Store, repository, backend, dependency, or remote state changed.
```

This is the active recent closeout index, newest first. Full pre-reset source and removed closeouts are frozen under `docs/09_frozen/active_state_snapshots/` and `docs/09_frozen/worklogs/`.

Current branch, next task ID, and active work live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry keeps a `Next:` line.
