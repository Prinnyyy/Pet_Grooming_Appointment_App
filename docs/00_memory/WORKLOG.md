# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Older `Next:` lines and branch references are historical closeout notes, not current instructions.

```text
Date: 2026-07-07
Task: T-158 - Public RPC wrapper hardening.
Files changed: `20260707174825_t158_public_rpc_wrapper_hardening.sql`, migration tests, RLS/RPC policy, memory docs.
Checks: RED/GREEN `node --test tests/migrations/public-rpc-wrapper-hardening.test.mjs`; `node --test tests/migrations/*.test.mjs`; `node --test tests/functions/customer-push-dispatcher.test.mjs`; authorized `supabase db push --linked`; post-apply `supabase db push --linked --dry-run`; public/private RPC metadata SQL; rollback authenticated wrapper execution SQL; `supabase db advisors --linked --type all --level warn --fail-on none`; `supabase db lint --linked --fail-on none`; `git diff --check`; `node scripts/context-hygiene-check.mjs`; `./scripts/ios-build.sh`.
Remote: Applied `20260707174825_t158_public_rpc_wrapper_hardening.sql` to `lqmasbuqzvcvtawonjlb`.
Result: Ten public authenticated RPCs that advisors flagged as `SECURITY DEFINER` are now public `SECURITY INVOKER` wrappers calling private `app_private` helpers with the original privileged function bodies. Public API names/signatures remain stable.
Risks: Advisors now only report Auth leaked-password protection. `db lint` still reports two pre-existing unread variables in private helper bodies. T-157 Edge Function deployment remains blocked until APNs secrets exist.
Next: Commit/push the T-157/T-158 changes, then continue T-157 APNs secret setup and function deploy when the secret values are available.
```

```text
Date: 2026-07-07
Task: T-157 - Customer APNs push notification foundation remote apply checkpoint.
Files changed: T-157 corrective migrations for push token validation/conflict/constraint handling, migration tests, memory docs.
Checks: Authorized sequential `supabase db push --linked`; post-apply `supabase db push --linked --dry-run`; metadata/RLS/index/constraint SQL; public RPC grant/security metadata SQL; trigger SQL; rollback claim/record validation; rollback authenticated register/unregister validation; `node --test tests/migrations/*.test.mjs`; `node --test tests/functions/customer-push-dispatcher.test.mjs`; `supabase db lint --linked --fail-on none`; `supabase db advisors --linked --type all --level warn --fail-on none`; `supabase secrets list --output-format json`; `git diff --check`; `node scripts/context-hygiene-check.mjs`; `./scripts/ios-build.sh`.
Remote: Applied `20260706230112_t157_customer_push_notifications.sql` plus corrective migrations through `20260707172322_t157_fix_push_token_constraint.sql` to `lqmasbuqzvcvtawonjlb`. `supabase secrets list` returned no APNs secrets, so the Edge Function was not deployed.
Result: The remote database now has customer APNs token registration, push delivery state, service-role dispatch RPCs, new-offer/new-message notification events, and corrected token validation for real APNs tokens.
Risks: Production push dispatch is still inactive until `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC`, and `APNS_PRIVATE_KEY` are configured and `supabase functions deploy dispatch-customer-push-notifications` is run. Advisors still report pre-existing public authenticated SECURITY DEFINER RPC warnings and Auth leaked-password protection.
Next: Configure or confirm APNs secrets, then deploy `dispatch-customer-push-notifications`; do not start a new task unless the user explicitly redirects.
```

```text
Date: 2026-07-06
Task: T-157 - Customer APNs push notification foundation.
Files changed: `20260706230112_t157_customer_push_notifications.sql`, `supabase/functions/dispatch-customer-push-notifications/`, customer push notification model/repository/store/coordinator/AppDelegate wiring, notification kind extension, migration/function/Swift tests, memory docs.
Checks: RED/GREEN `node --test tests/migrations/customer-push-notifications.test.mjs`; RED/GREEN `node --test tests/functions/customer-push-dispatcher.test.mjs`; RED/GREEN targeted `CustomerPushNotificationRegistrationStoreTests`; `node --test tests/migrations/*.test.mjs`; dispatcher tests; sequential `supabase migration list --linked`; sequential `supabase db push --linked --dry-run`.
Remote: No remote writes. Dry-run shows only `20260706230112_t157_customer_push_notifications.sql` pending after T-156. APNs secrets were not set, the Edge Function was not deployed, and post-apply SQL/advisors were not run.
Result: Local T-157 implementation is ready for authorization. It adds customer APNs token registration, push delivery state on durable customer notifications, controlled service-role dispatch RPCs, new `new_offer`/`new_message` notification events, and an Edge Function that sends APNs from system notification copy only.
Risks: The local app can request APNs permission after a Customer session loads, but remote token RPCs do not exist until the migration is applied. Production push also requires APNs secrets (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC`, `APNS_PRIVATE_KEY`) and `supabase functions deploy dispatch-customer-push-notifications`.
Next: Get explicit authorization for remote T-157 DDL/deploy steps, or pause before remote writes.
```

```text
Date: 2026-07-06
Task: T-156 - Booking handoff read-state persistence.
Files changed: `20260706220736_t156_booking_handoff_read_state.sql`, Customer request repository/store/view wiring, migration and Store tests, memory docs.
Checks: RED/GREEN `node --test tests/migrations/booking-handoff-read-state.test.mjs`; RED/GREEN targeted `CustomerRequestsStoreTests`; `node --test tests/migrations/*.test.mjs`; `supabase migration list --linked`; sequential dry-run; authorized `supabase db push --linked`; post-apply metadata/RLS/RPC/grant SQL; rollback RLS/RPC validation; zero-residue SQL; sequential lint/advisors; `git diff --check`; `./scripts/ios-build.sh`.
Remote: After explicit user authorization, `supabase db push --linked` applied `20260706220736_t156_booking_handoff_read_state.sql`; post-apply migration list and dry-run aligned, metadata/RLS/RPC/grant SQL passed, rollback-contained RLS/RPC validation passed, and zero-residue SQL returned 0.
Result: T-156 is complete. Booking handoff acknowledgements now use durable customer-owned backend state through repository/store boundaries while preserving local offline fallback.
Risks: Existing advisors remain pre-existing SECURITY DEFINER/Auth warnings. T-156 RPCs are security invoker and were not newly flagged.
Next: Use T-157 unless the user names another task.
```

```text
Date: 2026-07-06
Task: T-155 - Backfill matching after groomer activation/availability changes.
Files changed: `20260706213507_t155_backfill_matching.sql`, `tests/migrations/backfill-matching.test.mjs`, memory docs.
Checks: RED/GREEN `node --test tests/migrations/backfill-matching.test.mjs`; `node --test tests/migrations/*.test.mjs`; authorized `supabase db push --linked`; post-apply migration list/dry-run, function privilege SQL, trigger SQL, RPC-definition SQL, rollback backfill SQL, residue SQL; remote `matching_baseline` TestOps 8/8 with cleanup and zero residue; lint/advisors; `git diff --check`; `./scripts/ios-build.sh`; `ios-test` earlier failed one unrelated T-153 notification-order assertion.
Result: T-155 applied `20260706213507_t155_backfill_matching.sql` to `lqmasbuqzvcvtawonjlb`. It extracts reusable private request-match insertion, makes `public.create_grooming_request` reuse it, and backfills missing matches after groomer activation plus availability window, booking preference, and time-off changes. Private backfill functions grant execute only to `service_role`; trigger functions are not externally executable.
Risks: Rollback SQL verified activation, availability, preference, time-off, duplicate, inactive, and expired paths with zero tagged residue. Existing advisors remain public authenticated SECURITY DEFINER RPC warnings and Auth leaked-password protection. The unrelated T-153 same-timestamp notification-order test failure remains outside T-155 scope.
Next: Use T-156 unless the user names another task ID.
```

```text
Date: 2026-07-06
Task: T-154 - Request expiry conversion.
Files changed: `20260706211524_t154_request_expiry_conversion.sql`, migration tests, memory docs.
Checks: RED/GREEN `node --test tests/migrations/request-expiry.test.mjs`; `node --test tests/migrations/*.test.mjs`; pre-apply `supabase migration list --linked` and `supabase db push --linked --dry-run`; authorized `supabase db push --linked`; post-apply migration list/dry-run; function metadata/execute-privilege SQL; cron/pg_cron SQL; rollback-contained expiry conversion SQL; residue/stale-request SQL; `supabase db lint --linked --fail-on none`; `supabase db advisors --linked --type all --level warn --fail-on none`; `git diff --check`; `./scripts/ios-build.sh`; `./scripts/ios-test.sh`.
Result: T-154 applied `20260706211524_t154_request_expiry_conversion.sql` to project `lqmasbuqzvcvtawonjlb`. It adds private `app_private.expire_grooming_requests(integer)` batch processing, moves stale `open`/`has_offers` requests to `expired`, expires linked pending offers and active/offered matches, grants execute only to `service_role`, installs `pg_cron`, and schedules `groomly_expire_grooming_requests` every 5 minutes. Existing Swift expired-state filtering/presentation was validated through the full iOS test entrypoint.
Risks: Rollback SQL verified conversion behavior with zero residue, and there are currently zero stale open/has-offers requests. Advisors did not flag the private T-154 function. Baseline advisors still report pre-existing authenticated SECURITY DEFINER RPC warnings and Auth leaked-password protection.
Next: Use T-155 unless the user names another task ID.
```

```text
Date: 2026-07-06
Task: T-153 - Customer in-app notification center.
Files changed: `customer_notifications` migration, customer notification model/repository/store/view, Customer Home bell navigation, debug repository wrapper, Swift/SQL tests, screen/feature/memory docs.
Checks: RED SQL migration test and RED Swift store compile test; `node --test tests/migrations/customer-notifications.test.mjs`; `supabase migration list --linked`; `supabase db push --linked --dry-run`; authorized `supabase db push --linked`; post-apply migration list/dry-run; rollback SQL metadata/RLS/RPC/event-trigger checks; security/performance advisors; XcodeBuildMCP Customer Home bell/list目检; `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Customer Home bell now routes to a Customer notification list backed by repository/store boundaries, with timestamped read/unread system notifications and mark-read actions. The local migration creates the notification table, RLS policies, mark-read RPCs, and first event triggers for request published/cancelled and booking confirmed/cancelled.
Risks: `20260706203710_t153_customer_notifications.sql` is applied to authorized project `lqmasbuqzvcvtawonjlb`. Security advisor still reports pre-existing public authenticated `SECURITY DEFINER` RPC warnings and Auth leaked-password protection; T-153 mark-read RPCs are security invoker and were not flagged. APNs push remains deferred.
Next: Use T-154 unless the user names another task ID.
```

```text
Date: 2026-07-06
Task: T-152 - Groomer Offers tab.
Files changed: Groomer tab routing, `GroomerOffersView`, `GroomerOffersStore`, groomer offer list models/repository adapter, tests, `SCREEN_INVENTORY`, memory docs.
Checks: RED compile failure for missing offers list surface; `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; XcodeBuildMCP iPhone 17 Offers-tab目检; `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Groomers now have a visible Offers tab showing submitted offers grouped by status with readable request or booking context when available.
Risks: No Supabase schema/RLS/RPC/Storage, migrations, dependencies, seed data, remote writes, commits, or pushes changed. Offer creation and withdrawal remain in Board/request detail.
Next: Use T-153 unless the user names another task ID.
```

```text
Date: 2026-07-06
Task: T-151 - Active Markdown baseline recheck and AGENTS hardening.
Files changed: AGENTS.md, memory docs, ledger/worklog rolling archives, project-structure log.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; active stale-reference searches.
Result: Active docs use the T-151/T-152 baseline and AGENTS now rejects external reports as authoritative sources.
Risks: Docs-only. No iOS, Supabase, runtime, seed, simulator, commit, or push change.
Next: Use T-152 unless the user names another task ID.
```

```text
Date: 2026-07-06
Task: T-150 - Restore correct task baseline and archive external audit drafts.
Files changed: moved root reports to frozen; updated ignore/search and memory/ledger/archive indexes.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Active baseline is `codex/pet-fit-structure-cleanup`; T-151 is next.
Risks: Docs-only. `main` remote reconciliation needs explicit approval.
Next: Use T-151 unless the user names another task ID.
```

```text
Date: 2026-07-02
Task: T-149 - Active design document slimming.
Files changed: docs/01_product/DESIGN_SYSTEM.md, docs/08_design/UI_IMPLEMENTATION_NOTES.md, docs/09_frozen/design_notes/, scripts/context-hygiene-check.mjs, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs indexes, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: `git diff --check` passed. `node scripts/context-hygiene-check.mjs` passed with `DESIGN_SYSTEM.md` and `UI_IMPLEMENTATION_NOTES.md` under the new 900-word budgets. Archive/reference checks confirmed the full pre-slim design texts exist under `docs/09_frozen/design_notes/`.
Simulator launch: Skipped because this was docs/design-context cleanup only and did not affect iOS app/UI behavior.
Result: Active design docs now keep only current design-system rules, Groomly visual summary, screenshot rework boundaries, and source routing. Full historical T-023 through T-035 design-system narrative and prototype audit details are preserved in frozen design-note archives.
Risks: No Swift source, Supabase schema/RLS/RPC/Storage, migrations, seed data, dependencies, simulator, or remote state changed.
Next: Use T-150 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-148 - Pointer/template cleanup and Claude path correction.
Files changed: docs/00_memory/DECISION_LOG.md, docs/05_workflow/LIGHTWEIGHT_FINAL_REPORT_TEMPLATE.md, docs/06_tasks/LIGHTWEIGHT_TASK_PROMPT_TEMPLATE.md, docs/06_tasks/TASK_INTAKE_TEMPLATE.md, docs/09_frozen/memory_pointers/, docs/09_frozen/workflow_templates/, docs/09_frozen/task_templates/, CLAUDE.md, CLAUDE_reference/, docs indexes, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: `git diff --check` passed. `node scripts/context-hygiene-check.mjs` passed. Active stale-reference search found no deleted active paths outside historical worklog/reorganization audit text.
Simulator launch: Skipped because this was docs/archive cleanup only and did not affect iOS app/UI behavior.
Result: The memory decision-log compatibility pointer and low-use lightweight workflow/task templates were archived under `docs/09_frozen/` and removed from active docs. Claude files remain active, with stale Fresh Brief and Groomly prompt references corrected to current product/design/workflow entrypoints.
Risks: No iOS source, Supabase schema/RLS/RPC/Storage, migrations, seed data, dependencies, simulator, or remote state changed.
Next: Use T-149 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-147 - Active historical pointer and root brief cleanup.
Files changed: Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md, docs/09_frozen/product_briefs/FRESH_PET_GROOMER_MARKETPLACE_ENGINEERING_BRIEF_2026-07-02.md, docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md, README.md, PRODUCT_BRIEF.md, UI_IMPLEMENTATION_NOTES.md, DECISION_LOG.md, project-structure indexes, frozen archive index, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: `git diff --check` passed. `node scripts/context-hygiene-check.mjs` passed. Active reference search confirmed the deleted active files are no longer used outside the reorganization-log move record and frozen archive pointers.
Simulator launch: Skipped because this was docs/archive cleanup only and did not affect iOS app/UI behavior.
Result: The original root product/engineering brief is now frozen under `docs/09_frozen/product_briefs/` and removed from the repository root. The active Groomly design prompt pointer was deleted because the full prompt is already frozen. Active product/design work now routes through `docs/01_product/PRODUCT_BRIEF.md` and `docs/08_design/UI_IMPLEMENTATION_NOTES.md`.
Risks: No iOS source, Supabase schema/RLS/RPC/Storage, migrations, seed data, dependencies, simulator, or remote state changed.
Next: Use T-148 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-146 - AI collaboration context indexing and policy trim.
Files changed: AGENTS.md, workflow/context/stop docs, docs indexes, FEATURE_INDEX.md, backend policy docs, TestOps memory, Groomly design prompt pointer, frozen archives, context hygiene script, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: `git diff --check` passed. `node scripts/context-hygiene-check.mjs` passed word budgets, active Markdown link scan, default hidden-path checks, and stale TestOps credential wording checks. Targeted searches confirmed frozen archives remain default-hidden and TestOps credential docs match script behavior.
Simulator launch: Skipped because this was docs/workflow/search-hygiene only and did not affect iOS app/UI behavior.
Result: Active AI collaboration docs now use an explicit L0-L4 access model, stronger context stop conditions, compact single-purpose policy/index files, frozen pre-trim archives for historical trace, and one read-only context hygiene command for future closeouts.
Risks: No iOS source, Supabase schema/RLS/RPC/Storage, migrations, seed data, dependencies, simulator, or remote state changed. Historical details remain in frozen archives and should be read only with targeted recovery/comparison reasons.
Next: Use T-147 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```
