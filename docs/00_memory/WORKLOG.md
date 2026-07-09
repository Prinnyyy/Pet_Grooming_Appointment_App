# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-09
Task: T-218 - Meta-review and context hygiene.
Files changed: current state, task ledger, worklog, roadmap, and frozen rotated rows.
Checks: `git status --short`; `git diff --check`; context hygiene; commit and push.
Result: Runs the required 10-task cadence review after T-207, rotates excess active ledger/worklog rows, confirms active roadmap/queue/current-state pointers align at Q-30/T-219, and records the new meta-review marker.
Risks: Documentation governance only. No product code, Supabase schema, migration, remote write, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
Next: Use T-219 for the next user-chosen task; recommended queue start is Q-30 list pagination/load audit.
```

```text
Date: 2026-07-09
Task: T-217 - Free-tier auth deep link.
Files changed: auth callback configuration/model, auth repositories, AuthenticationStore, app URL handling, Info.plist URL scheme, auth callback tests, backend auth docs, roadmap, current state, task ledger, and worklog.
Checks: AuthenticationStore RED/GREEN; full `./scripts/ios-test.sh`; `./scripts/supabase-check.sh`; `./scripts/ios-build.sh`; `plutil -lint ios/PetGroomerMarketplace/Config/AppInfo.plist`; simulator openurl smoke; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-29/R-027 by passing the Supabase sign-up redirect URL, registering `com.prinnyyy.petgroomermarketplace://auth/callback`, handling supported callback links through AuthenticationStore, and showing safe expired/invalid link copy without exposing callback tokens.
Risks: Local iOS callback implementation and docs only. Supabase Auth redirect allow-list, SMTP, production HTTPS domain, associated domains, migrations, seeds, deploys, release upload, tag, PR, merge/rebase/reset, and force-push were not changed.
```

```text
Date: 2026-07-09
Task: T-216 - State-machine edge tests.
Files changed: appointment reminder scheduler, AppointmentReminderPlan tests, roadmap, current state, task ledger, and worklog.
Checks: AppointmentReminderPlan RED/GREEN; full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-28/R-028 by adding focused reminder idempotence coverage for duplicate booking rows and making local appointment reminder planning dedupe by stable reminder identifier while preserving first valid reminder order.
Risks: Local iOS planner/test hardening only. No Supabase schema, migration, remote write, repository API signature, UI layout redesign, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-215 - Republish hardening.
Files changed: customer requests store, CustomerRequestsStore republish tests, roadmap, current state, task ledger, and worklog.
Checks: CustomerRequestsStore RED/GREEN; full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-27/R-027 by making request-photo metadata failure non-blocking for loaded original requests, keeping cancelled/expired request details available for republish, skipping missing/oversized copied photos, resetting expired preferred windows to a future default range, and refusing cancelled-booking republish when the original request is unavailable.
Risks: Local iOS store/test hardening only. No Supabase schema, migration, remote write, repository API signature, UI layout redesign, Auth config, seed, TestOps remote execution, deploy, APNs dispatch, release upload, tag, PR, merge/rebase/reset, or force-push changed.
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
