# TestOps Results Index

Committed source docs should not accumulate raw run output by default.

Use this index only for durable summaries that future work needs. Local command artifacts are generated under:

```text
artifacts/testops/
```

## Durable Results

| Run ID | Scenario | Date | Status | Notes |
|---|---|---:|---|---|
| `TESTOPS-T300B-SMOKE5-*`, `TESTOPS-T300-BASELINE-*`, `TESTOPS-T300-RADIUS-*` | lifecycle / baseline / strict radius | 2026-07-11 | passed | [T-300 evidence](runs/T-300_STRICT_COORDINATE_CUTOVER.md): lifecycle 5/5, baseline 8/8, radius 6/6, strict missing-coordinate rejection, complete private-location cleanup, and zero residue. |
| `TESTOPS-RADIUS299-TC-RADIUS-001...006` | `request_matching_eval` / `matching_radius` | 2026-07-11 | passed | [T-299 evidence](runs/T-299_ADDRESS_BACKFILL_RADIUS.md): six near/edge/outside cases passed for both service directions; private Request locations and tagged rows were fully cleaned. |
| `TESTOPS-UI-T239-R11-20260709T235452Z` | full dual-role UI lifecycle | 2026-07-09 | passed | [T-239 evidence](runs/T-239_UI_LIFECYCLE.md): no-screenshot UI flow passed, Debug events 6/6 with zero errors, backend final state passed, and tagged residue was zero. |
| `TESTOPS-Q37-*-R2-20260709*` | remote `smoke5` / `matching_baseline` | 2026-07-09 | passed | Q-37 evidence in `runs/T-235_REMOTE_LIFECYCLE_MATCHING.md`: lifecycle 5/5, matching 8/8, artifact safety scans clean, and both tagged residue counts zero. |
| `TESTOPS-LOCAL-T222` | `marketplace_full_lifecycle` dry-run / `matching_baseline` dry-run / readiness rehearsal | 2026-07-09 | passed with non-blocking advisor findings | Q-33 local/read-only evidence recorded in `../release/T-222_IDEAL_OPERATION_READINESS_REHEARSAL.md`; backend smoke5 and matching baseline plans generated, Supabase/iOS gates completed, and advisor findings recorded. |
| `TESTOPS-LOCAL-T221` | `marketplace_full_lifecycle` dry-run / `matching_baseline` dry-run / UI launch smoke | 2026-07-09 | passed | Local no-write Q-32 evidence recorded in `runs/T-221_DUAL_ROLE_E2E_WALKTHROUGH.md`; backend smoke5 and matching baseline plans generated, and iOS launch wiring passed. |
| `TESTOPS-MATCH-REMOTE-20260702-*` | `request_matching_eval` / `matching_baseline` | 2026-07-02 | passed | Authorized remote run passed 8/8. Positive target cases matched with expected reason fragments; negative target cases excluded the target groomer. Tagged cleanup left `remainingTaggedRequests=0`. |
