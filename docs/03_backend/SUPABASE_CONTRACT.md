# Supabase Contract

## Contract Status

This backend contract is derived from `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`. The T-004 profile/avatar foundation, T-007 atomic profile-onboarding RPC, T-008 pet/photo schema and private bucket, T-010 groomer profile/services/portfolio backend, T-012 grooming request/match backend, T-015 groomer offer backend, T-018 booking/conversation backend, T-020 text-message backend, and T-021 completion/review backend are deployed to the fresh Supabase project and mirrored under `supabase/migrations/`. T-021 review metadata, grants, RLS, RPCs, and rollback-only participant checks are validated under the approved MCP-only boundary. The original project visible through MCP is a legacy project and is not a target for this rebuild.

Once migrations exist, reviewed migrations and verified deployed metadata are authoritative. This document must remain synchronized with them and must never claim a planned object is deployed.

## Environment Boundary

- MCP verification date: 2026-06-21.
- Legacy project: `Prinnyyy's Project`, ref `swdiiyypysyxbnfrxxsv`.
- Legacy project rule: do not inspect, branch, migrate, reset, or mutate; it is not a source for fresh schema or data.
- Fresh project: `Pet Groomer Marketplace`, ref `lqmasbuqzvcvtawonjlb`, organization `Prinnyyy`, region `us-west-1`.
- Project creation: authorized after the user confirmed the MCP-reported US$0/month cost; creation returned `ACTIVE_HEALTHY` on 2026-06-19.
- Verification performed: project baseline; MCP migration application; schema, grants, RLS, trigger, function, and Storage inspection; rollback-only policy/RPC tests; security and performance advisors.
- Applied migrations: `20260620105202_t004_profile_foundation`, `20260620105409_t004_optimize_rls_auth_calls`, `20260620172839_t007_create_my_profile`, corrective `20260620180607_t007_fix_create_my_profile_conflict_target`, `20260620192648_t008_pet_data_photo_storage`, `20260620224418_t010_groomer_profile_portfolio_backend`, corrective `20260620225308_t010_merge_groomer_select_policies`, `20260621000444_t012_grooming_request_match_backend`, corrective `20260621002211_t012_fix_create_grooming_request_conflict_target`, corrective `20260621010315_t012_limit_request_photo_snapshot`, `20260621024848_t015_groomer_offer_backend`, `20260621044424_t018_offer_acceptance_booking_backend`, `20260621055915_t020_booking_participant_chat`, `20260621065954_t021_completion_reviews`, and corrective `20260621070826_t021_fix_create_review_returning_ambiguity`.
- Local credential file: `supabase_api_key` exists, was not read, is Git-ignored, and has no authorization to appear in iOS code or documentation content.

All Supabase migration and validation operations must target only the task-authorized fresh project, remain separate from the legacy ref, and use Supabase MCP exclusively. Remote DDL requires explicit authorization and a reviewed migration; MCP `apply_migration` is the only DDL path.

## Platform Boundaries

- Supabase Auth supplies user identity; application role and ownership live in application tables.
- Postgres stores durable product state.
- RLS and explicit Data API grants jointly control client access.
- Storage uses owner/participant-scoped object paths and `storage.objects` policies.
- The iOS app uses a publishable client key only. Secret/service-role keys are forbidden.

## Tables and Roadmap

`profiles`, `customer_profiles`, base `groomer_profiles`, `pets`, `pet_photos`, T-010 groomer profile details, `groomer_services`, `groomer_portfolio_photos`, `grooming_requests`, `request_matches`, `groomer_offers`, `bookings`, `conversations`, `messages`, and `reviews` are deployed and backend-validated. Every other row remains planned until its owning task applies and verifies a migration.

