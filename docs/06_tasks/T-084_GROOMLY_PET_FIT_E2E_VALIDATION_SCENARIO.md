# T-084: Groomly Pet-Fit End-To-End Validation Scenario

## Status

- Status: checkpoint - validation harness needs follow-up
- Date: 2026-06-26
- Mode: Deep
- Branch: `codex/pet-fit-structure-cleanup`

## Scope

Validate the full rollback-only pet-fit evidence loop:

1. Customer publishes a request.
2. Eligible groomer receives a match.
3. Groomer submits an offer.
4. Customer accepts the offer into a booking.
5. Groomer completes the booking.
6. Customer submits structured pet-fit review outcomes.
7. Evidence aggregates.
8. A later equivalent request receives a better evidence-backed match reason.
9. RLS and visibility boundaries still hold.

No Supabase migration, schema change, RLS change, RPC change, Storage change, or iOS change is in scope.

## Files Changed

- `docs/06_tasks/sql_reviews/T-084_PET_FIT_E2E_ROLLBACK_VALIDATION.sql`
- `docs/06_tasks/T-084_GROOMLY_PET_FIT_E2E_VALIDATION_SCENARIO.md`

## Validation Attempt

Command:

```sh
supabase db query --linked --file docs/06_tasks/sql_reviews/T-084_PET_FIT_E2E_ROLLBACK_VALIDATION.sql --output json
```

Result:

- Failed with `invalid_booking` from `public.complete_booking(uuid)`.
- The failed statement passed a `null` booking ID into `complete_booking`.
- The likely cause is the validation harness, not the product RPC chain: the groomer-role subquery selected `bookings` joined to `grooming_requests` by service note after offer acceptance had hidden the request match, so the `grooming_requests` RLS path filtered the row for that groomer.
- The harness should be adjusted to keep the accepted booking ID from the customer acceptance step or query the groomer-visible `bookings` row without joining through the now-filtered request row.

## Safety

- The validation script is transaction-scoped and did not reach its final `ROLLBACK`, but the error occurred inside the transaction; the failed query was rolled back by the database session.
- Independent residue check confirmed zero T-084 validation rows across `auth.users`, profiles, customer/groomer profiles, pets, grooming requests, request matches, offers, bookings, reviews, and structured review outcomes.
- `git diff --check` passed for the checkpoint documentation and SQL artifact.

## Next Step

Requires explicit user approval to fix the rollback validation harness and run a second Deep validation attempt.
