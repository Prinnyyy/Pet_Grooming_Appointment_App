# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-09
Task: T-194 - Realtime foreground chat.
Files changed: chat repository protocol, Supabase chat repository, Debug chat wrapper, ChatStore, ChatView, ChatFeatureTests, current state, task ledger, and worklog.
Checks: Supabase changelog/docs review; focused ChatStoreTests; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-08/R-008 by adding foreground message INSERT streaming through the repository boundary, thread subscribe/unsubscribe lifecycle, foreground refresh for the messages list/thread, and debug events for subscription lifecycle/message events.
Risks: No Supabase migration, RLS, replication setting, remote write, attachment, or read-receipt behavior changed. Live two-role smoke was skipped because sending messages would require unauthorized remote writes/test data.
Next: Use T-195 unless resuming T-157 after Apple Developer credentials. Q-09/APNs dispatch remains externally blocked; next unblocked package is Q-10/R-010 Privacy and Support URLs.
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

```text
Date: 2026-07-09
Task: T-191 - Groomer private images.
Files changed: groomer profile store/view portfolio presentation, groomer profile tests, private image audit, current state, task ledger, and worklog.
Checks: GroomerProfileStoreTests; XcodeBuildMCP build; XcodeBuildMCP launch spot check for auth landing; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-04/R-005 by tracking groomer portfolio image-load attempts, rendering portfolio photos through the shared module image path, and showing distinct loading versus unavailable states when private image data cannot be read.
Risks: No Supabase schema, policy, migration, or remote write changed. Cross-user avatars in bookings/chat/notifications still need a future data-contract decision.
```

```text
Date: 2026-07-09
Task: T-190 - Customer private images.
Files changed: customer request store/view image presentation, customer request tests, private image audit, current state, task ledger, and worklog.
Checks: Customer requests/pets store tests; XcodeBuildMCP build; XcodeBuildMCP launch spot check for auth landing; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-03/R-005 by loading customer pet photo metadata/data into request flows, rendering request wizard pet avatars with `GroomlyModuleImage`, and showing `Photo unavailable` when request-photo metadata exists but image data cannot be read.
Risks: No Supabase schema, policy, migration, or remote write changed. Cross-user avatars in bookings/chat/notifications still need a future data-contract decision.
```

```text
Date: 2026-07-09
Task: T-189 - Shared private image renderer.
Files changed: private image loader/cache, Supabase private image data source, customer/groomer image repositories, private image audit, current state, task ledger, and worklog.
Checks: Focused `PrivateImageCacheKeyTests`/`PrivateImageLoaderTests`; iOS build; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-02/R-005 by adding a shared authenticated private-image loader with hashed file cache, replacing direct repository Storage downloads, preserving legacy groomer avatar fallback, and clearing the shared private image cache during local account cleanup.
Risks: No Supabase schema, policy, migration, or remote write changed. UI surfaces still need Q-03/Q-04 follow-up work for customer/groomer presentation polish and broader cache adoption.
```

```text
Date: 2026-07-09
Task: T-188 - Private image contract audit.
Files changed: private image audit, Storage policy, roadmap execution queue, current state, task ledger, and worklog.
Checks: Supabase read-only bucket/RLS queries; Storage code/UI grep; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-01/R-005 by confirming the deployed private bucket/RLS contract, authenticated Storage download usage, current rendered image surfaces, local cache coverage, and gaps for the shared image renderer.
Risks: Audit/docs-only change. No Swift behavior, schema, migration, simulator, PR, tag, merge/rebase/reset, seed, or non-Git remote write changed.
```

```text
Date: 2026-07-09
Task: T-187 - Roadmap execution queue.
Files changed: ROADMAP, roadmap execution queue, task directory guide, decision log, current state, task ledger, and worklog.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; commit and push.
Result: Adds `docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md` as the bounded planning layer between ROADMAP candidates and task-ledger execution. The queue defines Q-01 through Q-15 from R-005 through R-015 without assigning future T IDs in ROADMAP.
Risks: Documentation/planning-only change. No Swift, Supabase, runtime, simulator, PR, tag, merge/rebase/reset, seed, migration, or non-Git remote write changed.
```
