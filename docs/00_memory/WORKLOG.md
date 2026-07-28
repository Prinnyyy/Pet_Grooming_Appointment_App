# Worklog

```text
Date: 2026-07-28
Task: T-363 - Request page state and visual consistency.
Files changed: Customer Home/Requests state presentations and views; shared Request retry/position components; focused tests; roadmap and task memory.
Checks: TDD RED/GREEN; 102 focused Customer Request tests; complete iOS tests; iOS build; strict/global UI consistency, user-facing copy, diff, context, and unified closeout checks.
Result: Requests now keeps a direct New Request action above loading, empty, error, and loaded content. Home Active Request and Next Booking no longer disguise loading or failure as empty; persistent retry cards complement the existing global feedback path. Home and Requests carousels report the visible Request position, usable stale content wins over refresh failures, and obsolete Quest/handoff copy was removed.
Risks: Visible layout and interaction review remains user-owned. Q-104 Dynamic Type/Accessibility remains explicitly deferred.
Next: Use T-364 only after the next product package is explicitly adopted.
```

```text
Date: 2026-07-28
Task: T-362 - Offer confirmation and Booking handoff.
Files changed: Customer Offer detail/confirmation presentation; Customer Requests Store; focused fakes/tests; feature, roadmap, and task memory.
Checks: TDD RED/GREEN; focused and complete iOS tests; iOS build; user-facing copy, source, diff, context, and unified closeout checks.
Result: Accepting an Offer now opens one confirmation sheet with groomer, service, time, price, service location, address, and cancellation context. Confirmation is guarded locally and in the Store, RPC success creates a complete local Booking projection before refresh, and the flow opens Booking Detail directly without exposing backend terminology.
Risks: Visible layout review remains user-owned. The local Booking projection is a recovery bridge; refreshed repository data remains authoritative when available.
```

```text
Date: 2026-07-28
Task: T-361 - Periodic governance meta-review.
Files changed: Context hygiene/closeout scripts and tests; Current State, Worklog/archive, Feature Index, Roadmap queue, and Task Ledger.
Checks: 51 governance tests; context hygiene; default-search boundary, root Markdown, source-of-truth, repeated-rule, diff, and unified closeout checks.
Result: Active indexes, task facts, migration mirror, links, search exclusions, and workflow ownership remain coherent. Closeout prechecks now admit only explicitly authorized pending structural rotation, then require strict post-rotation hygiene; the Worklog threshold path no longer needs manual recovery.
Risks: Informational word telemetry still identifies several long domain references, but structural gates pass and no unbounded active-history growth was found.
```

```text
Date: 2026-07-28
Task: T-360 - Request photo selection and retry.
Files changed: Shared Customer Request photo preview/retry presentation; Wizard, Store, Home, Requests; focused tests; roadmap and task memory.
Checks: TDD RED/GREEN; focused and complete iOS tests; iOS build; source and diff checks; unified closeout and context hygiene.
Result: Request-specific photos now support multi-selection preview, per-photo removal, and a Review count without presenting the Pet avatar as an attachment. Once Request creation succeeds, only failed photo payloads are retained against that Request ID and can be retried or removed from one shared module shown on Home and Requests; retry never republishes the Request.
Risks: Visible layout review remains user-owned. Retry payloads survive tab navigation through the shared Store but are not an offline upload queue across app termination.
```

```text
Date: 2026-07-28
Task: T-359 - Request Wizard input and time semantics.
Files changed: Customer Request Wizard and Store; focused/address integration tests; roadmap and task memory.
Checks: TDD RED/GREEN; focused and complete iOS tests; iOS build; source and diff checks; unified closeout and context hygiene.
Result: New Requests no longer silently default to Full Groom. Customers must choose a service, Custom Request requires at least 10 trimmed characters of useful detail, the seven-day date strip now has a system date picker for later dates, and Continue uses the same enabled value for visuals and interaction while invalid taps reveal field-level errors.
Risks: Visible Wizard layout review remains user-owned. Request-photo preview, removal, review, and retry behavior remains Q-123.
```

