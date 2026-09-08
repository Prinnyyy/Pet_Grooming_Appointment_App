# T-379 Scoped Read Acceptance

Original WP-08 completed on 2026-09-08. D-047 preserves existing participant RLS and repository ownership; no migration, remote application write, or account-timezone settings change.

## Accepted Behavior

- Both Home roles query the nearest confirmed appointment directly, independent of historical list pages. Failed refreshes remain visibly unverified.
- Schedule queries the selected half-open date interval through bounded, deterministically ordered pages. Only a completed scope can show an empty day; failed continuation remains incomplete and late responses cannot replace another day's results.
- Booking details resolve exact owned IDs. Republish verifies the current cancelled/unfulfilled booking and authoritative original request, including unloaded sources, and still requires new address confirmation.
- Actual Debug composition forwards the new reads and existing versioned acceptance, fulfillment, and rescheduling methods instead of inheriting unavailable defaults.

## Evidence

- 55-item nearest-appointment RED: `/tmp/beckon-t379-nearest-red.log`; initial scoped GREEN: `/tmp/beckon-t379-scoped-green.log`.
- Final scoped, Home, republish, actual SDK transport, and runtime tests: `/tmp/beckon-t379-final-surfaces.log` passed. Cases include tied pagination, failed continuation, late day responses, exact missing/foreign objects, source failure, and address reconfirmation.
- Final full regression: `/tmp/beckon-t379-final-integration.log` passed. Default UI executed three cases and skipped six environment-gated cases; skipped cases are not acceptance evidence.
- Final build and preflight: `/tmp/beckon-t379-final-build.log` and `/tmp/beckon-t379-final-preflight.log` passed.
- Changed-surface runtime screenshots exported to `/tmp/beckon-t379-final-images`; normal/date-failure and accessibility rendering inspected, with bottom appointment actions reachable and failed date queries not represented as empty.

## Corrections And Limits

The first transport assertion omitted the SDK's explicit `nullslast` ordering serialization; corrected expectations passed without changing the query. The first full run failed an old scroll-size assertion and exposed date-label wrapping. Vertical date layout and actual inset-aware scrollability were corrected and the final full run passed.

The 55-item coverage is client-fixture plus real SDK request evidence, not a claim of live 55-row remote fixtures. Existing installed RLS is unchanged. Chat lookup/summary completeness belongs to WP-09, reminder reconciliation to WP-11, global asynchronous ownership to WP-13, and remaining old-writer/client distribution checks to WP-14.
