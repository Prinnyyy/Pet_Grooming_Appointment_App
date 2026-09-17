# Controlled Address Backfill

Use this runbook only for the R-040 Apple Maps/PostGIS legacy-address migration. The tool is macOS-only, dry-run by default, and never writes full addresses or coordinates to artifacts.

## Safety Contract

- Remote reads require `SUPABASE_URL` plus `SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY`.
- Writes require both `--execute` and `ADDRESS_BACKFILL_REMOTE_WRITE_APPROVED=1`.
- Only complete rows missing `address_location_id` are listed: Groomer profiles, Customer profiles, then active `open`/`has_offers` Requests.
- Apple Maps must return exactly one US result with the same normalized street number/core, state, and ZIP. City language/postal aliases are display variants; conflicting ZIP never auto-approves.
- A complete Unit/Apt/Suite suffix is removed only from the geocode query and remains unchanged in the source snapshot.
- Decisions contain support refs, SHA-256 address fingerprints, counts, and reason codes only.
- Writes compare the complete address snapshot under a row lock and run as one atomic batch per source type.
- Documented exceptions require a current support ref, address fingerprint, and safe reason code.

## Commands

Dry-run all unresolved targets:

```bash
node scripts/address-backfill.mjs --kind all --run-id T-299-DRY
```

Review the ignored decision artifact under `artifacts/address-backfill/<run-id>/`. Do not edit a decision to change its status. Record a manually reviewed blocker in a separate ignored exception file without address text or coordinates.

Authorized execution:

```bash
export ADDRESS_BACKFILL_REMOTE_WRITE_APPROVED=1
node scripts/address-backfill.mjs \
  --kind groomer_profile \
  --execute \
  --decision-file artifacts/address-backfill/<run-id>/decisions.json \
  --run-id T-299-EXEC-GROOMER
```

Repeat for `customer_profile` and `active_request`; pass `--exception-file` only for a current reviewed exception. Rerun the default dry-run and service-only summary after execution.

## Validation

```bash
./scripts/address-backfill-unit.sh
./scripts/testops-unit.sh
node scripts/testops.mjs run matching \
  --scenario request_matching_eval \
  --matrix matching_radius
```

T-300 completed strict coordinate cutover after these gates passed. Future backfill verification must preserve zero active Groomer/Request gaps and zero private-location orphans; matching no longer has a text fallback.
