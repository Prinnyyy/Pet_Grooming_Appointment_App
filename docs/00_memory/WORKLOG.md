# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-09
Task: T-201 - Release readiness dry run.
Files changed: release readiness evidence, App Store privacy pointer, Supabase check script, roadmap, current state, task ledger, and worklog.
Checks: Preflight; TestOps unit; App Store privacy test; TestOps doctor/backend smoke5/matching dry-runs; TestOps launch smoke; Supabase check; Supabase security/performance advisors; full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-15/R-015 for local/read-only release readiness. Release evidence confirms E2E dry-runs, privacy checks, advisors, and iOS build/test gates pass without remote writes.
Risks: Security advisor still reports the known Auth leaked-password protection WARN. Q-07 production auth domain/SMTP and Q-09 APNs dispatch remain externally blocked. No TestFlight upload, App Store Connect change, remote TestOps execution, migration, seed, deploy, tag, PR, merge/rebase/reset, or force-push changed.
Next: Use T-202 for the next user-chosen task. No unblocked roadmap queue package remains; Q-07 and Q-09 require external credentials/authorization.
```

```text
Date: 2026-07-09
Task: T-200 - Notification ordering test expansion.
Files changed: CustomerNotificationsFeatureTests, roadmap, current state, task ledger, and worklog.
Checks: CustomerNotificationsStoreTests RED/GREEN; full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-14/R-014 by making same-timestamp customer notification ordering deterministic in Store tests, replacing the flaky mark-all read assertion with stable display-order expectations, and restoring the full iOS test gate to passing.
Risks: No production Swift code, Supabase schema, migration, remote write, UI behavior, dependency, PR, tag, merge/rebase/reset, or force-push changed. Q-09/APNs dispatch remains externally blocked by missing Apple/APNs credentials.
```

```text
Date: 2026-07-09
Task: T-199 - Private image network resilience.
Files changed: PrivateImageLoader, PrivateImageLoaderTests, roadmap, current state, task ledger, and worklog.
Checks: PrivateImageLoaderTests RED/GREEN; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-13/R-013 by adding one retry for transient private-image downloads, using fresh remote data instead of stale cache after transient refresh failures, and treating cancelled refreshes as cancellation instead of cached success.
Risks: No Supabase schema, migration, storage policy, remote write, repository API, visible UI layout, dependency, PR, tag, merge/rebase/reset, or force-push changed. Full iOS tests still have the known T-153 notification-ordering blocker.
```

```text
Date: 2026-07-09
Task: T-198 - Accessibility and copy audit.
Files changed: DesignTokens, primary action primitives, BookingsStore copy, customer pet model/view accessibility, focused accessibility/copy tests, accessibility checklist, roadmap, current state, task ledger, and worklog.
Checks: Focused BookingsStore/customer pet/design-token accessibility tests; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-12/R-012 by adding contrast-checked semantic color constants, improving primary button text contrast, making booking-vs-schedule load failure copy role-specific, and giving customer pet cards a single readable VoiceOver summary and hint.
Risks: No Supabase schema, migration, remote write, navigation, persistence contract, dependency, PR, tag, merge/rebase/reset, or force-push changed. Runtime VoiceOver pass was limited to code/test/build validation because XcodeBuildMCP UI tools were unavailable in this session.
```

```text
Date: 2026-07-09
Task: T-197 - Local operational crash and funnel evidence.
Files changed: AppOperationalEvent recorder, app composition/root/auth entry instrumentation, debug/privacy docs, roadmap, current state, task ledger, and worklog.
Checks: Focused AppOperationalEventTests; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-11/R-011 by adding sanitized local-only JSONL lifecycle/funnel evidence for launch, foreground/background, auth restored/signed out, role resolved/onboarding, profile-load failure, and suspected prior-run interruption. DEBUG builds mirror these events into Debug Console Recent Events.
Risks: No third-party SDK, network analytics, crash-report upload, Supabase schema, migration, seed, app metadata remote write, repository setting, PR, tag, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-196 - Scheduled documentation meta-review.
Files changed: roadmap, current state, task ledger, worklog, and context hygiene rotation archives.
Checks: `git status --short`; `git diff --check`; `node scripts/context-hygiene-check.mjs`; targeted status/URL grep; context rotation; commit and push.
Result: Runs the required 10-task documentation governance review after T-195, fixes ROADMAP wording that marked completed tasks as waiting due to mixed "blocked" segments, and keeps active memory/ledger windows within policy.
Risks: Documentation-governance only. No Swift behavior, Supabase schema, migration, seed, app metadata remote write, repository setting, PR, tag, merge/rebase/reset, or force-push changed.
```

```text
Date: 2026-07-09
Task: T-195 - Privacy and Support URLs.
Files changed: release privacy/support pages, App Store privacy checklist, AppReleaseLinks, Account legal link UI, privacy tests, roadmap, current state, task ledger, and worklog.
Checks: App Store privacy Node test RED/GREEN; `./scripts/ios-build.sh`; link checks; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-10/R-010 by replacing Privacy Policy and Support URL blockers with public HTTPS GitHub release pages and exposing those links from customer, groomer, and generic Account surfaces through a shared app URL configuration.
Risks: No App Store Connect setting, GitHub repository setting, custom domain, legal entity contact, Supabase schema, migration, seed, or other non-Git remote write changed.
```

```text
Date: 2026-07-09
Task: T-194 - Realtime foreground chat.
Files changed: chat repository protocol, Supabase chat repository, Debug chat wrapper, ChatStore, ChatView, ChatFeatureTests, current state, task ledger, and worklog.
Checks: Supabase changelog/docs review; focused ChatStoreTests; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-08/R-008 by adding foreground message INSERT streaming through the repository boundary, thread subscribe/unsubscribe lifecycle, foreground refresh for the messages list/thread, and debug events for subscription lifecycle/message events.
Risks: No Supabase migration, RLS, replication setting, remote write, attachment, or read-receipt behavior changed. Live two-role smoke was skipped because sending messages would require unauthorized remote writes/test data.
```
