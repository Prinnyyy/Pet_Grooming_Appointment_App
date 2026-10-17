# Historical Task Ledger

Retired from allocation and daily updates by T-386. Rows below are preserved history, not current task status or execution instructions. Use [Current State](../00_memory/CURRENT_STATE.md) for allocation, pending work and recovery; historical missing completion commits are not retroactively claimed.

## Later Disposition

- T-386 governance was subsequently completed; see the [completed plan](../superpowers/plans/2026-09-10-lean-governance-plan.md) and completion commit `2be279f4`. Its planning row below is not an open task.
- T-365, T-366 and T-367 were closed by T-405 on 2026-10-17 (`4dfae125`). Their documents first entered Git in T-386; functional acceptance completed in T-385. See the [findings disposition](APP_FUNCTIONAL_DESIGN_FINDINGS.md) and [completed reliability plan](../superpowers/plans/2026-09-07-functional-reliability-task-plan.md). The original blocked rows remain historical evidence, not functional backlog or claims of separate original completion commits.
- Old cadence gates, physical-device requirements and task handoffs below describe their recording dates. Current scope and pending work belong only to Current State; Git owns the branch. Do not resume work from these rows.

## Archived Ranges

- [T-354 through T-360](../09_frozen/task_ledgers/TASK_LEDGER_T-354_TO_T-360_2026-09-07.md)
- [T-361 through T-371](../09_frozen/task_ledgers/TASK_LEDGER_T-361_TO_T-371_2026-09-08.md)
- [T-372 through T-378](../09_frozen/task_ledgers/TASK_LEDGER_T-372_TO_T-378_2026-09-10.md)

Pre-reset source snapshot: `docs/09_frozen/active_state_snapshots/T-345_2026-07-13/TASK_LEDGER.md`. Removed T-332 through T-339 rows live under `docs/09_frozen/task_ledgers/`.

## Historical Snapshot Through T-386 Planning

| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |
|---|---|---|---|---|---|---|---|
| T-386 | Lean governance for rules, state and validation | planned | Quick | G0 | docs/superpowers/plans/2026-09-10-lean-governance-plan.md; minimal task pointers | Planning only; no rule/script/app/backend changes | Four work packages, file dispositions, atomic rule/checker cutover, safety/evidence/rollback criteria. Await execution adoption; not an automatic periodic-review task. |
| T-385 | Local integrated compatibility and functional acceptance | completed | Deep | M15 | WP-14 and final WP-00; Simulator-only scope | Two actual app lifecycles/interruption/reconnect, 83 migrations, exact cleanup, full regression/build/preflight | sql_reviews/T-385_RELEASE_CHECKPOINT.md; fixed quote forwarding, notification bulk-read and Realtime publication. Existing governance cadence exception, no physical/store gate. |
| T-384 | Core-first loading without stale state | completed | Standard | M15 | Original WP-13/C-01 | Fixed measurements, optional failures, mutation/session/dirty-edit guards, 602 Swift tests, UI/build/preflight | sql_reviews/T-384_CORE_LOADING_ACCEPTANCE.md; no backend change. Original WP-14 next. |
| T-383 | Complete password recovery | completed | Deep | M15 | Original WP-12/F-07 | Delivered email/real SDK isolation/update/reuse, two-account cleanup, 587 Swift tests, UI/build/preflight | sql_reviews/T-383_PASSWORD_RECOVERY_ACCEPTANCE.md; physical-device handoff remains WP-14. |
| T-382 | Account-scoped reminder reconciliation | completed | Deep | M15 | Original WP-11/F-09 | Installed snapshot/cancellation/access/cleanup, full regression/build/runtime/preflight | Applied immutable 20260909004101; 82 aligned versions. sql_reviews/T-382_REMINDER_ACCEPTANCE.md. |
| T-381 | Actionable notifications and deliberate acknowledgement | completed | Deep | M15 | Original WP-10, F-08/C-02 | Installed SQL/HTTP/access, routes/retry/session, full regression/UI/build/preflight passed | 81 aligned versions. sql_reviews/T-381_NOTIFICATION_ACCEPTANCE.md; two-device qualification remains WP-14. |
| T-380 | Bounded chat summaries and exact conversation lookup | completed | Deep | M15 | Original WP-09, F-06/F-10 | Installed cap/tie/access/cost, exact routing/SDK, serial full regression/build/preflight passed | Applied immutable 20260908234932; 80 histories aligned. See sql_reviews/T-380_CHAT_SUMMARY_ACCEPTANCE.md. |
| T-379 | Correct scoped booking and request reads | completed | Deep | M15 | Original WP-08: nearest appointment, complete date scopes, exact request recovery | 55-item fixtures, tied pagination, date changes, unavailable/foreign reads, runtime, final full regression/build/preflight passed | See sql_reviews/T-379_SCOPED_READ_ACCEPTANCE.md; no migration or remote write. |
| T-369 | Functional reliability WP-00 preparation | completed | Quick | M15 | D-038 and scoped backend preparation; final disposition under T-385 | Original read-only catalog evidence; subsequent package decisions and T-385 compatibility matrix | Remaining policy/contracts/old-writer/legacy questions resolved in the original work packages and T-385, not claimed as runtime tests of the original preparation. |
| T-367 | Formal functional-reliability task plan | blocked | Quick | M15 | Proposed master task plan; findings backlink; documentation index; task memory | Metadata/coverage/dependencies/114 links/whitespace/diff passed; hygiene still fails on two backend freshness gates and checkpoint mismatch | WP-00...WP-14 cover 22 register items and eight self-review corrections with dependencies, decision gates, ownership, acceptance, and rollback boundaries. Planning only; no implementation adoption or remote authorization. |
| T-366 | Record request lifecycle and matching review addendum | blocked | Quick | M15 | App functional design findings; task memory | Tracked diff check passed; hygiene failed on backend freshness and blocked-checkpoint/completed-task mismatch | Adds F-11...F-15 and L-01...L-04, extends F-02/F-05/F-06, and identifies unfinished matching verification. No remediation, product-policy adoption, commit, or push. |
| T-365 | Record app functional design review findings | blocked | Quick | M15 | App functional design findings; documentation index; task memory | Evidence/links review; initial diff check passed; closeout precheck failed on existing backend-document freshness | F-01...F-10 and C-01...C-03 are saved and open for discussion. Supabase Contract and Migration Rules verification dates exceed the 45-day freshness gate; no commit/push or remediation performed. |
| T-157 | Customer APNs push notification foundation | blocked | Deep | M2 | APNs dispatcher and iOS registration foundation | Historical validation in frozen records | Database foundation is applied; deployment waits for Apple Developer access and APNs credentials. |
