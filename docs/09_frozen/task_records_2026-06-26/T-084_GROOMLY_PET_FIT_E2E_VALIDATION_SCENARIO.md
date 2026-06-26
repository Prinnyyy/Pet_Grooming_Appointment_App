# T-084: Groomly Pet-Fit End-To-End Validation Scenario

## Status

- Status: completed
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
- `docs/06_tasks/T-075_TO_T-085_GROOMLY_PET_FIT_EVIDENCE_CLOSURE_PLAN.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

## Validation

Command:

```sh
supabase db query --linked --file docs/06_tasks/sql_reviews/T-084_PET_FIT_E2E_ROLLBACK_VALIDATION.sql --output json
```

First attempt:

- Failed with `invalid_booking` from `public.complete_booking(uuid)`.
- The failed statement passed a `null` booking ID into `complete_booking`.
- The likely cause is the validation harness, not the product RPC chain: the groomer-role subquery selected `bookings` joined to `grooming_requests` by service note after offer acceptance had hidden the request match, so the `grooming_requests` RLS path filtered the row for that groomer.

Authorized follow-up:

- Corrected the harness to query participant-visible `bookings` rows directly for completion and review, without joining back through the now-filtered request row.
- The rollback validation passed with status `t084_pet_fit_e2e_rollback_validation_passed`.
- First match score/reason: `80.00`, `Same city and service location.`
- Second match score/reason: `89.00`, `Same city and service location. Pet-fit evidence: curly coats with positive reviews, poodles with positive reviews, small pets.`
- Structured outcome count: `2`.

## Safety

- The first validation attempt was transaction-scoped and did not reach its final `ROLLBACK`, but the error occurred inside the transaction; the failed query was rolled back by the database session.
- The authorized follow-up completed the script and reached the final `ROLLBACK`.
- Independent residue checks after both attempts confirmed zero T-084 validation rows across `auth.users`, profiles, customer/groomer profiles, pets, grooming requests, request matches, offers, bookings, reviews, and structured review outcomes.
- `git diff --check` passed.

## Result

T-084 is complete. The full rollback-only loop now proves that a completed booking plus structured positive review outcomes can improve the later match reason while RLS and participant visibility boundaries still hold. No migration, schema, RLS, RPC, Storage, iOS, or product behavior change was made.
