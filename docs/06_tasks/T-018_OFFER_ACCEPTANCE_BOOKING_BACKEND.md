# T-018 — Offer Acceptance and Booking Backend

## Status

- Mode: Deep.
- State: completed.
- Depends on: T-015 offer backend and T-017 customer offer review.
- Authorized Supabase target: `Pet Groomer Marketplace` / `lqmasbuqzvcvtawonjlb` only.
- Legacy project `swdiiyypysyxbnfrxxsv` remains forbidden.

## Goal

Add the backend contract for accepting one groomer offer into one durable booking and one participant conversation.

## Scope

In scope:

- Add `bookings`.
- Add `conversations` as the participant boundary created with a booking.
- Add `accept_groomer_offer`.
- Add `cancel_booking`.
- Enforce one booking per request and one booking per accepted offer.
- Reject overlapping confirmed groomer bookings while allowing boundary-touching time ranges.
- Close competing pending offers and hide matches when a request is booked.
- Add grants, RLS, indexes, triggers, and documentation.

Out of scope:

- Customer acceptance UI, booking lists, booking detail UI, or local iOS model/repository changes.
- Chat `messages`, chat attachments, realtime, push notifications, reviews, payments, or marketplace discovery.
- Reopening a request or offer after booking cancellation.
- Supabase CLI, `npx supabase`, local Supabase stack, direct database tools, or legacy project inspection.

## Migration Record

Applied local mirrors:

- `supabase/migrations/20260621044424_t018_offer_acceptance_booking_backend.sql`

Applied remote migrations:

- Version: `20260621044424`
- Name: `t018_offer_acceptance_booking_backend`

The reviewed SQL draft remains stored at:

- `docs/06_tasks/sql_reviews/T-018_OFFER_ACCEPTANCE_BOOKING_REVIEWED_SQL.sql`

## Contract Summary

### `bookings`

Durable booking created by accepting one pending offer.

Access:

- Customer participant can select own bookings.
- Groomer participant can select own bookings.
- Authenticated clients cannot directly insert, update, or delete bookings.
- Booking creation and cancellation are controlled by RPCs.

Important constraints:

- `request_id` is unique.
- `offer_id` is unique.
- Confirmed groomer bookings have a `btree_gist`-backed exclusion constraint on `[scheduled_start, scheduled_end)`, so overlaps are rejected and touching boundaries are allowed.

### `conversations`

Participant boundary created atomically with booking acceptance.

Access:

- Customer and groomer participants can select their own conversation row.
- Authenticated clients cannot directly insert, update, or delete conversations.
- Message rows are deferred to T-020.

### `accept_groomer_offer`

Signature:

```sql
accept_groomer_offer(p_offer_id uuid)
```

Returns:

- `booking_id`
- `conversation_id`
- `request_id`
- `offer_id`
- `booking_status`
- `offer_status`
- `request_status`

Server checks:

- Authenticated non-anonymous customer.
- Offer belongs to the caller's request.
- Offer is pending and unexpired.
- Request is `open` or `has_offers` and unexpired.
- Match is in `offered` state.
- No booking already exists for the request or offer.
- No confirmed groomer booking overlaps the offer's proposed range.

Atomic effects:

- Creates one confirmed booking.
- Creates one conversation.
- Marks the accepted offer `accepted_by_customer`.
- Marks competing pending offers `declined_by_customer`.
- Hides remaining request matches.
- Marks the request `booked`.

### `cancel_booking`

Signature:

```sql
cancel_booking(p_booking_id uuid)
```

Returns:

- `booking_id`
- `booking_status`
- `cancelled_timestamp`
- `cancelled_by`

Server checks:

- Authenticated non-anonymous booking participant.
- Actor is either the booked customer or booked groomer with the matching app role.
- Only `confirmed` bookings transition to a cancellation status.
- Already cancelled bookings return their current cancellation result for participant retries.
- `completed` bookings are not cancellable.

Cancellation does not reopen requests or offers in T-018. T-019 UI must present cancellation as a final booking outcome for the original request and guide users to create a new request if they need a replacement appointment.

The `completed` booking status is forward-compatible only in T-018. No deployed RPC writes it yet, and `cancel_booking` rejects completed bookings. Completion remains owned by T-021.

## Validation

Completed validation:

1. MCP migration apply passed and migration record `20260621044424` was confirmed.
2. MCP metadata checks verified:
   - `btree_gist` is installed.
   - `bookings` and `conversations` exist with RLS enabled.
   - Each new table has exactly one participant SELECT policy.
   - `authenticated` has SELECT only on the new tables; `service_role` has full table privileges.
   - `anon` and `public` cannot execute the new RPCs; `authenticated` and `service_role` can execute them.
   - `accept_groomer_offer` and `cancel_booking` are `SECURITY DEFINER` with an empty search path.
   - Uniqueness, conversation identity FK, groomer-offer identity FK, and `bookings_no_groomer_time_overlap` exclusion constraint exist.
3. Rollback-only MCP behavior checks passed:
   - Customer can accept own pending offer.
   - Direct authenticated booking insert is denied.
   - Duplicate accept is rejected.
   - Competing pending offer is declined.
   - Request becomes booked and matches are hidden.
   - Booking and conversation are readable only by participants.
   - Overlapping confirmed groomer booking is rejected.
   - Boundary-touching booking is allowed.
   - Customer and groomer participants can cancel confirmed bookings.
   - Non-participant cancellation is rejected.
4. Rollback cleanup confirmed zero persisted T-018 Auth/profile/request/match/offer/booking/conversation validation rows.
5. MCP security advisor returned expected `SECURITY DEFINER` WARNs for the four existing T-012/T-015 RPCs plus the two new T-018 RPCs. This is intentional for controlled multi-row writes while direct table writes remain denied; the RPCs perform explicit identity, role, ownership, status, uniqueness, and conflict checks, use an empty `search_path`, and revoke `PUBLIC`/`anon` execution.
6. MCP performance advisor returned INFOs:
   - Existing T-008/T-012/T-015 composite-FK and unused-index INFOs already reviewed in earlier tasks.
   - New T-018 composite-FK INFOs for `bookings_request_customer_fkey`, `bookings_offer_identity_fkey`, and `conversations_booking_identity_fkey`. They were reviewed as non-blocking because existing unique/leading-column indexes cover the authoritative request, offer, and booking lookup paths; broader composite indexing can be revisited when T-019 client query paths are final.
7. `./scripts/supabase-check.sh` passed.
8. `git diff --check` passed.

Initial rollback validation attempts exposed test-harness issues only: the harness tried to insert generated Auth column `confirmed_at`, used the wrong groomer profile column name, and attempted to discover a non-participant booking ID through RLS. The final corrected rollback batch passed without schema changes.

No iOS build, unit test, or UI test is planned because T-018 is backend-only.

## Closeout

T-018 is complete. Offer acceptance and booking cancellation are available as backend contracts only. Do not start T-019 UI work automatically.
