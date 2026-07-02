# TestOps Memory

This file records current TestOps capability and limits. It is not task history.

## Current Capability

- CLI entrypoint: `scripts/testops.mjs`.
- Tested core module: `scripts/testops-core.mjs`.
- Unit test entrypoint: `./scripts/testops-unit.sh`.
- Backend lifecycle scenario: `marketplace_full_lifecycle`.
- Smoke matrix: `smoke5`.
- Matching scenario: `request_matching_eval`.
- Matching matrix: `matching_baseline`.
- UI launch smoke: `scripts/ios-testops-e2e.sh`.
- Run artifacts: `artifacts/testops/` (ignored generated output, not source-of-truth docs).

## Remote Write Gate

Remote execute/cleanup requires all of these:

- explicit user authorization for the current run,
- `--execute`,
- `--cleanup` unless preserving tagged rows is intentional,
- `TESTOPS_REMOTE_WRITE_APPROVED=1`,
- valid Supabase URL/publishable key,
- either legacy `SUPABASE_SERVICE_ROLE_KEY=eyJ...` or modern `SUPABASE_SECRET_KEY=sb_secret_...`.

Modern `sb_secret_...` values are sent as `apikey` only, never Bearer. Seed scripts still require JWT-shaped legacy service-role keys.

## Limits

- Full UI lifecycle automation is not expanded beyond launch wiring.
- `smoke5` is backend lifecycle automation only.
- `matching_baseline` creates request-only matching evaluations; it does not create offers, bookings, chat rows, reviews, image uploads, or Storage objects.
- Screenshots are failure artifacts only, never pass/fail assertions.
- TestOps must use the T-129 seeded account pool; it must not create new test accounts.

## Account Pool

- Groomers: `docs/02_architecture/test_resources/T-129_GROOMER_TEST_PROFILES.md`.
- Customers: `docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md`.

Read the test-resource README first. The profile tables are machine-readable parser inputs and are not default context.
