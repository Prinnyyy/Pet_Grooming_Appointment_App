# Historical Worklog

Retired from daily updates by T-386. The entries below preserve their original claims and timestamps; they are not current instructions. Live task and recovery facts belong only to [Current State](CURRENT_STATE.md).

Later closure of T-365 through T-367 and implementation of T-386 are summarized in the [historical ledger disposition](../06_tasks/TASK_LEDGER.md#later-disposition). Original handoffs and verification gaps below must not reopen completed work.

```text
Date: 2026-09-10
Task: T-386 - Lean governance plan (planned; implementation not started).
Scope: User requested a governance plan after the read-only Astra-era workflow audit. Added docs/superpowers/plans/2026-09-10-lean-governance-plan.md and minimal current/ledger pointers; preserved existing dirty files.
State: Four packages define single dynamic state, concise rules/navigation, coupled checker/preflight migration, safety/evidence and reversible validation. No rules, scripts, app, backend or host settings changed; no checkpoint commit/push authorization inferred.
Validation: Plan metadata, four-package/twelve-case coverage, placeholder/whitespace and diff checks pass. Hygiene finds only the existing T-372-to-T-385 cadence failure; no new link/status error. No app/backend tests were required or run.
Next: Review/adopt execution of this plan; existing governance cadence failure remains a baseline, not silently repaired by planning.
```

```text
Date: 2026-09-10
Task: T-385 - Local integrated compatibility and functional acceptance.
Scope: Original WP-14 and outstanding WP-00, after T-384 completion/push 37d01435. No timezone-settings adjustment or governance expansion.
Result: Locally accepted. Fixed actual quote Debug readback forwarding, shared notification page bulk-read on exit, and missing messages Realtime publication. Applied immutable 20260910075314; 83 versions align, empty dry run. Two independent actual Simulator roles completed publish/quote/accept/chat/reschedule rejection/start/complete/review and a second withdrawal/re-quote/accept/cancel lifecycle. Actual committed-result interruption/restart, system keyboard, stale-notification current routing, OS reminder 1-to-0 reconnect, account switch and expired callback pass. Exact 39-field fixture restoration and the guarded 62-row notification read repair pass; no tagged requests or disabled profile triggers remain.
Scope clarification: User explicitly requires completion on this Mac using Simulators only. Physical devices, signing/provisioning and App Store/TestFlight/distribution are removed from task requirements, not deferred blockers. The prior stop was based on an over-restrictive interpretation of two-device evidence.
Validation: Final serial regression reports 603 Swift tests/60 suites passing (one environment skip), XCTest 22/one email bridge skip and UI 10/six fixture skips; separately linked actual/prior evidence covers skipped flows. Simulator build and preflight (3/116/10 tests) pass. Initial parallel run exposed a 50ms avatar-test assumption; changed only its wait to a bounded actual-read signal, preserving assertions. Final apps installed and launched as customer/groomer. Full evidence and 14-scenario/22-item/8-correction disposition: docs/06_tasks/sql_reviews/T-385_RELEASE_CHECKPOINT.md.
Handoff: Entire original plan functionally accepted under local-only scope; T-385 completion c24ca4f3 pushed on codex/pet-fit-structure-cleanup. Existing meta-review cadence exception remains explicit; no unified governance green claim. Earlier shared drafts/rules preserved separately. No further functional package or timezone-settings task started.
```

```text
Date: 2026-09-09
Task: T-384 - Core-first loading without stale state.
Scope: Original WP-13/C-01 after T-383 completion/push a34cb17d. Preserve critical-data failure handling, profile drafts, account boundaries and newer mutations; no new generic loading framework.
Result: Accepted under D-052. Core-first profile/request loading, bounded image batches, optional editing readiness, dirty-form and load/mutation/session guards. Controlled profile core 160.8ms to 69.2ms, request core 102.1ms to 1.3ms with unchanged calls/image bytes. Final /tmp/beckon-t384-final-regression.log passes 602 Swift tests/60 suites plus rendering and four default UI cases/six environment skips. Build and preflight pass; runtime images inspected. See docs/06_tasks/sql_reviews/T-384_CORE_LOADING_ACCEPTANCE.md.
Handoff: Completed/pushed 37d01435; original T-385/WP-14 follows. Device inventory reports no connected devices; original physical-device gates remain required. Existing meta-review cadence exception remains recorded, not a passing closeout claim.
```

```text
Date: 2026-09-09
Task: T-383 - Complete password recovery.
Scope: User resumed original WP-12 after T-382 completion/push 666d11b4. No timezone-settings work.
Result: Completed under D-051. Separate secure PKCE recovery session, exact appended redirect, resend/retry/return and partial-cleanup paths. Real Supabase email delivered by Resend; actual SDK password update/new login/reused-code denial preserved the other active account. Both temporary accounts removed and absence verified. Final 587 Swift tests/59 suites plus rendering, UI four executed/six fixture skips, build and preflight pass. See docs/06_tasks/sql_reviews/T-383_PASSWORD_RECOVERY_ACCEPTANCE.md for evidence and corrected entry/transition issues.
Handoff: Completion commit/push a34cb17d, then original T-384/WP-13. Physical-device handoff remains WP-14. The prior governance cadence exception remains explicit; no safety gate or review date changed.
```

```text
Date: 2026-09-08
Task: T-382 - Account-scoped reminder reconciliation.
Scope: Original WP-11 after T-381 completion/push 5d022174. No timezone-settings changes or APNs deployment.
Result: Completed. Immutable 20260909004101 applied; 82 histories align, empty dry run, installed owned cancellation/access and zero fixture residue pass; no new advisor WARN/ERROR. Full serial regression 580 Swift tests/58 suites plus rendering, build/preflight pass. Current cancelled/missing reminder target screenshots inspected. See docs/06_tasks/sql_reviews/T-382_REMINDER_ACCEPTANCE.md for late fetch/write, permissions, partial-scope, UTC and offline limits.
Handoff: Completion commit 666d11b4. User requested pause after WP-11; WP-12 remains unstarted, next T-383 on explicit resume. Strict closeout reports only the 10-task meta-review cadence; the prior user-directed original-plan execution exception is recorded, not a false hygiene success or review-date change. Preserve shared drafts and applied migrations; no background execution is planned.
```

```text
Date: 2026-09-08
Task: T-381 - Actionable notifications and deliberate acknowledgement.
Scope: Original WP-10 after T-380 completion/push 63fcb725; preserve owned current-state routes and independent acknowledgement.
State: D-049 implemented. Exact owned request/offer/match/booking/chat destinations open existing details and mark read only after resolution; cancelled/withdrawn targets use current state. Handoff caches only server-confirmed IDs under a versioned account key; retry and late-session/two-client cases pass. Applied immutable 20260909001015; installed pending/cancelled/access and independent read/acknowledgement vectors pass. Final serial full regression passes (570 Swift tests/57 suites plus rendering; default UI three executed/six skipped). Initial large-text screenshots exposed title compression; scoped responsive notification header correction is in final UI validation. No timezone-settings changes.
Result: Implementation/deployment complete. Final UI screenshots, build, preflight, installed SQL/HTTP/access/cleanup, 81 aligned versions and empty dry run pass; no new advisor WARN/ERROR. See docs/06_tasks/sql_reviews/T-381_NOTIFICATION_ACCEPTANCE.md. Original two-device qualification remains WP-14; two-client evidence is not physical-device evidence.
Handoff: Scoped completion commit/push, then T-382/WP-11 through WP-14. Preserve earlier shared drafts and applied migrations; no timezone-settings changes.
```

```text
Date: 2026-09-08
Task: T-380 - Bounded chat summaries and exact conversation lookup.
Scope: Original WP-09 after T-379 completion/push c5a0485f. Preserve participant access, private avatars, booking cards and local read semantics.
Result: Completed. Applied immutable 20260908234932; 80 histories align, empty dry run. Installed 1500-message/1000-cap reproduction, quiet previews/ties/access, indexed cost and zero fixture residue pass. Exact owned routing and SDK transport, final serial full regression (565 Swift tests/56 suites plus XCTest rendering), build and preflight pass. Default UI three executed/six skipped. See docs/06_tasks/sql_reviews/T-380_CHAT_SUMMARY_ACCEPTANCE.md for evidence and excluded wrapper/empty-fixture assumptions.
Handoff: T-381/WP-10 next, then original WP-11...WP-14. No timezone-settings work; earlier shared drafts preserved. New pair index initially unused INFO is intentional; no new advisor WARN/ERROR.
```

```text
Date: 2026-09-08
Task: T-379 - Correct scoped booking/request reads.
Scope: Original WP-08 after T-378 completion/push c7b1f491. Keep RLS, bounded list pages and original agreement/new-request rules.
State: D-047 adopted. Both Home roles now use nearest-eligible reads; Schedule reads all bounded pages for its selected half-open date scope with completion/stale/failure states and old-date response rejection. Exact booking/source reads support unloaded details/republish and preserve address reconfirmation. Debug wrappers now forward scoped/exact and earlier lifecycle/versioned interfaces rather than falling into unavailable defaults. 55-item nearest RED reproduced; date/exact/Home/republish tests passed. Transport assertion corrected for SDK nullslast serialization. First full integration passed other cases but failed the old accessibility scroll-size threshold; screenshots exposed the new DatePicker label wrapping, fixed with vertical label/control and inset-aware scrolling. Final changed-surface tests run in /tmp/beckon-t379-final-surfaces.log; final preflight passes. No backend schema/migration or remote writes in WP-08; applied 79-version baseline untouched.
Result: Completed. Final changed-surface/runtime, serial full regression, build and preflight passed; failed-date and accessibility images inspected. See docs/06_tasks/sql_reviews/T-379_SCOPED_READ_ACCEPTANCE.md. Default UI three executed/six skipped, with separate changed-surface runtime evidence.
Handoff: T-380/WP-09 next under original standards. Generic DebugGroomerRequestRepository older writer forwarding remains a WP-14 compatibility check; no timezone-settings changes.
```

```text
Date: 2026-09-08
Task: T-378 - Safe two-party rescheduling.
Scope: Original WP-07 after T-377 completed/pushed 8ee66212. Preserve original reservation until both participants accept a valid time-only change; keep existing duration, price, address, participants and pet.
Result: Completed. Applied immutable 20260908224104; 79 aligned histories and empty dry run. Installed authenticated SQL/boundary/access/replay, both real reschedule/cancel race orders and exact 39-field restoration pass. Final cleanup has zero fixture proposals/operations/disabled guards. Four client cases, both-role consent rendering, serial full regression (567 unique Swift cases), build/preflight and 19 race-tool cases pass. Advisors have no new WARN/ERROR; private RLS and retained FK indexes explain new INFOs. See docs/06_tasks/sql_reviews/T-378_RESCHEDULING_ACCEPTANCE.md for evidence and failed fixture/overlapping-build diagnosis.
Handoff: Completed and pushed c7b1f491; T-379/WP-08 is active. WP-08...WP-14 remain required. Shared unrelated drafts preserved; applied migrations immutable and account-timezone settings excluded.
```

```text
Date: 2026-09-08
Task: T-377 - Actual fulfillment and resource release.
Scope: Original WP-06 under D-045 and continuous-execution authorization. No account-timezone settings changes.
Result: Completed. Applied immutable migration 20260908214656; 78 versions aligned, dry run empty, advisors retain only existing findings. Installed authenticated lifecycle/replay/correction/nonzero release/quota/review/access vectors pass. Both real terminal winner orders and exact 39-field restoration pass; zero fixture events/disabled guards remain. Full regression 559 unique reported Swift cases, final provisional-handoff/recovery/reminder/Store and both-role rendering tests, build/preflight/UI/diff pass. See docs/06_tasks/sql_reviews/T-377_FULFILLMENT_ACCEPTANCE.md for evidence and failed fixture-policy setup diagnosis.
Handoff: Committed/pushed 8ee66212; T-378/WP-07 is active with original scope and standards. WP-07...WP-14 remain required; preserve earlier shared drafts. Applied migrations are immutable.
```

```text
Date: 2026-09-08
Task: T-376 - Versioned agreements and quote validity.
Scope: Original WP-05 under continuous-execution authorization; preserve WP-02 replay and WP-03/04 timing/eligibility. Account-timezone settings excluded.
Result: WP-05 completed. D-044 adopted; 20260908203810 and 20260908212824 applied and immutable, 77 histories aligned, final dry run empty. Complete agreement snapshots, owned versioned writers, atomic replacement, deadline/validity separation and non-reviving notice-policy changes verified. Installed SQL, four real HTTP lock races and exact 39-field restoration pass. Full regression had one obsolete copy assertion, corrected and covered by final focused suites; final deadline/recovery suite, both-role/replacement runtime, build, preflight and strict hygiene pass. Advisors retain existing Q-93/intentional INFOs. See docs/06_tasks/sql_reviews/T-376_AGREEMENT_ACCEPTANCE.md for concise evidence and failed-barrier diagnosis.
Handoff: Completion committed/pushed as 44fe624b; T-377/WP-06 is active. Original WP-06...WP-14 remain required. Physical-device/distribution, generic TestOps old-RPC compatibility and earlier keyboard screenshot belong to WP-14. Earlier shared document/governance drafts remain outside task Git scope; no account-timezone settings edits.
```

```text
Date: 2026-09-08
Task: T-375 - Feasible and explainable matching.
Scope: Execute original WP-04 after T-374 completion/push 71ffb595. Inspect installed definitions, add feasibility/size/legacy vectors, separate eligibility from ranking with consistent explanations, refresh affected matches while preserving dismissals, enforce writer checks, validate truthful recovery and measured quality/performance before deployment.
State: APPLIED 20260908185059 via /tmp/beckon-t375-deploy.log; worker paused/queue empty verified. Never edit this applied file. Final rollback rehearsal includes shared WP-03 timing vectors, actual occupied/fragmented bookings, custom/legacy assessment, unchanged equal-score exposure for BTG-002/003, authenticated publication/replay/reader isolation, direct quote/booking guards and batch/orphan handling. /tmp/beckon-t375-final-rehearsal.log passes. D-043 records scoped baseline/new timings (25 open-window calls: 2929/2518 ms; closed: 1408/1405 ms), initial budgets and append-only refresh events without cross-request foreign-key locks. Client transport/recovery, /tmp/beckon-t375-integration.log (UI three executed/six skipped), build and preflight pass. A custom_request literal defect was caught/fixed before installation. Initial exposure service and combined mutation/read assertions were fixture defects, corrected without weakening criteria. The old matcher already excludes whole-day time off; its reproduced false-positives are occupied/fragmented bookings below quota, not time off.
Installed acceptance: /tmp/beckon-t375-linked-matching-races-fixed.log passes both real lock-contention orderings, request-lock refresh retention, pending/current HTTP readback and exact 39-field restoration. Initial assertion wrongly expected exclusion after the helper restored time off; corrected fixture expectation passed without changing backend behavior. Worker job 4 is now active every 10 seconds; actual scheduled delivery drained the queue. All 75 histories align, dry run empty; advisors have no new blocker. Both pending/assessment UIKit rendering cases pass and exported screenshots were inspected. See docs/06_tasks/sql_reviews/T-375_MATCHING_ACCEPTANCE.md.
Result: Completed WP-04/F-04/F-14/F-15. Final focused rendering assertions also pass (/tmp/beckon-t375-final-ui.log). Scoped completion commit/push follows documentation gate, then original WP-05. Account-timezone settings excluded. Applied migration must not be edited; old paused-worker statements above describe installation only. Earlier shared document/governance drafts are preserved outside task Git scope.
```

```text
Date: 2026-09-08
Task: T-374 - Service timing and occupancy.
Result: Completed original WP-03 requirements: remaining preference windows, explicit editable service duration/price, immutable service/occupied timing snapshots, explicit location/schedule zones, buffers, DST occurrence handling, guarded admission and atomic availability Save. Existing accepted legacy timestamps/protection preserved; unsafe legacy quotes require replacement. No account-timezone settings feature.
Evidence: Applied append-only 20260908052312; 74 histories align; installed SQL assertions, empty dry run and security advisors (Q-93 only) pass. Actual HTTP v4 publish/replay -> automatic match -> offer/readback -> booking/read-only receipt replay plus both verified Save/admission lock orderings pass; exact 39-field restoration. See docs/06_tasks/sql_reviews/T-374_TIMING_BACKEND_ACCEPTANCE.md.
Client: Real Wizard cancellation/template/provider-confirmation/new publication and real quote occurrence/submission interactions pass, including inherited timezone/calendar change. Finite offer form uses VStack after observed lazy-layout/focus loop. Full /tmp/beckon-t374-final-integration.log and /tmp/beckon-t374-final-build.log pass; 359/1439-minute regressions pass /tmp/beckon-t374-broad-window-vectors.log; final preflight passes. 80 TestOps tests previously passed and unchanged evidence is reused.
Limits: Default UI runs three cases/six skipped; skipped cases are not acceptance. Supplemental system-keyboard-visible screenshot remains unverified and is retained for WP-14, not claimed as passing. Primary-window experiment reverted, flags removed, processes terminal. Generic TestOps cleanup conservatively preserves shared threads/untagged chat; exact restoration evidence uses the dedicated runner. Fixture/barrier failures are excluded, with restored data verified. Physical-device interruption/distribution remain WP-14; matching WP-04; fulfillment WP-06.
Handoff at completion: Unified closeout passed; committed/pushed 71ffb595. Continued as T-375/WP-04 under the user's explicit continuous-execution authorization. Unrelated prior document/governance drafts remain outside the completion commit.
```

Earlier preserved entries: [T-354 through T-360](../09_frozen/worklogs/WORKLOG_2026-09-07_T-354_TO_T-360.md), [T-361 through T-367](../09_frozen/worklogs/WORKLOG_2026-09-08_T-361_TO_T-367.md), and [T-368 through T-373](../09_frozen/worklogs/WORKLOG_2026-09-09_T-368_TO_T-373.md). Full pre-reset snapshots remain under `docs/09_frozen/active_state_snapshots/`. Git owns the current branch; this log and the retired ledger do not allocate tasks.
