# TestOps Results Index

Committed source docs should not accumulate raw run output by default.

Use this index only for durable summaries that future work needs. Local command artifacts are generated under:

```text
artifacts/testops/
```

## Durable Results

| Run ID | Scenario | Date | Status | Notes |
|---|---|---:|---|---|
| `TESTOPS-LOCAL-T222` | `marketplace_full_lifecycle` dry-run / `matching_baseline` dry-run / readiness rehearsal | 2026-07-09 | passed with non-blocking advisor findings | Q-33 local/read-only evidence recorded in `../release/T-222_IDEAL_OPERATION_READINESS_REHEARSAL.md`; backend smoke5 and matching baseline plans generated, Supabase/iOS gates completed, and advisor findings recorded. |
| `TESTOPS-LOCAL-T221` | `marketplace_full_lifecycle` dry-run / `matching_baseline` dry-run / UI launch smoke | 2026-07-09 | passed | Local no-write Q-32 evidence recorded in `runs/T-221_DUAL_ROLE_E2E_WALKTHROUGH.md`; backend smoke5 and matching baseline plans generated, and iOS launch wiring passed. |
| `TESTOPS-MATCH-REMOTE-20260702-*` | `request_matching_eval` / `matching_baseline` | 2026-07-02 | passed | Authorized remote run passed 8/8. Positive target cases matched with expected reason fragments; negative target cases excluded the target groomer. Tagged cleanup left `remainingTaggedRequests=0`. |
