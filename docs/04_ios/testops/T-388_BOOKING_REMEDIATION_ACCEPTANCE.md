# T-388 Booking Remediation Acceptance

Status: accepted 2026-09-10. All three defects closed within the adopted Simulator/Beckon scope; migrations deployed and fixtures restored.

Plan: [Booking Defect Remediation](../../superpowers/plans/2026-09-10-booking-defect-remediation-plan.md).
Historical baseline: [T-387](T-387_BOOKING_SCENARIOS.md), 72 executed / 69 passed / 3 failed. That result is unchanged.

## Implemented Scope

| Defect | Implementation | Acceptance |
|---|---|---|
| F2 / B72 | Retire locked original before unchanged quota-checked publication; preserve rollback/replay guards | PASS: B69/B70/B72 and E01-E08, including actual concurrent operations and full rejection digests |
| F3 / B67 | Shared session Store, authoritative acceptance read, generation guards and coalesced refresh | PASS: B65-B68; second booking visible within 3 seconds without refresh/relogin; both roles see equal authoritative state |
| F1 / B71 | Nullable conversation target and exact participant routing, no guessed booking | PASS: B71 and both notification UI clicks after one of multiple bookings was cancelled; exact notice read state/message verified |

Migrations applied to Beckon on 2026-09-10: `20260910125035_t388_atomic_request_replacement.sql` and `20260910125207_t388_message_notification_conversations.sql` in `supabase/migrations/`. Previous 83 versions aligned; dry run listed exactly these two, push succeeded, subsequent history aligned and dry run was empty. Actual nullable columns, SET NULL FKs, two indexes, enabled RLS, denied target-column UPDATE, trigger ACLs and replacement ordering were verified (`/tmp/t388-backend-verification.json`). Advisors report only `auth_leaked_password_protection` WARN; no migration-specific finding (`/tmp/t388-advisors.json`).

## Local Evidence

- Static replacement ordering and both conversation triggers were RED before fixes. Five new migration assertions and eight existing publish-idempotency/versioned-agreement tests pass. Final Preflight passed (`/tmp/t388-preflight-final.log`). These are not transaction/deployment proof.
- Shared-list late-read and both-role target-only routing tests were RED. Seven related Swift suites passed 219 tests (`/tmp/t388-focused-r3.log`).
- Review found a confirmed receipt can replay a rescheduled booking. Strengthened pre-refresh identity/content assertion failed (`/tmp/t388-replay-red-r2.log`, 120 tests / one issue), then passed after removing quote projection (`/tmp/t388-replay-green.log`, 120 tests / zero issues). An earlier individual selector selected no tests and is not evidence.
- Final full `ios-test.sh` succeeded (`/tmp/t388-full-final.log`). XCResult summary: 651 unique tests, 637 passed, 14 skipped, zero failed. Parameterized executions are not counted as extra scenarios. The UI subset has 16 tests, 12 skipped; real-account opt-in skips are not real booking acceptance. Evidence: `Test-Beckon-2026.09.10_06-21-44--0700.xcresult` in the current Beckon DerivedData `Logs/Test` directory; iPhone Air Simulator, iOS 26.5. A Simulator IPC shutdown diagnostic appeared after successful results; XCResult reports no test failures.
- Final `ios-build.sh` passed (`/tmp/t388-build-final.log`). Only the existing no-AppIntents metadata extraction warning was reported.
- HTTP runner, fixture and Simulator driver pass Node syntax checks; `git diff --check` passes. Real HTTP run completed 83/83 PASS: original B01-B64/B69-B72 (68 cases), plus 15 H/mixed-channel edges. Results and request trace: `artifacts/testops/TESTOPS-T387-T388-20260910-A/results.json` and `http-trace.json`; summary `/tmp/t388-http.log`.
- Startup recovery now additionally asserts the injected shared Store contains the exact recovered Booking. Updated `CustomerRequestsStoreTests` passed 120 tests (`/tmp/t388-recovery-shared.log`); production code is unchanged from the final full regression.
- E15 now directly tests both network failure and cancellation after synchronization, retained committed data, invalidated cursor and explicit retry recovery. Updated `BookingScopedReadTests` passed 12 tests (`/tmp/t388-refresh-recovery.log`); only tests changed since the full production-code regression.
- Six opt-in Simulator phases passed independently: PublishTwoRequests (111.471s), QuoteTwoRequests (83.248s), AcceptTwoRequests (81.533s), CancelOneRequest (32.675s), customer notification (22.705s), groomer notification (23.090s). These complete B65-B68 plus E17/E18 U evidence. Phase durations are test durations, not app latency measurements. Exact outcomes are in the run's `ui-*.json` and `ui-outcomes-*.json` artifacts. Original B01-B72: 72/72 PASS, no skipped original scenario.

