# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-09
Task: T-199 - Private image network resilience.
Files changed: PrivateImageLoader, PrivateImageLoaderTests, roadmap, current state, task ledger, and worklog.
Checks: PrivateImageLoaderTests RED/GREEN; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-13/R-013 by adding one retry for transient private-image downloads, using fresh remote data instead of stale cache after transient refresh failures, and treating cancelled refreshes as cancellation instead of cached success.
Risks: No Supabase schema, migration, storage policy, remote write, repository API, visible UI layout, dependency, PR, tag, merge/rebase/reset, or force-push changed. Full iOS tests still have the known T-153 notification-ordering blocker.
Next: Use T-200 unless resuming T-157 after Apple Developer credentials. Q-09/APNs dispatch remains externally blocked; next unblocked package is Q-14/R-014 Store/model/state/UI test expansion.
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

```text
Date: 2026-07-09
Task: T-193 - Email deep-link and SMTP design.
Files changed: auth email/deep-link design, Supabase contract, decision log, current state, task ledger, and worklog.
Checks: Supabase changelog/docs review; local auth/config grep; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-06/R-007 by defining Resend-backed Supabase custom SMTP, exact HTTPS-first redirect URL policy, dev/test custom scheme fallback, required email templates/secrets, and iOS callback behavior for Q-07.
Risks: No Supabase dashboard setting, Management API write, DNS, iOS entitlement, URL scheme, migration, or remote write changed. Q-07 implementation waits for a production auth domain and SMTP credentials.
```

```text
Date: 2026-07-09
Task: T-192 - Request wizard persistence decision.
Files changed: customer request store/view wizard presentation, customer request tests, decision log, current state, task ledger, and worklog.
Checks: CustomerRequestsStoreTests; XcodeBuildMCP build; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-05/R-006 by deciding request wizard drafts are ephemeral to the active sheet. Back/cancel and swipe dismiss discard unpublished draft fields/photos and reset default create state; publish failures still preserve input and explicit republish remains the only prefilled flow.
Risks: No Supabase schema, policy, migration, remote write, new persistence store, or visible copy change. Full iOS tests still have the known T-153 same-timestamp notification ordering blocker.
```
