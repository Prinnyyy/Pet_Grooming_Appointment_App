# RLS and RPC Policy

## Current Status

T-004 owner-scoped profile/avatar policies and T-007 `create_my_profile` are deployed and validated. T-008 explicit column grants, owner-scoped `pets`/`pet_photos` RLS, and private pet-photo Storage policies are deployed and backend-validated. T-050 is a local draft migration that keeps those RLS policies and Storage paths, while tightening `pets` field constraints and deriving `size` from `weight_lbs`; it has not been remotely deployed in this run. T-010 groomer profile/services/portfolio grants, RLS, and private portfolio Storage policies are deployed and backend-validated; a corrective migration merged equivalent permissive SELECT policies. T-012 `grooming_requests`, `request_matches`, `create_grooming_request`, and `dismiss_request_match` are deployed and backend-validated; corrective migrations resolved the request-match conflict-target ambiguity and capped request photo snapshots at 20 metadata rows. T-015 `groomer_offers`, `create_groomer_offer`, and `withdraw_groomer_offer` are deployed and backend-validated. T-018 `bookings`, `conversations`, `accept_groomer_offer`, and `cancel_booking` are deployed and backend-validated, including uniqueness, participant RLS, controlled cancellation, competing-offer closure, and confirmed groomer overlap rejection. T-020 `messages` is deployed and backend-validated for text-only participant reads/inserts. T-021 `reviews`, `complete_booking`, and `create_review` are deployed and backend-validated, including participant RLS, groomer-only completion, customer-only completed-booking review creation, duplicate-review rejection, and server-maintained groomer rating summary. T-044 `cancel_grooming_request` is deployed and backend-validated for customer-owned open/offer-state request cancellation. T-049 replaces `create_grooming_request` with fixed-service/location inputs, adds `request_photos` RLS, deploys private `request-photos` Storage policies, and validates metadata/policy/grant shape on project `lqmasbuqzvcvtawonjlb`. T-058 adds `groomer_availability_windows` as a direct table with explicit authenticated grants and owner-only groomer RLS. T-059 adds groomer full-address fields plus canonical multi-select `service_location_modes`, grants authenticated access to the new safe profile columns, keeps the legacy single mode synced by trigger, and replaces `create_grooming_request` matching to check mode membership with legacy fallback. T-060 adds `groomer_booking_preferences` and `groomer_time_off_windows` as direct owner-only tables with explicit authenticated grants and owner-only groomer RLS. T-065 adds private `app_private.pet_fit_*` SQL taxonomy helper functions only; they are `SECURITY INVOKER`, use an empty `search_path`, revoke `anon`/`authenticated` execute, and grant execute only to `service_role`. T-066 adds `groomer_fit_claims` and `groomer_portfolio_fit_tags` with explicit authenticated grants and groomer-owner RLS; corrective migrations keep T-065 helpers private, use table-local canonical trait CHECK constraints, merge SELECT policies, and cover the portfolio-tag composite foreign key. T-067 adds `review_pet_fit_outcomes` with participant SELECT RLS, no anon grant, no authenticated DML grants, and a compatible optional structured-outcomes `create_review` signature. T-068 adds read-only `groomer_pet_fit_evidence_summary` with `security_invoker`, `security_barrier`, authenticated/service_role SELECT grants only, no anon grant, and no direct mutation path. T-069 replaces only `create_grooming_request` internals so the controlled request-creation RPC derives request pet-fit traits, consumes T-068 aggregate evidence from backend context, and writes bounded match scores/reasons without adding RLS, grants, public objects, or direct client write paths. T-071 adds private `app_private.groomer_is_available_for_range` with no `anon`/`authenticated` execute privilege, then replaces only `create_groomer_offer` and `accept_groomer_offer` internals to enforce weekly availability, time off, advance notice, daily capacity, and existing booking conflicts without adding client write paths or changing signatures. T-072 replaces only `create_grooming_request` internals to require the same private availability helper during match creation, without adding RLS, grants, public objects, direct client write paths, or signature changes. T-073 replaces only `create_grooming_request` internals to consume existing T-066 claim/tag rows as capped low-confidence match-scoring signals after hard eligibility and availability checks, without adding RLS, grants, public objects, direct client write paths, or signature changes. The Storage DELETE policies are restricted to `authenticated` and match behavior-tested owner-only predicates. Approved rollback-only checks and remote smokes left zero persisted validation data.

