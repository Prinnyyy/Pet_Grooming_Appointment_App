# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-09
Task: T-190 - Customer private images.
Files changed: customer request store/view image presentation, customer request tests, private image audit, current state, task ledger, and worklog.
Checks: Customer requests/pets store tests; XcodeBuildMCP build; XcodeBuildMCP launch spot check for auth landing; `git diff --check`; context hygiene; commit and push.
Result: Closes Q-03/R-005 by loading customer pet photo metadata/data into request flows, rendering request wizard pet avatars with `GroomlyModuleImage`, and showing `Photo unavailable` when request-photo metadata exists but image data cannot be read.
Risks: No Supabase schema, policy, migration, or remote write changed. Cross-user avatars in bookings/chat/notifications still need a future data-contract decision.
Next: Use T-191 unless resuming T-157 after Apple Developer credentials. Recommended roadmap package is Q-04/R-005 groomer private images.
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

```text
Date: 2026-07-08
Task: T-186 - Stale workflow 85% wording cleanup and push-failure rule.
Files changed: AGENTS, workflow rules, decision log/archive, current state, task ledger, worklog, and structure log.
Checks: `git diff --check`; `node scripts/context-rotate.mjs --apply`; `node scripts/context-hygiene-check.mjs`; `node scripts/context-rotate.mjs`; commit and push.
Result: Removes active 85% warning/waterline closeout and stop rules, keeps 95% active Markdown as structural-review scheduling only, corrects the T-185 meta-review marker to 2026-07-08, and requires agents to stop without auto pull/rebase/merge/reset/force-push when automatic push fails or is rejected.
Risks: Documentation-only workflow change. No Swift, Supabase, runtime, simulator, PR, tag, merge/rebase/reset, seed, migration, or non-Git remote write changed.
```

```text
Date: 2026-07-09
Task: T-185 - Root external draft cleanup and meta-review.
Files changed: frozen external reports, current state, task ledger, worklog, and structure log.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; `node scripts/context-rotate.mjs`; targeted meta-review `rg`; commit and push.
Result: Preserves the ignored root APP_STATUS_OVERVIEW and V1.0 release-plan v3.1 drafts under `docs/09_frozen/external_agent_reports/`, removes root copies, and records the scheduled meta-review. Targeted review found stale 85% wording in active workflow docs that needs a standalone T-186 rule cleanup.
Risks: Documentation/archive cleanup only. No Swift, Supabase, runtime, simulator, PR, tag, merge/rebase/reset, seed, migration, or non-Git remote write changed.
```

```text
Date: 2026-07-09
Task: T-184 - Context budget workflow alignment.
Files changed: AGENTS.md, context/recovery workflow rules, decision log/archive, frozen external plan, current state, task ledger, and worklog.
Checks: `node scripts/context-rotate.mjs --apply`; `node scripts/context-hygiene-check.mjs`; `git diff --check`; commit and push.
Result: Implements Batch B of the context-budget redesign. Active workflow rules now use `context-rotate` for rolling-window overflow, define FIXED/WINDOW/INDEX write discipline, treat 95% active Markdown as structural-review signal, and archive the adopted root redesign plan.
Risks: Documentation-only workflow change. No Swift, Supabase, runtime, simulator, PR, tag, merge/rebase/reset, seed, migration, or non-Git remote write changed.
```

```text
Date: 2026-07-09
Task: T-183 - Context budget redesign tooling.
Files changed: context hygiene policy/check scripts, context rotate script, docs tests, decision log/archive, current state, task ledger, and worklog.
Checks: `node --test tests/docs/`; `node scripts/context-rotate.mjs`; `node scripts/context-rotate.mjs --apply`; `node scripts/context-hygiene-check.mjs`; `CONTEXT_HYGIENE_FORCE_NO_RG=1 node scripts/context-hygiene-check.mjs`; `git diff --check`; commit and push.
Result: Implements Batch A of the context-budget redesign: 36k hard total, no 85% warning, 95% structural-review warning, 650-word default active Markdown budget, full budget coverage output, decision-log 8-entry window, shared constants, and deterministic archive rotation.
Risks: Docs/tooling-only change. Workflow text alignment and root plan archival are intentionally deferred to T-184 Batch B. No Swift, Supabase, runtime, simulator, PR, tag, merge/rebase/reset, seed, migration, or non-Git remote write changed.
```
