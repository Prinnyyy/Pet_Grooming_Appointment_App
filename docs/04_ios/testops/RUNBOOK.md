# TestOps Runbook

## Doctor

Check local resources and environment without remote writes:

```bash
node scripts/testops.mjs doctor --dry-run
```

## Unit Tests

Run all TestOps Node unit tests, including parser, safety-gate, plan, redaction, report, cleanup, credential-type, run-id, and lifecycle-failure edge coverage:

```bash
./scripts/testops-unit.sh
```

## Seed Identity Verification

Inspect the planned Beckon seed identity target without a remote connection:

```bash
node scripts/seed-identity-cutover.mjs
```

After loading ignored Supabase environment variables, verify all 100 remote seed identities without writing:

```bash
node scripts/seed-identity-cutover.mjs --verify
```

Remote execute or explicit legacy rollback requires fresh operator authorization plus `BECKON_REMOTE_IDENTITY_APPROVED=1`. The runner updates Auth users in place, preserves UUIDs, validates a stable mapping digest, and automatically restores each user's exact pre-run identity if a batch fails. Never print seed credentials or service keys.

## Backend Lifecycle Dry Run

Print the planned `marketplace_full_lifecycle` payload:

```bash
node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --customer BTC-001 \
  --groomer BTG-001
```

Print the first five remote smoke plans without writing data:

```bash
node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --matrix smoke5
```

## Matching Evaluation Dry Run

Print the matching baseline plan without writing data:

```bash
node scripts/testops.mjs run matching \
  --scenario request_matching_eval \
  --matrix matching_baseline
```

This emits 8 redacted plans with local candidate projection:

- positive target inclusion for curly, wire, double-coat, and Orange County poodle paths;
- same-day capacity behavior where the preferred window does not exactly fit;
- negative target assertions for service mismatch, location-mode mismatch, and unavailable request day.

## Backend Lifecycle Execute

Requires explicit user authorization before running:

```bash
export SUPABASE_URL="https://lqmasbuqzvcvtawonjlb.supabase.co"
export SUPABASE_PUBLISHABLE_KEY="sb_publishable_..."
export SUPABASE_SECRET_KEY="sb_secret_..."
export TESTOPS_REMOTE_WRITE_APPROVED=1

node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --customer BTC-001 \
  --groomer BTG-001 \
  --execute \
  --cleanup
```

TestOps accepts either `SUPABASE_SECRET_KEY=sb_secret_...` or legacy `SUPABASE_SERVICE_ROLE_KEY=eyJ...` for service verification and tagged cleanup. Modern `sb_secret_...` values are sent only as `apikey`, never as `Authorization: Bearer ...`. Publishable keys are rejected for service verification.

For the T-374 timing contract, add `--timing` to the backend lifecycle command. Execution requires `--cleanup` and the same explicit remote authorization above. This mode reads timing capability version 1, four confirmed bounded buffers, seven weekdays in one valid schedule zone, and a coordinate-backed v3 profile address with a confirmed zone before publishing through v4. It preserves the publication operation ID and request values; it does not fabricate missing settings, update profiles, or fall back to v3 publication. The normal path remains available without this flag. Timing mode is included in redacted plan/result output. A failed timing run attempts tagged cleanup; cleanup failure is reported as unverified restoration, not a successful run.

This is an opt-in lifecycle transport path. T-374 deployment, v4 HTTP lifecycle and both admission/Save lock orderings passed through the dedicated guarded runner; see [backend acceptance](../../06_tasks/sql_reviews/T-374_TIMING_BACKEND_ACCEPTANCE.md). That evidence is not a blanket pass for every generic CLI mode or current account state. Before a new run, confirm installed capabilities, named TestOps account settings and legacy publication rollout/retirement restrictions. Existing scenario coordinates remain synthetic test inputs; this mode does not validate Apple Maps lookup or independently establish fulfillment-policy acceptance.

Timing execution currently accepts only BTC-001/BTG-001, the pair covered by the shared T-374 snapshot query. It rejects a pre-existing run marker without cleaning it, then captures the baseline through the sequential linked CLI, executes the HTTP lifecycle, attempts tagged cleanup, and captures the final snapshot even if execution or cleanup failed. Success requires identical snapshots and confirmed zero tagged requests; read failure or mismatch cannot produce a verified result. `scripts/t374-timing-snapshot.mjs` is shared with the SQL rollback runner. Generic CLI runs require their own result and restoration evidence; snapshots do not resolve uncertain late writes or prove concurrency. T-374's accepted live results use the dedicated runner's exact restoration, not generic cleanup alone.