T-012/T-072/T-073, T-015/T-071, T-018/T-071, T-021/T-067, T-044, and T-049/T-059/T-069 intentionally use nine `SECURITY DEFINER` RPCs in `public` so authenticated clients can invoke controlled multi-row writes while direct request/match/offer/booking/conversation/review/review-outcome table inserts, updates, and deletes remain denied. This produces Supabase security advisor WARNs by design. The functions keep an empty `search_path`, revoke `PUBLIC`/`anon` execution, grant only `authenticated`/`service_role`, and perform explicit auth, role, ownership, current-state, range, uniqueness, availability, and conflict checks.

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
| Groomer profile/services/portfolio/availability | read marketplace-safe active profile/service/portfolio data only | manage own profile, services, portfolio, weekly availability rows, booking preferences, time off rows, full base address fields, and profile avatar path/object | Verification/rating summary denied to client; availability preferences/time off are enforced by controlled request matching, offer, and acceptance RPCs, not customer-readable slot discovery; broader customer-facing avatar presentation remains deferred |
| `grooming_requests`, `request_photos` | read own; controlled cancel where specified; upload/delete request photos for owned open requests | read requests/photos only through own active match | Publication/matching/status transitions controlled |
| `request_matches` | no management | read/update own allowed transition via controlled operation | Insert and system statuses denied |
| `groomer_offers` | read for owned request | read own | Create/withdraw/accept/status changes controlled by RPC/approved operation |
| `bookings` | read own | read own | Insert and critical transitions denied |
| `conversations`, `messages` | booking participant only; text message insert as self | booking participant only; text message insert as self | Non-participant access denied; message update/delete denied |
| `reviews` | read own booking review; create once through `create_review` only after completion | read own booking review | Direct insert/update/delete denied to authenticated clients |
| `review_pet_fit_outcomes` | read structured outcomes for own booking reviews | read structured outcomes for own booking reviews | Rows are created only by `create_review`; direct insert/update/delete denied to authenticated clients |
| `groomer_pet_fit_evidence_summary` | read aggregate evidence visible through underlying RLS | read aggregate review evidence visible through underlying RLS | Read-only `security_invoker`/`security_barrier` view; no anon grant; direct insert/update/delete denied |
| `groomer_fit_claims`, `groomer_portfolio_fit_tags` | read active rows for active groomers only | manage own claims/tags; read own inactive claims/tags | Claims/tags are direct owner tables only; T-073 reads them inside controlled matching as low-confidence scoring signals, but they do not create eligibility, proof of expertise, or public directory access |

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
- `create_grooming_request`: creates the request and authorized matches from customer-owned pet data, fixed service type, validated location mode/address/state/ZIP/range, compatible groomer `service_location_modes` membership, active fixed groomer services, groomer availability for the preferred range, and backend-owned location plus pet-fit evidence scoring with capped low-confidence claim/portfolio signals.
- `cancel_grooming_request`: lets the owning customer cancel only `open` or `has_offers` requests, declines pending offers, and hides visible/viewed/offered matches.
- `dismiss_request_match`: changes only the calling groomer's match.
- `create_groomer_offer` / `withdraw_groomer_offer`: enforce match, state, range, availability, conflict, and active-offer rules.
- `accept_groomer_offer`: atomically creates booking/conversation and closes the request and competing offers after rechecking groomer availability.
- `cancel_booking`: applies only an allowed role-specific cancellation transition.
- `messages`: direct insert is allowed only for the authenticated conversation participant as `sender_id`; direct update/delete is denied.
- `complete_booking`: only the booked groomer completes a confirmed booking.
- `create_review`: only the booked customer reviews a completed booking once; optional structured pet-fit outcomes are validated and written atomically with the review.

## Required Negative Tests

- Anonymous callers cannot execute onboarding; anonymous authenticated JWTs are rejected.
- A caller cannot switch an existing profile role or read/update another caller's profile.
- Customer A cannot read or mutate Customer B pets or profile-private data.
- Groomer A cannot read an unmatched request or mutate Groomer B profile/services.
- A customer cannot directly insert a booking or request match, or author match scores/reasons.
- A groomer cannot directly create a booking or accept an offer.
- A non-participant cannot read or insert conversation messages or chat attachments.
- A customer cannot review an incomplete or unrelated booking.
- A booking non-participant cannot read structured review outcomes or T-068 evidence summary rows, and authenticated clients cannot directly insert/update/delete outcome rows or evidence summary rows.
- Direct status edits cannot bypass limits, ownership, uniqueness, or overlap checks.

Official implementation reference: [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).
