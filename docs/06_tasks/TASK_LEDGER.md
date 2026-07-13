# Task Ledger

Task ID, status, and next-number source of truth. Keep only planned, active, blocked, and the latest completed rows. Detailed evidence belongs in `docs/00_memory/WORKLOG.md`; older rows live under `docs/09_frozen/task_ledgers/`.

Current branch and task-numbering baseline: use `codex/pet-fit-structure-cleanup`; use `T-347` for the next new task. T-346 is completed, and T-340 remains separately planned.

Active blocked task: T-157 waits for paid Apple Developer Program access and APNs credentials before dispatcher deployment. Q-104 remains user-deferred and is tracked in `docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md` rather than as an allocated task.

Pre-reset source snapshot: `docs/09_frozen/active_state_snapshots/T-345_2026-07-13/TASK_LEDGER.md`. Removed T-332 through T-339 rows live under `docs/09_frozen/task_ledgers/`.

## Recent and Current Tasks

| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |
|---|---|---|---|---|---|---|---|
| T-346 | Roadmap and completed-artifact rotation | completed | Quick | G0 | Roadmap/Queue; active contracts/indexes; completed plans/specs; identity checker/tests; frozen/task memory | Brand audit/test; docs tests; diff/path/word/context checks | Keeps only unresolved roadmap direction, freezes completed task artifacts, and moves current brand/address authority into active domain contracts with all backlinks updated. |
| T-345 | Active-state reset and context reduction | completed | Quick | G0 | Current State, Worklog, Task Ledger, memory/frozen indexes and snapshots | Docs governance tests; diff/search/word/context checks | Replaces historical startup narrative with current facts, keeps six compact closeouts and eight ledger rows, and preserves the original files plus removed entries in frozen archives. |
| T-344 | Direct Customer Request Offers entry and action hierarchy | completed | Standard | M14 | Customer Request actions; dedicated Offers page; focused contracts | Focused tests; iOS build; source/diff/context audits | Request cards expose status-backed Offers; the dedicated page owns Offer loading/detail/acceptance and Request Details no longer owns Offers. |
| T-343 | Shared Customer/Groomer Account architecture | completed | Standard | M14 | Shared Account/settings/photo primitives; Customer and Groomer Account/Profile surfaces | Focused test; full iOS tests/build; UI debt/source audits | Both roles share Account presentation architecture without Store, repository, or backend changes. |
| T-342 | Groomer Profile RPC null-parameter correction | completed | Standard | M14 | Shared Profile address RPC encoder; focused tests | Runtime trace; focused/full tests; iOS build | Nil Apple Place IDs encode as explicit JSON null; no backend or remote state changed. |
| T-341 | Customer Hero and global palette alignment | completed | Standard | M14 | Customer Hero; semantic color roles; shared primitives | Focused/full tests; iOS build; user visual approval | Customer surfaces use the approved #333333 and Display P3 palette while Groomer/status roles remain independent. |
| T-340 | iOS compiler warning audit and cleanup | planned | Standard | M14 | Supabase Auth repository; Customer Request reminder synchronization | Pending focused/full iOS validation | Remove the app-owned redundant-await and unused-result warnings without behavior changes; retain AppIntents metadata output as toolchain information unless App Intents is adopted. |
| T-157 | Customer APNs push notification foundation | blocked | Deep | M2 | APNs dispatcher and iOS registration foundation | Historical validation in frozen records | Database foundation is applied; deployment waits for Apple Developer access and APNs credentials. |
