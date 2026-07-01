# TestOps Memory

## Current State

- T-136 introduces the TestOps documentation set, scripts, launch arguments, and Debug Console TestOps section.
- `scripts/testops.mjs` supports `doctor`, backend lifecycle dry-run/execute, tagged cleanup, and report generation.
- `scripts/ios-testops-e2e.sh` runs the TestOps launch smoke.
- Backend execute/cleanup require `--execute` plus `TESTOPS_REMOTE_WRITE_APPROVED=1`.
- No Supabase schema, RLS, RPC, Storage, or remote data write is part of T-136 implementation.

## Known Limits

- Full UI lifecycle automation is not yet expanded beyond launch wiring.
- The initial backend lifecycle intentionally skips image upload so cleanup is deterministic and does not need Storage object deletion.
- TestOps reports generated under `artifacts/testops/` are local artifacts, not source-of-truth task records.

## Account Pool

- Groomer accounts: `docs/02_architecture/test_resources/T-129_GROOMER_TEST_PROFILES.md`
- Customer accounts: `docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md`

