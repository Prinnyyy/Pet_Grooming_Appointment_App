# T-012 — Grooming Request and Match Backend

## Status

- Mode: Deep.
- State: completed.
- Authorized Supabase target: `Pet Groomer Marketplace` / `lqmasbuqzvcvtawonjlb` only.
- Legacy project `swdiiyypysyxbnfrxxsv` remains forbidden.

## Goal

Add the backend contract for customer grooming requests and groomer request matches.

## Scope

In scope:

- Add `grooming_requests`.
- Add `request_matches`.
- Add request/match status constraints, timestamps, indexes, explicit grants, and RLS.
- Add `create_grooming_request` to atomically create a request and eligible groomer matches.
- Add `dismiss_request_match` so a groomer can privately dismiss only their own match.
- Update backend documentation and durable memory after deployment.

Out of scope:

- iOS request wizard or groomer request feed UI.
- Groomer offers, booking, chat, reviews, favorites, notifications, or payments.
- Complex AI matching, maps, distance calculations, or customer-targeted groomer selection.
- Storage bucket changes or pet-photo download policy changes.
- Supabase CLI, `npx supabase`, local Supabase stack, direct database tools, or legacy project inspection.

## Migration Record

Applied local mirrors:

- `supabase/migrations/20260621000444_t012_grooming_request_match_backend.sql`
- `supabase/migrations/20260621002211_t012_fix_create_grooming_request_conflict_target.sql`
- `supabase/migrations/20260621010315_t012_limit_request_photo_snapshot.sql`

Applied remote migrations:

- Version: `20260621000444`
- Name: `t012_grooming_request_match_backend`
- Version: `20260621002211`
- Name: `t012_fix_create_grooming_request_conflict_target`
- Version: `20260621010315`
- Name: `t012_limit_request_photo_snapshot`

The first corrective migration changes only the `create_grooming_request` conflict target from ambiguous column syntax to the named `request_matches_request_groomer_key` constraint. The second corrective migration caps request `photo_snapshot` generation to the first 20 pet-photo metadata rows ordered by primary flag, sort order, and creation time.

## Contract Summary

### `grooming_requests`

Customer-owned published request with frozen pet and photo snapshots, service details, preferred time window, approximate location, status, expiry, and timestamps.

Access:

- Customer can select own requests.
- Groomer can select a request only through their own active match while the request remains open or offer-eligible and unexpired.
- Authenticated clients cannot directly insert, update, or delete requests.
- Request creation is controlled by `create_grooming_request`.

### `request_matches`

Groomer-specific assignment for an eligible request.

Access:

- Groomer can select own matches.
- Customers do not manage matches.
- Authenticated clients cannot directly insert, update, or delete matches.
- Match creation is controlled by `create_grooming_request`.
- Dismissal is controlled by `dismiss_request_match`.

### `create_grooming_request`

Signature:

```sql
create_grooming_request(
  p_pet_id uuid,
  p_service_type text,
  p_service_notes text,
  p_preferred_start timestamptz,
  p_preferred_end timestamptz,
  p_city text,
  p_state text,
  p_zip_code text
)
```

Returns:

- `request_id`
- `match_count`

Server checks:

- Authenticated non-anonymous customer.
- Pet belongs to caller and is active.
- At most three currently open/offer-eligible unexpired requests per customer.
- Valid service text, preferred time range, and location.
- Frozen pet snapshot and pet-photo metadata snapshot.
- Pet-photo metadata snapshot is capped at 20 rows to match the table constraint.
- Eligible matches are active groomers in the same state or city with at least one active service.

### `dismiss_request_match`

Signature:

```sql
dismiss_request_match(
  p_match_id uuid,
  p_reason text default null
)
```

Returns:

- `match_id`
- `status`
- `dismissed_at`

Server checks:

- Authenticated non-anonymous groomer.
- Match belongs to caller.
- Match is currently dismissible.
- Underlying request is still open/offer-eligible and unexpired.
- Dismissal is private to the groomer.

## Validation

Completed validation:

1. Remote primary migration apply passed and migration record `20260621000444` was confirmed.
2. Remote conflict-target corrective migration apply passed and migration record `20260621002211` was confirmed.
3. Remote photo-snapshot cap corrective migration apply passed and migration record `20260621010315` was confirmed.
4. Tables, columns, constraints, indexes, grants, policies, and function privileges were verified through CLI-backed metadata SQL.
5. Rollback-only remote behavior checks passed:
   - Valid customer request creates one request and expected matches.
   - Pet snapshot and photo snapshot freeze current pet/photo data.
   - Open request limit rejects the fourth active request.
   - Customer cannot create a request for another customer's pet.
   - Customer cannot directly insert a request or match.
   - Groomer can select only their own matched request.
   - Unmatched groomer cannot select the request.
   - Groomer can dismiss own match.
   - Groomer cannot dismiss another groomer's match.
   - Anonymous caller cannot execute either RPC.
6. A rollback-only regression check with 21 pet-photo rows passed: request creation succeeded and stored a 20-item `photo_snapshot`.
7. Rollback cleanup confirmed zero persisted T-012 Auth users, profiles, pets, photos, requests, or matches.
8. Supabase CLI security advisor returned two expected WARNs for authenticated callers executing the T-012 `SECURITY DEFINER` RPCs. This is intentional for controlled multi-row writes while direct table insert/update/delete grants remain denied; both RPCs perform explicit identity, role, ownership, and state checks, use an empty `search_path`, and revoke `PUBLIC`/`anon` execution.
9. Supabase CLI performance advisor returned INFOs:
   - Existing T-008 `pet_photos_pet_owner_fkey` composite-FK advisory, already reviewed in T-008.
   - New T-012 composite-FK index suggestions for `grooming_requests_pet_owner_fkey` and `request_matches_request_customer_fkey`.
   - New T-012 unused-index INFOs expected before T-013/T-014 client queries exercise request flows.
10. `./scripts/supabase-check.sh` passed.
11. `git diff --check` passed.

No iOS build, unit test, or UI test is planned because T-012 is backend-only.

## Closeout

T-012 is complete. Do not start T-013 UI work automatically.