| Table | Purpose | Key Planned Fields | Access Summary | Roadmap |
|---|---|---|---|---|
| `profiles` | Map Auth user to one app role and shared identity | `id` → Auth user, immutable `role`, `display_name`, private `avatar_path`, timestamps | Owner read/insert; owner updates only display name/avatar path; broader profile presentation deferred | T-004 |
| `customer_profiles` | Customer onboarding role marker and extension point | `user_id`, timestamps | Customer inserts/reads own matching-role row; detail fields deferred | T-004 |
| `groomer_profiles` | Groomer role marker plus marketplace profile details | `user_id`, business name, bio, experience, base city/state, radius, rating summary, active/verified flags, timestamps | Groomer updates own safe profile fields and active flag; authenticated users read active groomer profiles; rating/verification remain server-maintained | T-004, T-010, T-021 |
| `pets` | Customer-owned pet profile | `id`, `customer_id`, identity/details/notes, active/delete markers, timestamps | Customer CRUD for owned rows; groomer access only through authorized request snapshot | T-008 |
| `pet_photos` | Metadata for pet image objects | `id`, `pet_id`, `customer_id`, bucket/path, caption/order/primary, timestamp | Customer-managed for owned pet; direct groomer reads not required | T-008 |
| `groomer_services` | Groomer's offered services | `id`, `groomer_id`, title, description, base price, duration, accepted sizes, active flag, timestamps | Groomer manages own; authenticated users read active services for active groomers | T-010 |
| `groomer_portfolio_photos` | Metadata for groomer portfolio objects | `id`, `groomer_id`, bucket/path, caption/order, timestamp | Groomer manages own; authenticated users read portfolio metadata for active groomers | T-010 |
| `grooming_requests` | Published customer request with frozen pet/photo snapshot | `id`, customer/pet references, snapshots, service/time/location, status/expiry, timestamps | Customer reads own; matched groomer reads only open/offer-eligible assigned requests; direct client writes denied | T-012 |
| `request_matches` | Assignment of an eligible request to a groomer | `id`, request/groomer/customer references, optional score/reason, dismiss reason, status/event timestamps | Groomer reads own match; direct client writes denied; creation and dismissal are controlled | T-012 |
| `groomer_offers` | Groomer's proposed time, price, and message | `id`, request/match/customer/groomer references, proposal, status/expiry, timestamps | Groomer reads own; customer reads offers for owned request; create/withdraw/status transitions controlled | T-015 |
| `bookings` | Durable result of accepted offer | `id`, request/offer/customer/groomer references, scheduled range/prices/status, completion/cancellation audit fields, timestamps | Participants read own; direct client insert and critical status updates denied; completion/cancellation use RPCs | T-018, T-021 |
| `conversations` | Participant boundary created with booking | `id`, optional request, booking/customer/groomer references, timestamps | Booking participants only | T-018 |
| `messages` | Text-only conversation messages | `id`, `conversation_id`, `sender_id`, `body`, timestamp | Conversation participants read; sender must be a participant; update/delete denied to authenticated clients | T-020 |
| `reviews` | One customer review for a completed booking | `id`, unique `booking_id`, customer/groomer references, rating/content, timestamp | Booking participants read through RLS; booked customer creates once through `create_review`; direct authenticated insert/update/delete denied | T-021 |
| `favorites` | Name reserved by the Fresh Brief without a defined flow or fields | No contract approved | No access, migration, repository, or UI authorized | deferred |

## Planned Status Values

| Domain | Values | Implementation Note |
|---|---|---|
| Grooming request | `open`, `has_offers`, `booked`, `cancelled`, `expired` | Client cannot freely update status; transitions follow RPC/controlled mutation rules |
| Request match | `visible`, `viewed`, `dismissed`, `offered`, `hidden`, `expired` | Match creation and system hiding are backend-controlled |
| Groomer offer | `pending`, `accepted_by_customer`, `declined_by_customer`, `withdrawn_by_groomer`, `expired` | Acceptance and competing-offer closure occur atomically |
| Booking MVP | `confirmed`, `completed`, `cancelled_by_customer`, `cancelled_by_groomer` | T-018 writes `confirmed` and cancellation statuses; T-021 writes `completed`; `pending_confirmation`, `in_progress`, `no_show`, and `disputed` are not authorized for MVP behavior |

## Planned Invariants

- One profile role per Auth user; normal UI cannot switch role.
- At most three open requests per customer; a new request defaults to a 48-hour expiry contract.
- Request snapshots do not change when a pet profile changes later.
- At most one match per request/groomer pair.
- At most one active pending offer per request/groomer pair.
- A request and an offer can each create at most one booking.
- Active groomer bookings must not overlap: `start_a < end_b AND start_b < end_a`. Touching boundaries are allowed.
- One conversation is created for the accepted booking flow.
- T-018 booking cancellation does not reopen the original request or any offer; a replacement appointment requires a new request until a future explicit rebooking flow is designed.
- One review per completed booking, written only by its customer.

Exact SQL types, constraints, indexes, cascading behavior, and enum/check implementation are decided and verified in the owning migration task, not invented in this documentation task.

## Deployed RPCs

