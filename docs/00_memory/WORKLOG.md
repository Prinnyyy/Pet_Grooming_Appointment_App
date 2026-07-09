# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-09
Task: T-215 - Republish hardening.
Files changed: customer requests store, CustomerRequestsStore republish tests, roadmap, current state, task ledger, and worklog.
Checks: CustomerRequestsStore RED/GREEN; full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-27/R-027 by making request-photo metadata failure non-blocking for loaded original requests, keeping cancelled/expired request details available for republish, skipping missing/oversized copied photos, resetting expired preferred windows to a future default range, and refusing cancelled-booking republish when the original request is unavailable.
Risks: Local iOS store/test hardening only. No Supabase schema, migration, remote write, repository API signature, UI layout redesign, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
Next: Use T-216 for the next user-chosen task; recommended queue start is Q-28 state-machine edge tests.
```

```text
Date: 2026-07-09
Task: T-214 - Decode and cache tolerance tests.
Files changed: marketplace status models, affected status UI surfaces, DecodeToleranceFeatureTests, roadmap, current state, task ledger, and worklog.
Checks: Focused DecodeTolerance RED/GREEN; full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-26/R-028 by adding safe unknown-status decode fallbacks, neutral unknown-status UI handling, malformed-date display tolerance, null optional pet snapshot coverage, and oversized corrupt private image cache rejection coverage.
Risks: Local iOS/model/test hardening only. No Supabase schema, migration, remote write, repository API signature, UI layout redesign, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-213 - Time and boundary contract tests.
Files changed: time-boundary migration contract tests, roadmap, current state, task ledger, and worklog.
Checks: Focused `node --test tests/migrations/time-boundary-contract.test.mjs`; `node --test tests/migrations/*.test.mjs`; `./scripts/supabase-check.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-25/R-028 by adding focused backend contract coverage for groomer-local request-day matching, exact offer/booking availability windows, time-off overlap, minimum advance notice, daily capacity, expiry edge conversion, and service size-band limits.
Risks: Test-only backend contract coverage. No Supabase schema, migration, remote write, repository API signature, UI layout, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
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
