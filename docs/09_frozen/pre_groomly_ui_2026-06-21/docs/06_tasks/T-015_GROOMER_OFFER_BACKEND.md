# T-015 — Groomer Offer Backend

## Status

- Mode: Deep.
- State: completed.
- Authorized Supabase target: `Pet Groomer Marketplace` / `lqmasbuqzvcvtawonjlb` only.
- Legacy project `swdiiyypysyxbnfrxxsv` remains forbidden.

## Goal

Add the backend contract for groomer offers.

## Scope

In scope:

- Add `groomer_offers`.
- Add offer status constraints, timestamps, indexes, explicit grants, and RLS.
- Add `create_groomer_offer` so a matched groomer can submit one active pending offer for an eligible request.
- Add `withdraw_groomer_offer` so a groomer can withdraw their own pending offer and later submit a new one.
- Update backend documentation and durable memory after deployment.

Out of scope:

- iOS offer form, customer offer list, offer comparison, or offer acceptance UI.
- `bookings`, `conversations`, chat, reviews, notifications, payments, or marketplace discovery.
- Booking conflict checks that require the future `bookings` table.
- Supabase CLI, `npx supabase`, local Supabase stack, direct database tools, or legacy project inspection.

## Migration Record

Applied local mirrors:

- `supabase/migrations/20260621024848_t015_groomer_offer_backend.sql`

Applied remote migrations:

- Version: `20260621024848`
- Name: `t015_groomer_offer_backend`

The reviewed SQL draft remains stored at:

- `docs/06_tasks/T-015_GROOMER_OFFER_BACKEND_REVIEWED_SQL.sql`

## Contract Summary

### `groomer_offers`

Groomer-owned offer linked to one customer request and one request match. It stores proposed time, estimated price, optional message, status, expiry, and timestamps.

Access:

- Customer can select offers for their own requests.
- Groomer can select their own offers.
- Authenticated clients cannot directly insert, update, or delete offers.
- Offer creation and withdrawal are controlled by RPCs.

### `create_groomer_offer`

Signature:

```sql
create_groomer_offer(
  p_request_id uuid,
  p_proposed_start timestamptz,
  p_proposed_end timestamptz,
  p_price_estimate numeric,
  p_message text default null
)
```

Returns:

- `offer_id`
- `offer_status`
- `request_status`

Server checks:

- Authenticated non-anonymous groomer.
- Caller has a visible or viewed match for the request.
- Request is `open` or `has_offers` and unexpired.
- Proposed range is future and valid.
- Price is non-negative, within the task cap, and has at most two decimals.
- Optional message is normalized and length-limited.
- No existing active pending offer for the same request/groomer pair.
- Creates the offer, marks the match `offered`, and marks the request `has_offers` atomically.

### `withdraw_groomer_offer`

Signature:

```sql
withdraw_groomer_offer(p_offer_id uuid)
```

Returns:

- `offer_id`
- `offer_status`
- `withdrawn_timestamp`
- `request_status`

Server checks:

- Authenticated non-anonymous groomer.
- Offer belongs to caller.
- Offer is pending, or already withdrawn for idempotent retry.
- Request is still open/offer-eligible and unexpired.
- Withdraws the offer, resets the match to `viewed`, and returns the request to `open` if no pending offers remain.

## Validation

Completed validation:

1. MCP migration apply passed and migration record `20260621024848` was confirmed.
2. MCP metadata checks verified:
   - `groomer_offers` exists with RLS enabled and exactly one participant SELECT policy.
   - `request_matches_identity_key` exists to support the composite offer FK.
   - `groomer_offers` constraints include primary key, request/customer FK, match identity FK, price check, and status check.
   - `authenticated` has SELECT only on `groomer_offers`; `service_role` has full table privileges.
   - `anon` and `public` cannot execute the offer RPCs; `authenticated` and `service_role` can execute them.
   - Both offer RPCs are `SECURITY DEFINER` with an empty search path.
3. Rollback-only MCP behavior checks passed:
   - Matched groomer can create one pending offer.
   - Duplicate active offer is rejected.
   - Withdrawn offer allows a new offer.
   - Customer can select offers for own request.
   - Different customer cannot select the offer.
   - Unmatched groomer cannot create an offer.
   - Customer cannot directly insert an offer.
   - Anonymous caller cannot execute either RPC.
4. Rollback cleanup confirmed zero persisted T-015 request and offer validation rows.
5. MCP security advisor returned expected `SECURITY DEFINER` WARNs for the two T-012 RPCs plus the two T-015 offer RPCs. This is intentional for controlled multi-row writes while direct table insert/update/delete grants remain denied; the RPCs perform explicit identity, role, ownership, current-state, and range checks, use an empty `search_path`, and revoke `PUBLIC`/`anon` execution.
6. MCP performance advisor returned INFOs:
   - Existing T-008/T-012 composite-FK and unused-index INFOs already reviewed in earlier tasks.
   - New T-015 composite-FK INFOs for `groomer_offers_request_customer_fkey` and `groomer_offers_match_identity_fkey`.
   - New T-015 unused-index INFO for `groomer_offers_match_idx`, expected before T-016/T-017 client query paths exercise offers.
7. `./scripts/supabase-check.sh` passed.
8. `git diff --check` passed.

No iOS build, unit test, or UI test is planned because T-015 is backend-only.

## Closeout

T-015 is complete. Do not start T-016 UI work automatically.
