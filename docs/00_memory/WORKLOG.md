# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-09
Task: T-213 - Time and boundary contract tests.
Files changed: time-boundary migration contract tests, roadmap, current state, task ledger, and worklog.
Checks: Focused `node --test tests/migrations/time-boundary-contract.test.mjs`; `node --test tests/migrations/*.test.mjs`; `./scripts/supabase-check.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-25/R-028 by adding focused backend contract coverage for groomer-local request-day matching, exact offer/booking availability windows, time-off overlap, minimum advance notice, daily capacity, expiry edge conversion, and service size-band limits.
Risks: Test-only backend contract coverage. No Supabase schema, migration, remote write, repository API signature, UI layout, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
Next: Use T-214 for the next user-chosen task; recommended queue start is Q-26 decode/data tolerance tests.
```

```text
Date: 2026-07-09
Task: T-212 - Split groomer profile surfaces.
Files changed: groomer profile root/account/profile form/services/portfolio/fit/availability/status SwiftUI files, roadmap, current state, task ledger, and worklog.
Checks: Full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-24/R-026 by splitting the oversized GroomerProfileManagementView surface into focused account, profile form, services, portfolio, fit signals, availability, and status/preview files while preserving runtime behavior.
Risks: Structure-only groomer profile refactor. No Supabase schema, migration, remote write, repository API signature, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-211 - Split customer requests view.
Files changed: customer request root/dashboard/detail/wizard/status SwiftUI files, stale groomer tab model test expectation, roadmap, current state, task ledger, and worklog.
Checks: Full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-23/R-026 by splitting the oversized CustomerRequestsView surface into focused root, dashboard, detail, wizard, and status/preview files while preserving runtime behavior.
Risks: Structure-only request UI refactor plus one stale test expectation alignment for the existing groomer Alerts tab. No Supabase schema, migration, remote write, repository API signature, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-210 - Unread badge propagation.
Files changed: chat model/store/repository/view, customer/groomer tab badge rules and shared tab-level stores, customer home notification store injection, focused chat/badge tests, roadmap, current state, task ledger, and worklog.
Checks: ChatStore/TabBadge RED/GREEN; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-22/R-025 by propagating notification and chat badge counts at customer/groomer tab roots, loading shared badge sources on tab startup, showing customer Home notification badges, customer/groomer Messages unread badges, groomer Alerts unread badges, and clearing local chat unread state when a thread is opened.
Risks: Chat unread state is local/session-scoped because no read-receipt schema exists in the Standard Q-22 scope. No Supabase schema, migration, remote write, repository API signature, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-209 - Local appointment reminders.
Files changed: appointment reminder scheduler, bookings store/view, customer requests store, focused booking/request tests, roadmap, current state, task ledger, and worklog.
Checks: Appointment reminder planner/store RED/GREEN; CustomerRequests accept reminder RED/GREEN; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-21/R-025 by adding local notification reminder planning/scheduling for future confirmed bookings, page-level refusal copy when local notifications are disabled, reminder sync after booking load and offer acceptance, and reminder cancellation after booking cancel/complete.
Risks: Local notifications require user authorization at runtime. No Supabase schema, migration, remote write, repository API, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-208 - Notification domain tests.
Files changed: customer/groomer notification models, customer/groomer notification focused tests, roadmap, current state, task ledger, and worklog.
Checks: CustomerNotificationsStoreTests/GroomerNotificationsStoreTests RED/GREEN; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-20/R-028 by covering duplicate concurrent read/mark-all guards, mark-all failure/cancellation state preservation, repository debug event metadata, and unknown notification kind decode fallback for customer and groomer notifications.
Risks: No Supabase schema, migration, remote write, repository API, UI layout, Auth config, seed, TestOps remote execution, deploy, APNs, release upload, tag, PR, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-207 - Meta-review and context hygiene.
Files changed: current state, task ledger, worklog, frozen rotated ledger/worklog rows.
Checks: `git status --short`; `git diff --check`; context hygiene; commit and push.
Result: Runs the required 10-task cadence review after T-206, rotates excess active ledger/worklog rows, confirms active roadmap/queue/current-state pointers align, and keeps Q-20 as the next roadmap package.
Risks: Governance-only cleanup. No app code, Supabase schema, migration, remote write, Auth config, seed, TestOps remote execution, deploy, APNs, release upload, tag, PR, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-206 - Offer domain tests.
Files changed: GroomerOffersFeatureTests, GroomerRequestFeatureTests, GroomerRequestsStore, roadmap, current state, task ledger, and worklog.
Checks: GroomerOffersStoreTests/GroomerRequestsStoreTests RED/GREEN; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-19/R-028 by adding focused coverage for offer empty/cancelled list states, stale request and active-offer conflicts, and rejected accepted-offer withdrawal. Production change clears stale success notice before local withdraw rejection.
Risks: No Supabase schema, migration, remote write, repository API, UI layout, dependency, Auth config, seed, TestOps remote execution, deploy, APNs, release upload, tag, PR, merge/rebase/reset, or force-push changed.
```