Tagged cleanup accepts only an exact `TESTOPS:<run-id>` marker or that marker followed by a space and scenario text, matching the existing address-cleanup RPC boundary. It checks returned ownership markers again before mutation and fails if tagged requests remain after deletion. Similar run-ID prefixes or marker text embedded later in notes are not eligible. This request-level check does not replace the exact fixture snapshots required for timing/concurrency acceptance.

`--timing-race` implies timing mode and its cleanup/account/snapshot gates. After creating a tagged request and quote, it verifies the schedule-local day is isolated from existing booking occupancy (bounded paginated read), then dispatches customer acceptance and groomer Save adding a uniquely identified one-day time off under `scripts/timing-database-barrier.mjs`. The barrier must observe both RPCs blocked by its holder before releasing the groomer lock. Exactly one must succeed; the rejected operation must carry the expected structured occupancy error, and booking/time-off readbacks must agree. It removes only its own temporary time-off ID using the latest schedule revision, preserving other settings, before outer tagged cleanup and snapshot comparison. It stops before completion/review. Network errors, an unverified barrier, both successes/failures, inconsistent readback or failed temporary restoration fail the run. Concurrent HTTP dispatch alone is not proof of lock contention; generic mode and dedicated acceptance results must remain distinguishable.

The first five-case smoke matrix uses the same safety gate:

```bash
node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --matrix smoke5 \
  --execute \
  --cleanup
```

The matching baseline uses the same safety gate:

```bash
node scripts/testops.mjs run matching \
  --scenario request_matching_eval \
  --matrix matching_baseline \
  --execute \
  --cleanup
```

The coordinate radius matrix uses the same gate and service-only tagged location cleanup:

```bash
node scripts/testops.mjs run matching \
  --scenario request_matching_eval \
  --matrix matching_radius \
  --run-id TESTOPS-RADIUS \
  --execute \
  --cleanup
```

Do not run matching execute without `--cleanup` unless preserving tagged rows for manual investigation is intentional. Cleanup is scoped to `TESTOPS:<run_id>`.

Artifacts are written under `artifacts/testops/` and are not intended as committed source docs.

## Cleanup

Cleanup deletes run-tagged requests and their dependent test records. Participant conversations are preserved: they are shared across bookings, not owned by one request. Conversation lookup follows booking cards, never removed `conversations.request_id`/`booking_id` columns. Within those conversations, only messages whose body is exactly the run marker or begins with the marker plus a space are explicitly deleted; booking cards cascade with their bookings. Untagged chat, including acceptance greetings, is preserved. `preservedParticipantConversationCount` reports affected shared threads, not exact restoration. Timing acceptance that requires restoring original thread rows/metadata must use the dedicated guarded fixture restoration; the generic cleanup helper alone does not meet that stronger gate.

```bash
SUPABASE_URL="https://lqmasbuqzvcvtawonjlb.supabase.co" \
SUPABASE_PUBLISHABLE_KEY="sb_publishable_..." \
SUPABASE_SECRET_KEY="sb_secret_..." \
TESTOPS_REMOTE_WRITE_APPROVED=1 \
node scripts/testops.mjs cleanup --run-id TESTOPS-... --execute
```

## UI Launch Wiring

Run the TestOps XCUITest launch smoke. Without seed credentials, role-navigation cases skip and the clear-session launch contract still runs:

```bash
TESTOPS_RUN_ID=TESTOPS-LOCAL-0001 \
./scripts/ios-testops-e2e.sh marketplace_full_lifecycle
```

For seeded customer/groomer sign-in, tab navigation, customer request-sheet open/dismiss, and session reset, export the four `TESTOPS_UI_<ROLE>_EMAIL/PASSWORD` values from the T-129 seed profiles before running the same command. Do not print or persist those values. The script passes them with Xcode's `TEST_RUNNER_` environment convention, redacts summaries, and deletes its temporary log/result bundle.

This launch harness performs no request/offer/booking writes.

## Authorized UI Lifecycle

Export the four seeded role credential variables, Supabase URL/publishable/server credential, and `TESTOPS_REMOTE_WRITE_APPROVED=1`, then run:

```bash
TESTOPS_RUN_ID=TESTOPS-UI-... ./scripts/ios-testops-lifecycle.sh
```

The wrapper runs only `TestOpsLifecycleTests`, verifies the six lifecycle Store success events from Debug JSONL, verifies final Supabase request/offer/booking/chat/review state, and deletes only `TESTOPS:<run_id>` rows. A run passes only when cleanup reports `remainingTaggedRequests: 0`. Never print or persist the credential values.

## Debug Events

After a local app repro:

```bash
./scripts/ios-debug-events.sh tail 300
```

Filter by `category=test`, `automationRunID`, `scenarioID`, `phase`, and nearby `store`/`repository` events.
