# TestOps Results Index

Committed source docs should not accumulate raw run output by default.

Use this index only for durable summaries that future work needs. Local command artifacts are generated under:

```text
artifacts/testops/
```

## Durable Results

| Run ID | Scenario | Date | Status | Notes |
|---|---|---:|---|---|
| `TESTOPS-MATCH-REMOTE-20260702-*` | `request_matching_eval` / `matching_baseline` | 2026-07-02 | passed | Authorized remote run passed 8/8. Positive target cases matched with expected reason fragments; negative target cases excluded the target groomer. Tagged cleanup left `remainingTaggedRequests=0`. |
