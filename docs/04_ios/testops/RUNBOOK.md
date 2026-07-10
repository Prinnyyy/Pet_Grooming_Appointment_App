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

Do not run matching execute without `--cleanup` unless preserving tagged rows for manual investigation is intentional. Cleanup is scoped to `TESTOPS:<run_id>`.

Artifacts are written under `artifacts/testops/` and are not intended as committed source docs.

## Cleanup

Cleanup deletes only records tagged with the run id:

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
