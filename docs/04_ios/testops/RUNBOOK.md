# TestOps Runbook

## Doctor

Check local resources and environment without remote writes:

```bash
node scripts/testops.mjs doctor --dry-run
```

## Backend Lifecycle Dry Run

Print the planned `marketplace_full_lifecycle` payload:

```bash
node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --customer GTC-001 \
  --groomer GTG-001
```

## Backend Lifecycle Execute

Requires explicit user authorization before running:

```bash
export SUPABASE_URL="https://lqmasbuqzvcvtawonjlb.supabase.co"
export SUPABASE_PUBLISHABLE_KEY="sb_publishable_..."
export SUPABASE_SERVICE_ROLE_KEY="..."
export TESTOPS_REMOTE_WRITE_APPROVED=1

node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --customer GTC-001 \
  --groomer GTG-001 \
  --execute \
  --cleanup
```

Artifacts are written under `artifacts/testops/` and are not intended as committed source docs.

## Cleanup

Cleanup deletes only records tagged with the run id:

```bash
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

