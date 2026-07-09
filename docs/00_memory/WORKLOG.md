# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.

```text
Date: 2026-07-09
Task: T-235 - Remote TestOps lifecycle and matching evidence.
Files changed: TestOps doctor/result/artifact redaction, three unit suites, durable remote run record/results index/TestOps memory, roadmap/queue/current state/task ledger/worklog.
Checks: Doctor/dry-runs; redaction RED/GREEN; `./scripts/testops-unit.sh` 28/28; authorized remote smoke5 5/5; authorized matching baseline 8/8; 10 lifecycle and 16 matching artifact scans with zero unsafe files; linked tagged-residue queries returned zero; `git diff --check`; context hygiene.
Result: Q-37 proves five full backend marketplace lifecycles and eight matching cases against the linked project with scoped cleanup. Console and artifact entity IDs are now 8-character refs, and doctor correctly recognizes modern server credentials.
Risks: The first smoke run passed/cleaned up but revealed full UUIDs in console/JSON. Execution stopped, unsafe generated artifacts were deleted, regression coverage was added, and clean R2 runs replaced the evidence. No raw artifact is committed.
Next: Use T-236 for Q-39 booking and notification pagination.
```

```text
Date: 2026-07-09
Task: T-234 - Evidence-backed foreign-key indexes.
Files changed: two-index migration, rollback-only forced-plan SQL, migration regression test, index evidence audit, Supabase contract, roadmap/queue/current state/task ledger/worklog.
Checks: Focused RED/GREEN; 47 migration and 10 Edge tests; `./scripts/preflight.sh`; `./scripts/supabase-check.sh`; linked list/dry-run/apply/parity; catalog definitions; before/after forced plans; performance advisor; `git diff --check`; context hygiene.
Result: Q-36 adds only `customer_booking_handoff_acknowledgements(booking_id)` and `request_photos(customer_id)`. Both high-cost forced sequential scans changed to index-backed plans, and the two target unindexed-FK findings cleared.
Risks: Both new indexes immediately appear as unused because linked traffic is minimal; this is expected and does not authorize removal. The remaining 10 FK findings retain the T-228 disposition.
```

```text
Date: 2026-07-09
Task: T-233 - Account deletion Storage API correction.
Files changed: account-deletion Edge Function and tests; append-only SQL migration and static test; rollback-only runtime SQL; Storage/backend/feature docs; current state, roadmap, task ledger, and worklog.
Checks: Official Storage list/delete docs; Edge and migration RED/GREEN; recursive/paged/1000-object batch cases; exact T-232/T-233 function comparison; 45 migration and 10 Edge tests; `./scripts/preflight.sh`; `./scripts/supabase-check.sh`; linked dry-run/apply/parity; rollback-only runtime and zero-residue query; linked lint; security/performance advisors; Edge version 2 active with JWT verification; full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene.
Result: Account deletion no longer mutates `storage.objects` from SQL. After transactional anonymization, the Edge Function recursively lists the user's UUID prefix in six current/legacy buckets, removes objects in batches of at most 1000, and only then soft-deletes Auth. Storage failure is recorded and blocks Auth deletion.
Risks: The production function deployment is verified by version/status and unit-boundary coverage; no live end-user account was destructively deleted. Advisor output remains limited to known APNs/Auth-plan and Q-36 index findings.
```

```text
Date: 2026-07-09
Task: T-232 - Account deletion conflict-target correction.
Files changed: append-only account-deletion function migration, static regression test, current state, task ledger, and worklog.
Checks: Remote constraint/function evidence; focused RED/GREEN; 45 migration and 10 Edge tests; `./scripts/preflight.sh`; linked list/dry-run/apply/parity; post-apply function source; linked database lint; `git diff --check`; context hygiene.
Result: The account-deletion upsert now targets `account_deletion_requests_user_key` by constraint name, removing the PL/pgSQL output-column ambiguity. Remote lint reports no schema errors.
Risks: A rollback-only function execution exposed an independent 42501 failure from direct `storage.objects` deletion. No test residue remained; T-233 owns the Storage API correction and Edge deployment.
```

```text
Date: 2026-07-09
Task: T-231 - Groomer in-app notification remote parity.
Files changed: notification negative-contract rollback SQL and static test; roadmap, queue, current state, task ledger, and worklog. Existing T-203 migration was applied remotely.
Checks: Current Supabase docs/changelog; migration/Edge preflight; 8/8 rollback-only negative checks; linked migration parity/dry-run; catalog, grants, RLS, RPC, trigger, and residue queries; linked lint; security/performance advisors; full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene.
Result: Q-35 is complete. Groomer in-app notifications now have remote table/RLS/RPC/trigger parity and the existing iOS list/read behavior is backed by the live schema. The rollback validator was corrected to use PL/pgSQL row counts and authenticated temp-result privileges.
Risks: APNs, groomer push tokens, push dispatch, and paid Apple work remain excluded. Advisor output contains only known APNs/Auth-plan and Q-36 index findings. Runtime lint exposed a separate account-deletion conflict ambiguity, assigned next as T-232.
```

```text
Date: 2026-07-09
Task: T-230 - Request and offer visible pagination.
Files changed: shared pagination model/action primitive; customer request/offer Stores, views, and tests; groomer request/offer Stores, views, and tests; pagination audit; roadmap/queue/current state/task ledger/worklog.
Checks: Four Store pagination RED/GREEN cases; focused customer/groomer request and groomer offer suites; full `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; XcodeBuildMCP build/run plus customer Requests navigation/screenshot; `git diff --check`; context hygiene.
Result: Q-38 adds one shared explicit Load More interaction to customer requests, customer request offers, groomer matched requests, and groomer offers. All four preserve loaded rows and next-page state across failure, retry the same page, deduplicate stable IDs, and stop at the terminal page.
Risks: No schema, migration, Supabase write, TestOps execute, seed, deploy, APNs, release upload, PR, merge/rebase/reset, or force-push. The live customer account had fewer than 50 rows, so conditional button visibility is covered by Store tests while Simulator verification covered the surrounding production screen.
```

```text
Date: 2026-07-09
Task: T-229 - Periodic meta-review.
Files changed: current state, feature index, task ledger, worklog, and frozen rotations.
Checks: Git status/diff; context hygiene; 56-file migration mirror count; root-report tracking/ignore/frozen checks; targeted branch/task/queue fact scan.
Result: Resolves the 10-task cadence gate. All 69 active Markdown files remain within individual budgets; root external reports are ignored/untracked with frozen copies; migration and roadmap facts align. The 95% total is observed, but no duplicate active source is safe to remove.
Risks: Governance closeout only. No workflow rule, app/backend behavior, Supabase write, migration, TestOps execute, seed, deploy, release action, or APNs work changed.
```

```text
Date: 2026-07-09
Task: T-228 - Supabase advisor index evidence audit.
Files changed: index audit, Supabase contract, roadmap/queue, current state, task ledger, and worklog.
Checks: Current Supabase docs/changelog and CLI help; linked performance advisor; sequential read-only catalog/index/table/pg_stat queries; transaction-local safe EXPLAIN; Supabase/diff checks. Context hygiene requires the scheduled T-229 meta-review.
Result: Q-34 classifies all 12 FK and 8 unused-index INFO findings. Only handoff `booking_id` and request-photo `customer_id` need indexes; 10 FK findings already have usable indexes. No unused index is safe to remove from current low-cardinality evidence.
Risks: Read-only remote inspection plus docs only. No schema/config/data write, migration, statistics reset, TestOps execute, seed, deploy, release action, or APNs work occurred. Q-36 still requires explicit migration authorization.
```
