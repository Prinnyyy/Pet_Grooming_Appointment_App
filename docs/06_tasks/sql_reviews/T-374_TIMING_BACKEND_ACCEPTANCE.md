# T-374 Timing Backend Acceptance

Status: original WP-03 backend acceptance passed, 2026-09-08. Package evidence belongs to the [plan](../../superpowers/plans/2026-09-07-functional-reliability-task-plan.md); later package and release limits remain explicit below.

## Deployment

- `20260908052312_t374_service_timing.sql` is applied and append-only. All 74 local/remote histories align: `/tmp/beckon-t374-release-history-after.log`.
- Assertions against installed definitions, without reinjecting the migration, pass for hours, bookings, offers, settings, addresses and publication: `/tmp/beckon-t374-deployed-combined.log`. Exact fixture restoration passes.
- Post-apply dry run is empty: `/tmp/beckon-t374-post-apply-dry-run.log`. Security advisors show only existing Q-93, no ERROR: `/tmp/beckon-t374-post-apply-security.log`.
- No existing-account buffer or address-timezone backfill was performed.

## Admission And Save

Runner: `scripts/test-t374-admission-save.mjs`, authorized by `TESTOPS_REMOTE_WRITE_APPROVED=1`; only BTC-001/BTG-001. Preflight requires no open unexpired requests, no occupied groomer bookings, and no existing pair conversation. Temporary seven-day Los Angeles hours and explicit buffers are restored from exact rows, including timestamps. No production function, RLS, or migration changes occur during this test.

`/tmp/beckon-t374-linked-admission-save-diagnostic.log` passes both orderings:

1. Booking wins; Save returns exact `22023/time_off_conflicts_with_booking_occupancy`.
2. Time off wins; acceptance returns exact `22023/occupied_time_off_conflict`.

One CLI transaction holds groomer advisory lock 71071; two independent HTTP sessions invoke the actual RPCs. Before releasing the lock, the holder verifies both named RPCs are active and blocked by its own PID. Final authenticated booking/time-off readback agrees with each outcome. The final shared 39-field snapshot equals the pre-test snapshot exactly. Requests, booking conversation/messages, notifications and temporary settings are restored/removed within the named fixture scope. Recovery artifacts are private under ignored `artifacts/testops/`.

The first run passed two booking-first races. A later attempted reverse-order run failed to verify the barrier; its exact restoration passed and it does not count as acceptance. The subsequent diagnostic run above passed both orderings. The barrier's fixed launch delay remains a possible source of harness flakiness; failed contention verification fails closed, never becomes a concurrency claim. No automatic retry is implemented.

## Integrated Flow And Limits

- The latest `/tmp/beckon-t374-linked-v4-local-fixture.log` extends the runner to actual authenticated v4 publication/replay, automatic matching (no injected match), actual offer creation, customer offer allocation readback, accepted booking allocation equality and acceptance replay/read-only receipt equality. Both contention orderings and exact 39-field restoration pass. Full completion/review behavior is not claimed; fulfillment changes belong to WP-06.
- The earlier v4 trial correctly produced no target match: its Fullerton fixture point was 20.5 miles from a 12-mile-radius groomer (`/tmp/beckon-t374-v4-fixture-location.log`). Exact restoration passed. The final case uses the groomer's existing coordinate-backed address as the explicitly temporary service location, with consistent text/coordinates and an active Dog fixture. No radius, profile address, or matching rule was changed to obtain a match.
- Actual provider-confirmation/new Wizard publication and quote submission pass at the client adapter boundary; see [UI acceptance and release limits](T-374_TIMING_UI_ACCEPTANCE.md).
- Unknown HTTP write outcomes retain fixtures for reconciliation; immediate snapshots do not prove absence of late writes.
- Matching alignment remains WP-04. No distribution, physical-device interruption, or full-plan completion is claimed.
- General TestOps `cleanupRun` now follows booking cards, preserves participant conversations and untagged chat, and only explicitly deletes exact run-tagged messages; cards cascade with bookings. A regression rejects obsolete conversation queries or conversation-wide deletion. All 80 TestOps tests pass (`/tmp/beckon-t374-participant-cleanup-green.log`). This is conservative generic cleanup, not exact thread/metadata restoration. These passing remote runs use the dedicated runner's guarded SQL restoration, not that helper. `verifyUILifecycleRun` resolves the participant pair from booking identities.

Local evidence: 79 TestOps tests pass (`/tmp/beckon-t374-db-barrier-diagnostic-unit.log`), including barrier failures and both simulated winners; preflight passes (`/tmp/beckon-t374-db-barrier-preflight.log`).
