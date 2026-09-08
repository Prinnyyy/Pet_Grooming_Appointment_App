# WP-07 Rescheduling Acceptance

T-378, 2026-09-08. Original WP-07 accepted under D-046 and the [rescheduling contract](../../03_backend/BOOKING_RESCHEDULING_CONTRACT.md).

## Delivered

- Time-only proposals preserve the original booking until the other participant accepts. One pending proposal, exact base revision, 24-hour/original-start/new-start deadline, reject/withdraw/expiry and terminal invalidation.
- Acceptance excludes only its own old allocation, rechecks current availability/notice/pet/groomer/daily capacity, and atomically replaces the same booking's interval, occupied interval and agreement. Duration, price, identity, service, address and buffers remain unchanged; old/new snapshots retain history.
- Persistent original-operation recovery, actor-owned receipts plus current state, exact reviewed proposal consent, transactional Chat events, and changed-booking reminder input. Both roles see old/new times and legal actions. Account-timezone settings remain untouched.

## Evidence

| Gate | Result |
|---|---|
| Installed SQL | `/tmp/beckon-t378-installed-sql.log`: authenticated own-overlap, cross-day quota, another booking taking the slot, original-service-boundary expiry, rejection/withdrawal, cancellation invalidation, changed-intent rejection, foreign read/receipt isolation and direct-write denial. Caller-owned rollback using named T-376 fixtures and the existing T-377 historical fixture helper; guards restored before tested RPCs. |
| Real contention | `/tmp/beckon-t378-live-races.log`: both reschedule-first and cancel-first outcomes under verified database request-lock contention; loser PT409, one booking, original receipt/current-state replay. Run `artifacts/testops/T378-749a6493-c4cf-45db-84fe-a93287758024`; exact 39-field restoration passes. Final cleanup confirms zero fixture proposals/operations and disabled guards. |
| Client/runtime | `/tmp/beckon-t378-consent-runtime.log`: four client recovery/consent/reminder cases plus both-role pending/confirmation rendering. Four screenshots exported to `/tmp/beckon-t378-consent-images` and inspected. |
| Integration/build | `/tmp/beckon-t378-integration-serial.log`: full regression passes, 567 unique reported Swift cases, default UI three executed/six environment-gated skips. `/tmp/beckon-t378-build.log`: build passes. Preflight and 19 scoped race-tool cases pass. |
| Deployment | Applied immutable `20260908224104`; 79 versions align, final dry run empty. Advisors retain Q-93 and prior INFOs; new private operation-table RLS/no-policy is intentional server-only access, and two proposal FK indexes are retained despite initial unused-index INFOs. No new WARN/ERROR. |

## Failed Attempts And Limits

- Initial SQL access test expected permission denied, while the controlled reader deliberately returns booking-not-found for outsiders. Original-boundary fixture initially used statement time rather than wall time. Corrected assertions/setup passed without loosening application rules.
- The first full regression had an auto-dismiss timing failure and Simulator launch failure while a shared-directory build overlapped testing. That run is excluded. After build completion, serial full regression passed with no test or application change.
- Original general list completeness, asynchronous enrichment ownership, global reminders and physical-device/distribution qualification remain WP-08/WP-13/WP-11/WP-14. No automatic fault adjudication, reserved proposed slot, or immediate offline remote-change delivery is claimed.
