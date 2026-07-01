# TestOps Memory

## Current State

- T-136 introduces the TestOps documentation set, scripts, launch arguments, and Debug Console TestOps section.
- T-137 splits TestOps into thin CLI `scripts/testops.mjs` plus testable core module `scripts/testops-core.mjs`.
- `scripts/testops.mjs` supports `doctor`, backend lifecycle dry-run/execute, tagged cleanup, report generation, and `--matrix smoke5`.
- `./scripts/testops-unit.sh` runs Node built-in tests under `tests/testops/`.
- `TEST_CASES.md` defines the first five backend smoke cases. Authorized remote `smoke5` passed 5/5 on 2026-07-01 and cleanup left zero tagged requests/offers/reviews.
- `scripts/ios-testops-e2e.sh` runs the TestOps launch smoke.
- Backend execute/cleanup require `--execute` plus `TESTOPS_REMOTE_WRITE_APPROVED=1`.
- No Supabase schema, RLS, RPC, Storage, or remote data write is part of T-136/T-137 implementation.

## Known Limits

- Full UI lifecycle automation is not yet expanded beyond launch wiring.
- `smoke5` is backend lifecycle automation only; screenshot assertions remain out of scope.
- The initial backend lifecycle intentionally skips image upload so cleanup is deterministic and does not need Storage object deletion.
- For `customer_comes_to_groomer`, TestOps must send a valid travel radius; use the app-default 15 miles.
- TestOps reports generated under `artifacts/testops/` are local artifacts, not source-of-truth task records.

## Account Pool

- Groomer accounts: `docs/02_architecture/test_resources/T-129_GROOMER_TEST_PROFILES.md`
- Customer accounts: `docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md`