```text
Date: 2026-07-28
Task: T-358 - Request publish idempotency and recovery.
Files changed: Private publish-operation table and v3 RPC; Customer Request model/repository/Store; TestOps publisher; rollback/static/iOS tests; backend, TestOps, feature, roadmap, and task memory.
Checks: TDD RED/GREEN; 81 migration tests; 28 focused migration/TestOps tests; focused and complete iOS tests; iOS build; Supabase/preflight checks; linked migration apply/history/final dry-run; rollback-only replay and authorization validation; security/performance advisors; diff and context/closeout checks.
Result: One Customer Wizard/TestOps publish operation now creates at most one Request and replays its original ID/match count. Once creation succeeds, photo upload and list refresh failures close the Wizard as published, emit one combined recoverable notice, and never surface a false publish failure.
Risks: Request-photo retry UI remains owned by Q-123. Q-93 leaked-password protection remains the only security advisor warning and requires a Supabase paid plan.
```

```text
Date: 2026-07-28
Task: T-357 - Customer Request Journey remediation design.
Files changed: R-042 roadmap and Q-121...Q-125 execution queue; D-036; task memory.
Checks: Docs governance; diff check; unified closeout; context hygiene.
Result: Adopted five dependency-ordered packages that address publish idempotency, Wizard input/time semantics, Request photos, informed Offer acceptance with direct Booking handoff, and Request page-state/visual consistency without mixing implementation into the design task.
Risks: Q-121 is a Deep backend contract and remains blocked from remote application until explicit Supabase migration authorization. Q-104 Groomer Dynamic Type/Accessibility remains user-deferred.
```

```text
Date: 2026-07-15
Task: T-356 - Manual preference and skill learning review.
Files changed: Learning review CLI/core/tests; memory guide; root README; task memory.
Checks: TDD RED/GREEN focused learning-review tests; context hygiene.
Result: Added a manual review-only script that reads transcript-like files or stdin, extracts preference and skill candidates with source evidence, deduplicates repeated statements, and writes a promotion checklist report without automatically changing AGENTS, workflow docs, or Codex skills.
Risks: The extractor is heuristic and intentionally conservative; candidate promotion remains manual and must be checked against current rules before durable updates.
```

```text
Date: 2026-07-14
Task: T-355 - Chat counterpart avatar hydration and access.
Files changed: Chat model/repository/participant avatar loader/list/thread; Customer avatar profile and Storage RLS migration; rollback/static/focused tests; UI audit baseline; backend/feature/task memory.
Checks: TDD RED/GREEN; focused Chat and migration tests; UI audit tests; preflight with 77 migration and 10 Edge Function tests; full iOS tests; iOS build; linked migration apply/history/final dry-run; rollback authorization SQL; security/performance advisors; diff check; unified closeout; context hygiene.
Result: Chat now carries one role-neutral counterpart avatar. Customers load Groomer avatars and Groomers load Customer avatars in the shared conversation row and thread header; remote RLS permits the reverse profile/object read only when the participant-pair conversation exists.
Risks: Server chat read receipts, attachments, and server expiry remain deferred. Q-93 leaked-password protection remains the known plan-gated security advisor warning; visual interaction review remains user-owned.
```

```text
Date: 2026-07-14
Task: T-354 - Shared Customer/Groomer Messages presentation.
Files changed: Shared Chat conversation-list presentation, title and card row; removed Groomer-only inbox presentation; focused contract; feature/task memory.
Checks: TDD RED/GREEN; 30 focused Chat tests; full iOS tests; iOS build; source audit; git diff check; unified closeout; context hygiene.
Result: Groomer Messages now uses the same custom Messages title, participant card, 64pt avatar, two-line preview, unread dot, timestamp, and read-only chip as Customer. The already-shared thread, message bubble, booking card, composer, Store, repository, pagination, and routing remain intact.
Risks: Visual interaction review is user-deferred.
```

This is the active recent closeout index, newest first. Full pre-reset source and removed closeouts are frozen under `docs/09_frozen/active_state_snapshots/` and `docs/09_frozen/worklogs/`.

Current branch, next task ID, and active work live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry keeps a `Next:` line.
