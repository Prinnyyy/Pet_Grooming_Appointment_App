# RLS and RPC Policy

## Current Status

T-004 owner-scoped profile/avatar policies and T-007 `create_my_profile` are deployed and validated. T-008 explicit column grants, owner-scoped `pets`/`pet_photos` RLS, and private pet-photo Storage policies are also deployed and backend-validated. The Storage DELETE policy is restricted to `authenticated` and exactly matches the behavior-tested owner-only SELECT predicate; actual object deletion uses the Storage API and is exercised by T-009. T-008 security advisor returned no lints. Later resource rules remain planned requirements rather than proof of deployment.

## RLS Baseline

- Enable RLS on every table in an exposed schema.
- Use explicit `TO authenticated` or `TO anon` policy roles and add ownership/relationship predicates; role membership alone is not authorization.
- Treat `auth.uid()` as nullable and require authenticated identity where ownership is expected.
- Use both `USING` and `WITH CHECK` for ownership-sensitive updates, with a matching select policy where updates require row visibility.
- Index ownership and relationship columns used by policies when the owning schema task verifies the access path.
- Never use user-editable Auth `user_metadata` as an authorization source.
- Views exposed to clients must obey underlying RLS, such as with `security_invoker`, or be kept out of exposed schemas and revoked from client roles.

## Data API Grants

RLS controls rows after a request can access a relation; Postgres grants control whether `anon` or `authenticated` can access the relation at all. Every schema task must review and test both layers. Do not assume a new table is automatically available through the Data API.

## Planned Access Matrix

| Resource | Customer | Groomer | Direct Critical Writes |
|---|---|---|---|
| Own `profiles`/role profile | read/update owned safe fields | read/update owned safe fields | Role changes denied after onboarding except a future privileged process |
| `pets`, `pet_photos` | CRUD owned active records | no general direct access | Ownership reassignment denied |
| Groomer profile/services/portfolio | read marketplace-safe active data | manage own | Verification/rating summary denied to client |
| `grooming_requests` | read own; controlled cancel where specified | read only through own active match | Publication/matching/status transitions controlled |
| `request_matches` | no management | read/update own allowed transition via controlled operation | Insert and system statuses denied |
| `groomer_offers` | read for owned request | read own | Create/withdraw/accept/status changes controlled by RPC/approved operation |
| `bookings` | read own | read own | Insert and critical transitions denied |
| `conversations`, `messages` | booking participant only | booking participant only | Non-participant access denied |
| `reviews` | read permitted marketplace result; create only when eligible | read applicable review result | Insert/update eligibility controlled |

## RPC Requirements

Use RPCs for multi-row writes, status transitions, role/ownership validation that must not be bypassed, limits, conflict protection, and atomic operations.

Each RPC must:

1. Reject unauthenticated callers.
2. Resolve role/ownership from trusted database state, not client payload or user-editable metadata.
3. Validate current status and all input ranges/limits.
4. Lock or constrain rows where concurrency could violate uniqueness.
5. Commit every required change atomically or none.
6. Return a stable typed result/error contract documented for the iOS repository.
7. Have explicit execute privileges for only the intended caller role.

Prefer invoker security when it can satisfy the operation. If a function genuinely requires `SECURITY DEFINER`, place privileged helpers outside exposed schemas, set a safe search path, revoke default `PUBLIC` execute, grant narrowly, perform explicit identity/ownership checks, and verify with security advisors. Never add definer security merely to bypass an RLS error.

## Controlled Operations

- `create_my_profile`: creates the authenticated non-anonymous caller's shared profile and exactly one matching role marker atomically; role changes are rejected and same-role retries preserve the stored name.
- `create_grooming_request`: creates the request and authorized matches from customer-owned pet data.
- `dismiss_request_match`: changes only the calling groomer's match.
- `create_groomer_offer` / `withdraw_groomer_offer`: enforce match, state, range, conflict, and active-offer rules.
- `accept_groomer_offer`: atomically creates booking/conversation and closes the request and competing offers.
- `cancel_booking`: applies only an allowed role-specific cancellation transition.
- `complete_booking`: only the booked groomer completes a confirmed booking.
- `create_review`: only the booked customer reviews a completed booking once.

## Required Negative Tests

- Anonymous callers cannot execute onboarding; anonymous authenticated JWTs are rejected.
- A caller cannot switch an existing profile role or read/update another caller's profile.
- Customer A cannot read or mutate Customer B pets or profile-private data.
- Groomer A cannot read an unmatched request or mutate Groomer B profile/services.
- A customer cannot directly insert a booking or request match.
- A groomer cannot directly create a booking or accept an offer.
- A non-participant cannot read conversation messages or chat attachments.
- A customer cannot review an incomplete or unrelated booking.
- Direct status edits cannot bypass limits, ownership, uniqueness, or overlap checks.

Official implementation reference: [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).
