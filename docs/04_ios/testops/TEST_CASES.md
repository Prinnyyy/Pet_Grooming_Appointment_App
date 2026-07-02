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
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
export TESTOPS_REMOTE_WRITE_APPROVED=1

node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --matrix smoke5 \
  --execute \
  --cleanup
```

The current TestOps CLI expects `SUPABASE_SERVICE_ROLE_KEY` to be a JWT-shaped legacy service-role key because it uses that value as a Bearer token for service verification and cleanup. Do not substitute `SUPABASE_SECRET_KEY=sb_secret_...`, `supabase_api_key`, or a publishable key. Modern Supabase secret keys are not JWTs and need different request headers before they can replace this variable.

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
