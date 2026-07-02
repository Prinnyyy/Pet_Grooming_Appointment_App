# TestOps Test Cases

This file is the stable case catalog. Use `RUNBOOK.md` for commands and `RESULTS_INDEX.md` for saved run records.

## Backend Smoke Matrix: `smoke5`

Run dry-run:

```bash
node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --matrix smoke5
```

Run remote execute only after explicit authorization:

```bash
export SUPABASE_URL="https://lqmasbuqzvcvtawonjlb.supabase.co"
export SUPABASE_PUBLISHABLE_KEY="sb_publishable_..."
export SUPABASE_SECRET_KEY="sb_secret_..."
export TESTOPS_REMOTE_WRITE_APPROVED=1

node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --matrix smoke5 \
  --execute \
  --cleanup
```

TestOps accepts either `SUPABASE_SECRET_KEY=sb_secret_...` or legacy `SUPABASE_SERVICE_ROLE_KEY=eyJ...` for service verification and cleanup. Modern secret keys are sent only as `apikey`, not Bearer JWTs.

| Case | Customer | Groomer | Purpose |
|---|---|---|---|
| `TC-MKT-001` | `GTC-001` Toy Poodle | `GTG-001` curly/full groom | Default LA curly coat full lifecycle |
| `TC-MKT-002` | `GTC-003` Miniature Schnauzer | `GTG-003` wire/full groom | Wire/terrier studio full lifecycle |
| `TC-MKT-003` | `GTC-004` Shih Tzu | `GTG-004` drop/long coat full groom | Small drop-coat full lifecycle |
| `TC-MKT-004` | `GTC-016` German Shepherd | `GTG-006` double-coat large dog | Larger double-coat full lifecycle |
| `TC-MKT-005` | `GTC-049` Standard Poodle | `GTG-041` Orange County curly/full groom | Orange County curly full lifecycle |

## Assertions

Each remote case must assert:

- Customer password sign-in succeeds.
- Active dog pet exists for the customer.
- Request uses `customer_comes_to_groomer` with a valid 15-mile travel radius.
- `create_grooming_request` returns a request id and `match_count >= 1`.
- Selected groomer has a `request_matches` row for that request.
- `create_groomer_offer` returns an offer id.
- `accept_groomer_offer` returns a booking id.
- `complete_booking` succeeds.
- `create_review` returns a review id.
- Service-role verification sees final request, offer, booking, and review state.
- Cleanup leaves zero tagged request rows for `TESTOPS:<run_id>`.

## Safety

- Do not add screenshots as pass/fail logic.
- Do not run matrix execute without a fresh remote-write authorization.
- Do not manually delete by broad email domain or table name. Cleanup must start from `TESTOPS:<run_id>`.
- Do not add Storage/image cases to `smoke5`; create a separate case set when image cleanup is implemented.

## Matching Baseline Matrix: `matching_baseline`

Run dry-run:

```bash
node scripts/testops.mjs run matching \
  --scenario request_matching_eval \
  --matrix matching_baseline
```

Run remote execute only after explicit authorization:

```bash
export SUPABASE_URL="https://lqmasbuqzvcvtawonjlb.supabase.co"
export SUPABASE_PUBLISHABLE_KEY="sb_publishable_..."
export SUPABASE_SECRET_KEY="sb_secret_..."
export TESTOPS_REMOTE_WRITE_APPROVED=1

node scripts/testops.mjs run matching \
  --scenario request_matching_eval \
  --matrix matching_baseline \
  --execute \
  --cleanup
```

| Case | Customer / Pet | Target Groomer | Expected Target Result | Purpose |
|---|---|---|---|---|
| `TC-MATCH-001` | `GTC-001` Toy Poodle | `GTG-001` curly/full groom | include | Exact preferred window fits |
| `TC-MATCH-002` | `GTC-001` Toy Poodle | `GTG-001` curly/full groom | include | Same-day capacity when preferred time is late |
| `TC-MATCH-003` | `GTC-003` Miniature Schnauzer | `GTG-003` wire/terrier studio | include | Wire coat and studio full groom |
| `TC-MATCH-004` | `GTC-016` German Shepherd | `GTG-006` large double-coat groomer | include | Large double-coat full groom |
| `TC-MATCH-005` | `GTC-049` Standard Poodle | `GTG-041` OC curly/full groom | include | Orange County curly poodle |
| `TC-MATCH-006` | `GTC-002` Golden Retriever | `GTG-002` mobile deshed groomer | exclude | Target lacks `full_groom` service |
| `TC-MATCH-007` | `GTC-001` Toy Poodle | `GTG-005` mobile-only groomer | exclude | Target does not support studio request mode |
| `TC-MATCH-008` | `GTC-001` Toy Poodle | `GTG-001` weekday-only groomer | exclude | Target lacks enabled availability on request day |

Matching assertions:

- Customer password sign-in succeeds.
- Active dog pet exists for the selected customer.
- `create_grooming_request` returns a request id.
- Positive target cases assert the target groomer has a `request_matches` row.
- Negative target cases assert the target groomer has no `request_matches` row.
- Positive reason assertions check targeted fragments only, not the entire reason string.
- Local dry-run projection explains target hard-filter state before remote execution.
- Cleanup leaves zero tagged request rows for each `TESTOPS:<run_id>`.
