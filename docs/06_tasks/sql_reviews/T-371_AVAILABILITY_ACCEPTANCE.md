# T-371 Availability Acceptance

Date: 2026-09-07. Scope: functional-reliability WP-01 only.

## Delivered

- One owned snapshot and atomic version-checked Save for weekly hours, preferences and time off.
- Shared groomer admission lock, final-state backfill, preserved confirmed bookings, revoked legacy partial writes.
- Independent profile edits, draft-only time off, conflict/reload recovery and guarded discard.
- Public permanent revision conflicts use PT409/HTTP 409. The initial 40001 mapping caused an actual HTTP timeout/retry incident; the append-only correction was deployed and verified.

## Evidence

- Full iOS regression: 457 Swift cases, zero failures; default UI suite executed three and skipped six credential/write-gated cases. These skips are not interaction evidence.
- Separate authorized seeded UI runs: four navigation cases, draft cancel/discard/reload, and actual Save/reload all passed without skips. Independent server reads confirmed UI Save; exact original rows/revision were restored.
- Real database rollback validation covered weekly insert, preference upsert and time-off insert failures; original schedule, bookings and matches remained unchanged.
- Authenticated-role and cross-account validation covered signed-out/anonymous/customer rejection, foreign revision rejection, spoofed ownership isolation and nine direct-write denials.
- Concurrent same-version HTTP submissions produced exactly one success and one PT409 conflict.
- Save/acceptance tests passed simultaneous requests, Save-first rejection without booking creation, and acceptance-first preservation of the confirmed booking after closing hours.
- All remote fixtures used designated BTG-001/BTC-001 seed accounts. Unique request tags bounded cleanup; original schedule IDs/timestamps/revision and booking/match hashes were independently verified after each successful run. No existing conversation was removed.
- Preflight: 85 migration tests and 10 function tests passed. Final iOS build passed; only existing AppIntents metadata information remains.
- Linked history: 72 versions align; final push dry run empty. Security/performance advisors retained only existing Q-93.

## Repeatable Checks

Remote commands require explicit operator authorization and the existing local client configuration. Never run these against another project or concurrently with another writer to the named fixtures.

```sh
TESTOPS_REMOTE_WRITE_APPROVED=1 node scripts/test-t371-availability-race.mjs race
TESTOPS_REMOTE_WRITE_APPROVED=1 node scripts/test-t371-availability-race.mjs ui-save
TESTOPS_REMOTE_WRITE_APPROVED=1 node scripts/test-t371-availability-race.mjs acceptance-race
TESTOPS_REMOTE_WRITE_APPROVED=1 node scripts/test-t371-availability-race.mjs acceptance-save-first
TESTOPS_REMOTE_WRITE_APPROVED=1 node scripts/test-t371-availability-race.mjs acceptance-accept-first
```

The runners retain recovery snapshots under ignored `artifacts/testops/`. On an unknown network outcome, reconcile outstanding requests before restoration; do not blindly replay an old revision. Rollback/access SQL lives alongside this record.

## Limits

WP-02 through WP-14 are not delivered by this task. Matching reconciliation remains WP-04; insert-only backfill is not claimed to perform it. Existing older clients must update because direct schedule writes are deliberately denied. Distribution/release acceptance remains WP-14. Review was performed locally; repository policy disables reviewer subagents.
