# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-07
Task: T-166 - Git/GitHub rules hardening.
Files changed: GITHUB_RULES.md, TOOLING_POLICY.md, root/docs README indexes, decision log, active ledger, frozen ledger archive, current state, and reorganization log.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Git rules now require `T-xxx: <type>: <summary>` commit messages, same-task commit scope, approved checkpoint commits, explicit push/PR/tag gates, branch cleanup rules, and a dedicated `main` reconciliation task for the known 2fddf7b governance divergence.
Risks: Docs/workflow only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
Next: Use T-167 unless the user resumes T-157 after Apple Developer Program upgrade.
```

```text
Date: 2026-07-07
Task: T-165 - Context hygiene v2 truth checks.
Files changed: context hygiene script/tests, CONTEXT_AND_RECOVERY.md, frozen worklog archive, memory docs.
Checks: RED/GREEN `node --test tests/docs/context-hygiene-check.test.mjs`; `node scripts/context-hygiene-check.mjs`; `git diff --check`.
Result: Hygiene now detects branch/latest/next task drift, rolling-window overflow, active Markdown total budget, expanded file budgets, and missing `rg` without TypeError.
Risks: Docs/workflow tooling only. No iOS source, Supabase command, migration, runtime behavior, simulator, commit, or push changed.
```

```text
Date: 2026-07-07
Task: T-164 - Backend contract catch-up.
Files changed: SUPABASE_CONTRACT.md, RLS_RPC_POLICY.md, memory docs.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; targeted migration-object reference search.
Result: Active backend contract indexes now cover T-153 through T-160 customer notification, handoff, APNs foundation, account deletion, automation, Edge Function, and controlled/service-role RPC facts.
Risks: Docs-only. No Supabase remote command, migration, iOS source, runtime behavior, simulator, commit, or push changed.
```

```text
Date: 2026-07-07
Task: T-163 - Docs governance truth cleanup.
Files changed: README/Claude/product/design/workflow docs, feature index, decision log, frozen external report/current-state/ledger archives, memory docs.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; targeted stale-notification wording searches.
Result: Root governance plan is archived as review input, notification/APNs scope is recorded as current fact, stale active-task wording is removed, Offers routing points at the T-152 code area, and active current-state/ledger files stay under budget.
Risks: Docs-only. No iOS source, Supabase schema/RLS/RPC/Storage, migrations, remote writes, simulator, commit, or push changed.
```

```text
Date: 2026-07-07
Task: T-162 - Cancelled request/booking repost flow.
Files changed: Customer request Store/View, BookingsView, CustomerTabView, Customer request feature tests, memory docs, and frozen worklog archive for T-150 through T-154.
Checks: RED/GREEN targeted `CustomerRequestsStoreTests`; `git diff --check`; `./scripts/ios-build.sh`; `node scripts/context-hygiene-check.mjs`.
Result: Customers can start a new request from a cancelled request or cancelled booking. The existing five-step wizard opens at Review with original request details prefilled, cached request photos copied into the new draft upload path, and publish still creating a fresh request id.
Risks: No Supabase schema/RLS/RPC change. Cancelled booking repost requires the matching original request to load; otherwise the Store reports a recoverable refresh error. Full `ios-test` remains blocked by the known T-153 notification ordering test.
```

```text
Date: 2026-07-07
Task: T-161 - App Store privacy baseline.
Files changed: iOS `PrivacyInfo.xcprivacy`, App Store privacy checklist, manifest tests, memory docs, and frozen worklog archive for T-146 through T-149.
Checks: RED/GREEN `node --test tests/ios/app-store-privacy.test.mjs`; `plutil -lint` for the privacy manifest; `./scripts/ios-build.sh`; built-app manifest presence check; `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Adds the Groomly 1.0 privacy manifest with no tracking, app-functionality data declarations, `UserDefaults` reason `CA92.1`, and file timestamp reason `C617.1`. Documents App Store Connect nutrition-label posture plus blocking Privacy Policy URL and Support URL placeholders.
Risks: Real production Privacy Policy URL and Support URL remain TBD and must be provided before App Store metadata submission. Full `ios-test` remains blocked by the known T-153 notification ordering test.
```

