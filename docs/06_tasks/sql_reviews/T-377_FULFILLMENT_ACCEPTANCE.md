# WP-06 Fulfillment Acceptance

T-377, 2026-09-08. Original WP-06 accepted. D-045 and [fulfillment contract](../../03_backend/BOOKING_FULFILLMENT_CONTRACT.md) define the adopted policy; WP-07 follows.

## Delivered

- Server-timed actual start/end, no future or instant completion, pre-start cancellation, interruption/no-show reports, other-participant confirmation, withdrawal, elapsed closure, retrospective bilateral correction and objections without invented fault or history.
- Versioned, participant-owned mutation and persistent original-operation recovery. Receipt lookup returns current booking state; reports/events and Chat writes are transactional. Missing handoff fulfillment data requires verification rather than exposing old writer buttons.
- Immutable planned agreements; effective pet/groomer release feeds exclusions, admission, matching, quote evaluation and coverage. Nonzero cleanup/travel remains reserved; daily quota does not reset after early release. Only completed service allows one review.
- Both-role detail actions, confirmation/reason forms, recent activity, explicit read-only check versus retry, single-booking refresh, and unfulfilled new-request recovery. Reminders are withdrawn only after a verified changed outcome. Account-timezone settings untouched.

## Evidence

| Gate | Result |
|---|---|
| Installed SQL | `/tmp/beckon-t377-installed-vectors.log`: authenticated role lifecycle, replay/stale revision, future/instant rejection, nonzero release/admission/quota, report withdrawal, objection, bilateral correction, review uniqueness and access denial; caller-owned rollback. Time checks run after acquiring locks. |
| Real HTTP | `/tmp/beckon-t377-live-terminal-races-final.log`: both participant winner orders under verified database lock contention, one terminal result/event, original receipt and owned lookup, exact 39-field restoration. Run `artifacts/testops/T377-571317ea-72e5-44df-a303-2afc317fa18a`. Final cleanup confirms zero fixture events and disabled guards. |
| Client | `/tmp/beckon-t377-integration.log`: full regression, 559 unique reported Swift cases; default UI three executed/six environment-gated skips. `/tmp/beckon-t377-final-handoff.log`: final fulfillment/Bookings Store and both-role rendering suites pass, including provisional handoff, persistent recovery, exact transport and reminder withdrawal. |
| Runtime/build | `/tmp/beckon-t377-runtime.log`: both roles and accessibility-size detail rendering; exported compact/accessibility images inspected. Final changed detail build `/tmp/beckon-t377-handoff-build.log` passes. |
| Static/deploy | Final preflight, UI consistency, diff and 25 TestOps cases pass. Migration `20260908214656` is applied and immutable; 78 histories align, final dry run empty. Advisors show only existing Q-93/intentional RLS and existing index INFOs, no new fulfillment finding. |

## Failed Attempts And Limits

- Historical rollback setup initially attempted an unavailable replication setting; no privilege was granted. Named fixture guards are restored before tested actions and the transaction rolls back.
- Old DTO test names and new UI semantic-style violations were corrected without changing verification rules. The nonzero-buffer fixture initially read location from the wrong table; corrected to the immutable agreement.
- First HTTP run passed contention but failed exact restoration because temporary advance-notice changes correctly rotated the isolated groomer's eligibility revision. Configuration/data were restored; that historical revision was not forged back. A no-preference-write attempt restored exactly but correctly rejected unconfirmed buffers. Final runner preserves notice, explicitly configures buffers, and restores only its buffer/timestamp change under a transaction with the timestamp trigger restored before commit; final exact comparison passes. These earlier attempts are not acceptance evidence.
- Physical-device/distribution, global reminder reconciliation and broader date-query ownership remain WP-14/WP-11/WP-08. No adjudication staffing, penalties, or unrelated optimization is claimed. Subagents remain disabled; review was performed in this task.
