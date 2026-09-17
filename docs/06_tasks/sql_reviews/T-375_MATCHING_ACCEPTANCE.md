# T-375 Matching Acceptance

Date: 2026-09-08. Scope: WP-04, F-04/F-14/F-15 of the [authorized plan](../../superpowers/plans/2026-09-07-functional-reliability-task-plan.md).

## Delivered Contract

- Explicit service sizes constrain eligibility; missing size/duration/settings produce assessment, never fabricated confirmed fit. Identity, role and owned location remain mandatory.
- The same continuous-interval evaluator supplies candidate eligibility and time explanations. It subtracts actual groomer/pet occupancy, preserves buffers, notice, local-day quota and DST boundaries, and does not sum fragmented gaps. Existing experience ranking weights remain unchanged.
- Append-only private refresh events cover affected active requests after service, location, schedule, time-off and booking changes. Dismissals survive. Owned reads mask queued evaluation as pending; quote and booking writers revalidate explicit constraints under the shared admission lock.
- Publication returns truthful potential-candidate counts and preserves operation replay. Clients distinguish checking from assessment and require explicit quote terms. No customer constraints are changed automatically.

## Evidence

| Gate | Observed result |
|---|---|
| SQL rehearsal | `/tmp/beckon-t375-final-rehearsal.log`: shared WP-03 timing and WP-04 core/evaluator assertions passed in rollback, including unknown/custom data, real occupied/fragmented bookings, dismissal, batch retention, ownership and direct writers. |
| Publication/read/write | Authenticated v4 publication/replay and owned reader denial/pending passed; direct changed-size quote/booking rejected, explicit 30-minute quote was not overwritten by a 60-minute catalog estimate. Logs: `beckon-t375-authenticated-publish`, `match-reader-auth`, `writer-enforcement` under `/tmp/`. |
| Real contention | `/tmp/beckon-t375-linked-matching-races-fixed.log`: both admission/Save orderings passed with verified database lock contention; refresh event survived request-lock SKIP LOCKED and HTTP reads changed from pending to current evaluation. Exact 39-field fixture restoration passed. |
| Ranking/cost | Equal controlled new-groomer fixtures remained exposed with equal scores. Fixed 25-call closed-window baseline/new: 1408/1405 ms; open-window: 2929/2518 ms. D-043 budgets are scoped probes, not production percentiles. |
| iOS integration | `/tmp/beckon-t375-integration.log`, `beckon-t375-build.log` and `beckon-t375-preflight.log` passed. Default UI executed three and skipped six cases; skips are not evidence. Focused transport/publication recovery and service-label RED/GREEN passed. |
| Changed UI | `/tmp/beckon-t375-matching-ui.log`: both pending/assessment rendering tests passed. Exported xcresult screenshots inspected: pending disables quote entry; assessment retains duration/price inputs, no observed overlap. `/tmp/beckon-t375-final-ui.log` passes both cases including final no-input assertions and preserves legacy fixtures. |
| Deployment | Applied immutable `20260908185059_t375_feasible_matching.sql`; 75 local/remote versions aligned and final linked dry run empty. |
| Worker | `beckon_refresh_request_matches` job 4 active every 10 seconds, 25 pairs/run. `/tmp/beckon-t375-worker-delivery.log` records actual scheduled success and queue drained to zero. |
| Security | Installed advisors: no ERROR; existing Q-93 leaked-password warning and three intentional private/server-owned RLS INFOs. No new matching-queue performance advisory. |

## Limits And Recovery

The initial concurrency rerun corrected a fixture expectation after temporary time off had already been restored, not a backend invariant. The failed run also restored all 39 fields; only the corrected complete run is acceptance. No retained test fixtures or credentials are committed.

Pre-deploy SQL files assume a fresh queue inside the migration rollback transaction. Do not rerun them wholesale against the installed active queue. Installed acceptance uses scoped HTTP operations and scheduler/readback evidence.

Refresh is asynchronous; pending is intentional and writer checks remain authoritative. Broad release load, compatible-client distribution and physical-device interruption remain WP-14. Versioned consent/address snapshots remain WP-05; fulfillment remains WP-06. Account-timezone settings are excluded. Disable only the worker for operational recovery if required, retaining pending masking and authoritative write guards; applied migrations require forward fixes.
