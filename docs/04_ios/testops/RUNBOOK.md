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

## Backend Lifecycle Dry Run

Print the planned `marketplace_full_lifecycle` payload:

```bash
node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --customer GTC-001 \
  --groomer GTG-001
```

Print the first five remote smoke plans without writing data:

```bash
node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --matrix smoke5
```

## Backend Lifecycle Execute

Requires explicit user authorization before running:

```bash
export SUPABASE_URL="https://lqmasbuqzvcvtawonjlb.supabase.co"
export SUPABASE_PUBLISHABLE_KEY="sb_publishable_..."
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
export TESTOPS_REMOTE_WRITE_APPROVED=1

node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --customer GTC-001 \
  --groomer GTG-001 \
  --execute \
  --cleanup
```

`SUPABASE_SERVICE_ROLE_KEY` is currently interpreted by `scripts/testops.mjs` as a legacy JWT-shaped service-role key and is sent as `Authorization: Bearer ...` for service verification and cleanup. Do not use `SUPABASE_SECRET_KEY=sb_secret_...`, `supabase_api_key`, or a publishable key in this variable. Modern `sb_secret_...` keys are not JWTs; using one here fails with a PostgREST JWT decode error. If only `sb_secret_...` is available, update the script first to support secret-key `apikey` semantics, or use an explicitly authorized MCP SQL fallback for read-only verification/tagged cleanup.

The first five-case smoke matrix uses the same safety gate:

```bash
node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --matrix smoke5 \
  --execute \
  --cleanup
```

Artifacts are written under `artifacts/testops/` and are not intended as committed source docs.

## Cleanup

Cleanup deletes only records tagged with the run id:

```bash
SUPABASE_URL="https://lqmasbuqzvcvtawonjlb.supabase.co" \
SUPABASE_PUBLISHABLE_KEY="sb_publishable_..." \
SUPABASE_SERVICE_ROLE_KEY="eyJ..." \
TESTOPS_REMOTE_WRITE_APPROVED=1 \
node scripts/testops.mjs cleanup --run-id TESTOPS-... --execute
```

## UI Launch Wiring

Run the TestOps XCUITest launch smoke:

```bash
TESTOPS_RUN_ID=TESTOPS-LOCAL-0001 \
./scripts/ios-testops-e2e.sh marketplace_full_lifecycle
```

This currently verifies launch arguments, live-auth clear-session behavior, and the authentication root. Full UI lifecycle automation should build on this wrapper with stable accessibility identifiers and backend verification.

## Debug Events

After a local app repro:

```bash
./scripts/ios-debug-events.sh tail 300
```

Filter by `category=test`, `automationRunID`, `scenarioID`, `phase`, and nearby `store`/`repository` events.