## Edge Coverage

| IDs | Passing evidence |
|---|---|
| E01-E08 | Actual H replacement/replay/races/rejection digests; expired-fixture setup boundary below |
| E09-E11 | Shared acceptance/pre-refresh and controlled stale-page tests; B67 U; fresh paging and duplicate guards |
| E12-E14 | Lost-response/store-restart/terminal-replay/session-isolation S; current cancelled acceptance receipt H; no second acceptance write |
| E15-E16 | Controlled failed/cancelled-refresh S, legacy cancellation/reschedule/fulfillment suites; B68 U and equal counterpart state |
| E17-E19 | Both real text directions, multiple-booking conversation reuse and exact H reads; both U clicks; target-outside-loaded-page S |
| E20-E24 | Legacy/targetless/read-failure/wire-model S; foreign access/target-write denial and legacy projections H; read/FK transaction evidence below |

## Real-Scenario Evidence Boundaries

- Existing runner retains B01-B72 identities, with B65-B68 owned by the Simulator driver. All E01-E24 requirements are covered through the channels above; do not describe the S-only cases or rolled-back SQL checks as 96 real user UI scenarios.
- E08 expiration used a separate SQL-seeded historical fixture followed by authenticated HTTP rejection, never mutation of published immutable terms or a fake clock. Fixture insertion and rejection both succeeded on the actual schema.
- E24 single-read uses authenticated HTTP. Batch-read uses authenticated SQL/JWT context inside a rollback transaction so original notifications stay unchanged. FK deletion is also rolled back; no persisted conversation deletion is claimed as a user action.
- E17 UI driver sent real three-column messages through authenticated HTTP and clicked their resulting notifications in Simulator. It did not type into the chat composer. Both clicks ran after B68 cancellation with the other UI booking still confirmed, satisfying E18 without guessing a booking target.
- Cleanup excluded baseline notification IDs and rejected unscoped new text notices. Exact restoration passed 15/15 hashes, including notifications/messages/addresses/receipts; tagged request count is zero and `recovery.restored` is true. Evidence: run `restoration.json`, `message-notification-cleanup.json`, `recovery.json`, and `/tmp/t388-cleanup.log`. Preference timestamps/security revisions legitimately advance; the existing snapshot contract excludes these monotonic audit fields and they were not rolled back or disguised.

## Closure

User explicitly authorized the two Beckon migrations, existing-account TestOps writes, scoped temporary settings restore and this run's fixture cleanup on 2026-09-10. New run `TESTOPS-T387-T388-20260910-A` prepared from an idle cohort; its recovery/baseline artifacts are under `artifacts/testops/TESTOPS-T387-T388-20260910-A/`. Never prepare over these artifacts or reuse a restored run.

No failed H/U execution required a retry in this run. Local RED evidence remains separate. Deployment metadata/advisors/history copies are also retained in the run directory. No real device, account creation, signing, store or APNs work was added. Existing unrelated dirty documentation and archived snapshots remain outside the scoped T-388 commit.
