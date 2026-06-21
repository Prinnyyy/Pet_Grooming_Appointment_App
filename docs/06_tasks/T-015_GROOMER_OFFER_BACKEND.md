# T-015 — Groomer Offer Backend

## Status

- Mode: Deep.
- State: in progress; reviewed SQL draft prepared, remote DDL pending explicit user approval.
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

## Reviewed SQL Draft

The reviewed SQL draft is stored at:

- `docs/06_tasks/T-015_GROOMER_OFFER_BACKEND_REVIEWED_SQL.sql`

Do not apply it remotely until the user explicitly approves this SQL.

After successful MCP `apply_migration`, save an exact local migration mirror under `supabase/migrations/` using the version/name reported by MCP.

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

## Validation Plan

After approval and MCP migration apply:

1. Confirm the applied migration version/name through MCP `list_migrations`.
2. Verify table, constraints, grants, policies, function definitions, and execute privileges through MCP metadata SQL.
3. Run rollback-only MCP behavior checks:
   - Matched groomer can create one pending offer.
   - Duplicate active offer is rejected.
   - Withdrawn offer allows a new offer.
   - Customer can select offers for own request.
   - Different customer cannot select the offer.
   - Unmatched groomer cannot create an offer.
   - Customer cannot directly insert an offer.
   - Anonymous caller cannot execute either RPC.
4. Confirm rollback cleanup left zero persisted T-015 validation rows.
5. Run MCP security/performance advisors if available through the connector.
6. Run `./scripts/supabase-check.sh`.
7. Run `git diff --check`.

No iOS build, unit test, or UI test is planned because T-015 is backend-only.