```text
Date: 2026-07-07
Task: T-160 - Account deletion flow.
Files changed: `20260707191034_t160_account_deletion.sql`, `supabase/functions/delete-account/`, Auth session repository/store/UI, local profile/pet-photo cache cleanup, Node/Swift tests, memory docs.
Checks: RED/GREEN Node migration/function tests; pre-apply dry-run/lint; authorized remote `supabase db push --linked`; post-apply migration list, metadata SQL, advisors; `supabase functions deploy delete-account`; `supabase functions list`; `git diff --check`; `./scripts/ios-build.sh`; targeted `AuthenticationStoreTests`. Full `./scripts/ios-test.sh` still fails the known T-153 notification ordering test.
Remote: Applied `20260707191034_t160_account_deletion.sql` to `lqmasbuqzvcvtawonjlb` and deployed `delete-account` with JWT verification enabled. Post-apply `supabase db push --linked --dry-run` and `supabase db lint --linked` could not rerun because `SUPABASE_DB_PASSWORD` is not configured for direct Postgres CLI connections.
Result: Completed. Adds account deletion audit/anonymization RPCs, service-role completion/failure RPCs, user-auth Edge Function that soft-deletes the Auth user with `deleteUser(user_id, true)`, Account double-confirm delete UI, and local snapshot cleanup after successful deletion.
Risks: Advisors still report baseline `customer_push_tokens` RLS-enabled/no-policy INFO, Auth leaked-password protection WARN, existing performance INFOs, and a new expected unused-index INFO for `account_deletion_requests_user_status_idx` because the index has just been created.
```

```text
Date: 2026-07-07
Task: T-159 - Private RPC lint cleanup.
Files changed: `20260707183427_t159_private_rpc_lint_cleanup.sql`, `tests/migrations/private-rpc-lint-cleanup.test.mjs`, memory docs.
Checks: RED/GREEN `node --test tests/migrations/private-rpc-lint-cleanup.test.mjs`; `node --test tests/migrations/*.test.mjs`; pre-apply migration list/dry-run; authorized `supabase db push --linked`; post-apply migration list/dry-run; RPC metadata SQL; `supabase db lint --linked --fail-on none`; `supabase db advisors --linked --type all --level warn --fail-on none`; `git diff --check`; context hygiene.
Remote: Applied `20260707183427_t159_private_rpc_lint_cleanup.sql` to `lqmasbuqzvcvtawonjlb`.
Result: `app_private.accept_groomer_offer(uuid)` and `app_private.complete_booking(uuid)` no longer contain the unread PL/pgSQL variables previously reported by `supabase db lint`; lint now reports no schema errors.
Risks: Advisors still report only Auth leaked-password protection. T-157 APNs Edge Function deployment remains blocked by missing paid Apple Developer Program APNs credentials.
```

```text
Date: 2026-07-07
Task: T-157 - APNs credential availability note.
Files changed: memory docs only.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Remote: No remote writes.
Result: Recorded that the user currently has a free Apple Developer account, so APNs Auth Key / Push Notifications capability is not available yet. T-157 Edge Function deployment remains blocked until Apple Developer Program upgrade provides APNs Key ID, Team ID, topic confirmation, and `.p8` private key.
Risks: In-app notifications and the T-157 database/iOS foundation remain usable; actual remote APNs delivery is deferred.
```

```text
Date: 2026-07-07
Task: T-158 - Public RPC wrapper hardening.
Files changed: `20260707174825_t158_public_rpc_wrapper_hardening.sql`, migration tests, RLS/RPC policy, memory docs.
Checks: RED/GREEN `node --test tests/migrations/public-rpc-wrapper-hardening.test.mjs`; `node --test tests/migrations/*.test.mjs`; `node --test tests/functions/customer-push-dispatcher.test.mjs`; authorized `supabase db push --linked`; post-apply `supabase db push --linked --dry-run`; public/private RPC metadata SQL; rollback authenticated wrapper execution SQL; `supabase db advisors --linked --type all --level warn --fail-on none`; `supabase db lint --linked --fail-on none`; `git diff --check`; `node scripts/context-hygiene-check.mjs`; `./scripts/ios-build.sh`.
Remote: Applied `20260707174825_t158_public_rpc_wrapper_hardening.sql` to `lqmasbuqzvcvtawonjlb`.
Result: Ten public authenticated RPCs that advisors flagged as `SECURITY DEFINER` are now public `SECURITY INVOKER` wrappers calling private `app_private` helpers with the original privileged function bodies. Public API names/signatures remain stable.
Risks: Advisors now only report Auth leaked-password protection. `db lint` still reports two pre-existing unread variables in private helper bodies. T-157 Edge Function deployment remains blocked until APNs secrets exist.
```
