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
- UI harness: `scripts/ios-testops-e2e.sh` plus `TestOpsUIFlowDriver`; clear-session smoke always runs, while seeded customer/groomer navigation runs when role credentials are supplied through environment variables.
- Full UI lifecycle: `scripts/ios-testops-lifecycle.sh` plus `TestOpsLifecycleTests`; requires the remote-write gate, verifies Debug JSONL and backend state, then enforces zero-residue cleanup.
- Run artifacts: `artifacts/testops/` (ignored generated output, not source-of-truth docs).
- Doctor recognizes either legacy service-role or modern secret server credentials without printing values.
- Lifecycle and matching console results plus JSON/Markdown artifacts retain only 8-character entity support references.

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

- `smoke5` is backend lifecycle automation only.
- Full UI lifecycle currently uses the fixed `BTC-001` / `BTG-001` pair; matrix UI execution is not implemented.
- `matching_baseline` creates request-only matching evaluations; it does not create offers, bookings, chat rows, reviews, image uploads, or Storage objects.
- Screenshots are failure artifacts only, never pass/fail assertions.
- TestOps must use the T-129 seeded account pool; it must not create new test accounts.
- Seed credentials are never committed to the harness or printed. The wrapper uses `TEST_RUNNER_` environment forwarding, redacted summaries, and temporary result cleanup.
- Stable selectors cover authentication, both role tab sets, request/offer/booking/chat/review actions, and support-reference entity targeting. Groomer's sixth tab uses the system More overflow.

## Account Pool

- Groomers: `docs/02_architecture/test_resources/T-129_GROOMER_TEST_PROFILES.md`.
- Customers: `docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md`.

Read the test-resource README first. The profile tables are machine-readable parser inputs and are not default context.
