# TestOps Run Records

Use this folder only when a run result needs to become a durable project reference.

Routine local outputs from `scripts/testops.mjs` belong under `artifacts/testops/` and should not be committed unless a task explicitly asks to preserve a run record.

Durable records:

- `T-299_ADDRESS_BACKFILL_RADIUS.md`: controlled Apple Maps backfill counts, reviewed exception, and six-case coordinate radius evidence.