| Function | Inputs | Result | Verified Contract | Roadmap |
|---|---|---|---|---|
| `create_my_profile` | `p_role user_role`, `p_display_name text` | Caller `id`, authoritative immutable `role`, stored `display_name` | Authenticated non-anonymous caller only; `security invoker`; empty `search_path`; shared profile inserted before matching role marker; same-role retries preserve the first name; different-role retry raises `P0001/profile_role_immutable`; anon has no execute grant | T-007 |
| `create_grooming_request` | `p_pet_id uuid`, service details, preferred range, location | Request ID and match count | Authenticated non-anonymous customer only; `security definer`; empty `search_path`; validates role, pet ownership, active pet state, preferred range, location, and three-open-request limit; freezes pet snapshot and up to 20 pet-photo metadata rows; creates eligible active-groomer matches atomically; direct request/match table writes remain denied to authenticated clients | T-012 |
| `dismiss_request_match` | `p_match_id uuid`, optional reason | Match ID, `dismissed` status, dismissed timestamp | Authenticated non-anonymous groomer only; `security definer`; empty `search_path`; validates role, match ownership, dismissible match status, and open/unexpired request state; only the calling groomer's match changes | T-012 |
| `create_groomer_offer` | `p_request_id uuid`, proposed range, price estimate, optional message | Offer ID, offer status, request status | Authenticated non-anonymous groomer only; `security definer`; empty `search_path`; validates role, visible/viewed match ownership, open/unexpired request state, future proposed range, price bounds/scale, message length, and no active pending offer; creates the offer, marks the match `offered`, and marks the request `has_offers` atomically | T-015 |
| `withdraw_groomer_offer` | `p_offer_id uuid` | Offer ID, offer status, withdrawn timestamp, request status | Authenticated non-anonymous groomer only; `security definer`; empty `search_path`; validates role, offer ownership, pending/withdrawn state, and open/unexpired request state; withdraws the offer, resets the match to `viewed`, and returns the request to `open` when no pending offers remain | T-015 |
| `accept_groomer_offer` | `p_offer_id uuid` | Booking ID, conversation ID, request ID, offer ID, booking/offer/request statuses | Authenticated non-anonymous customer only; `security definer`; empty `search_path`; validates customer role, offer ownership, pending/unexpired offer, open/unexpired request, offered match, booking uniqueness, and confirmed groomer time conflicts; creates one confirmed booking and one conversation, accepts the selected offer, declines competing pending offers, hides matches, and marks the request `booked` atomically | T-018 |
| `cancel_booking` | `p_booking_id uuid` | Booking ID, booking status, cancellation timestamp, cancelling user | Authenticated non-anonymous booking participant only; `security definer`; empty `search_path`; validates customer/groomer role from database state, permits only confirmed booking cancellation, returns already-cancelled participant retries idempotently, rejects `completed`, and does not reopen the request or offers | T-018 |
| `complete_booking` | `p_booking_id uuid` | Booking ID, booking status, completed timestamp, completing groomer | Authenticated non-anonymous booked groomer only; `security definer`; empty `search_path`; validates groomer role, booking ownership, and confirmed status; writes `completed_at`/`completed_by`; already completed retries return the authoritative completed state | T-021 |
| `create_review` | `p_booking_id uuid`, `p_rating integer`, `p_content text` | Review ID, booking/customer/groomer IDs, rating/content, created timestamp, updated groomer rating summary | Authenticated non-anonymous booked customer only; `security definer`; empty `search_path`; validates customer role, booking ownership, completed status, rating range, trimmed content length, and one-review uniqueness; writes `reviews` and updates groomer rating summary atomically | T-021 |

The corrective T-007 migration changes only the profile insert conflict target to the named `profiles_pkey` constraint. T-012 corrective migrations change the request-match insert conflict target to the named `request_matches_request_groomer_key` constraint and cap request photo snapshots at 20 metadata rows. The T-018 migration installs `btree_gist` and adds a `[scheduled_start, scheduled_end)` exclusion constraint for confirmed groomer bookings so overlaps are rejected while boundary-touching times are allowed. The corrective T-021 migration qualifies the `create_review` inserted-row `RETURNING` columns to avoid PL/pgSQL output-variable ambiguity while preserving the reviewed contract and privileges.

## Planned RPCs

No additional RPCs are approved beyond the deployed functions above. Future function signatures, return shapes, security mode, grants, and error codes must be finalized in their owning tasks. Cross-record operations must be atomic and explicitly granted only to intended roles.

## Storage Buckets and Roadmap

`avatars` is deployed by T-004. `pet-photos` is deployed and backend-validated by T-008. `groomer-portfolio` is deployed and backend-validated by T-010. Supabase intentionally requires the Storage API for binary deletion; the approved T-009 remote smoke verified actual authenticated upload/delete integration for pet photos and cleaned up all temporary validation data. Every other bucket remains planned until its owning task applies and verifies its Storage contract.

| Bucket | Default Visibility | Path Contract | Roadmap |
|---|---|---|---|
| `avatars` | Private; owner-only in T-004, with broader authorized presentation deferred | `{user_id}/{file_id}.{allowed_image_extension}` | T-004 |
| `pet-photos` | Private | `{customer_id}/{pet_id}/{file_id}.jpg` | T-008 |
| `groomer-portfolio` | Private bucket; authenticated object reads for active groomer portfolio metadata; owner-writable | `{groomer_id}/{file_id}.jpg` | T-010 |
| `chat-attachments` | Private to conversation participants | `{conversation_id}/{message_id}.jpg` | deferred beyond T-020 |

Object extension is illustrative; implementation tasks must validate allowed MIME types, sizes, generated file IDs, and actual path/metadata consistency. T-020 implements text-only messages and does not deploy a chat attachment bucket.

## Data API Exposure

New Supabase projects may not automatically expose newly created tables to the Data API. Each migration task must explicitly review schema exposure and table/function privileges in addition to enabling RLS. A table with RLS but no required grant is unavailable; a grant without correct RLS is unsafe.

## Client Rules

- Repositories, not SwiftUI views, own queries, RPC calls, and uploads.
- Publishable client keys may be configured in the app; secret/service-role keys may not.
- Client queries remain narrowly scoped even when RLS is present.
- The client does not calculate authoritative matches, accept offers by sequencing direct writes, or locally resolve booking conflicts.
- No runtime fixtures or cached server records act as production fact sources.
