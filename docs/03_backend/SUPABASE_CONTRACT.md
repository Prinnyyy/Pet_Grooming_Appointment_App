# Supabase Contract

## Contract Status

This is the planned backend contract derived from `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`. The project visible through MCP is a legacy project and is not a target for this rebuild. A separate fresh Supabase project has not yet been created or selected, the repository has no local Supabase configuration or migration files, and no T-004 schema change has been applied.

Once migrations exist, reviewed migrations and verified deployed metadata are authoritative. This document must remain synchronized with them and must never claim a planned object is deployed.

## Environment Boundary

- MCP verification date: 2026-06-19.
- Legacy project: `Prinnyyy's Project`, ref `swdiiyypysyxbnfrxxsv`.
- Legacy project rule: do not inspect, branch, migrate, reset, or mutate; it is not a source for fresh schema or data.
- Fresh project: not created or selected.
- Verification performed: read-only project listing only.
- Not performed: key retrieval, SQL execution, schema/table/migration inspection, advisors, DDL, Storage changes, or any other remote write.
- Local credential file: `supabase_api_key` exists, was not read, is Git-ignored, and has no authorization to appear in iOS code or documentation content.

Future T-004 work must first create or explicitly select a new project, record its new ref, and keep every migration and validation target separate from the legacy ref. Project creation requires user-approved organization and cost confirmation; remote DDL still requires explicit authorization and a reviewed migration strategy.

## Platform Boundaries

- Supabase Auth supplies user identity; application role and ownership live in application tables.
- Postgres stores durable product state.
- RLS and explicit Data API grants jointly control client access.
- Storage uses owner/participant-scoped object paths and `storage.objects` policies.
- The iOS app uses a publishable client key only. Secret/service-role keys are forbidden.

## Planned Tables

| Table | Purpose | Key Planned Fields | Access Summary | Roadmap |
|---|---|---|---|---|
| `profiles` | Map Auth user to one app role and public identity | `id` → Auth user, `role`, `display_name`, `avatar_url`, timestamps | Owner read/update; narrowly defined authenticated profile reads only when a feature requires them | T-004 |
| `customer_profiles` | Customer location/default service context | `user_id`, `city`, `state`, `zip_code`, `default_notes`, timestamps | Customer owns row; not generally groomer-readable | T-004 |
| `groomer_profiles` | Groomer business and marketplace summary | `user_id`, business/bio/experience/location/radius, rating summary, active/verified flags, timestamps | Owner update; authenticated read limited to active data needed for matching/offers | T-004, T-010, T-021 |
| `pets` | Customer-owned pet profile | `id`, `customer_id`, identity/details/notes, active/delete markers, timestamps | Customer CRUD for owned rows; groomer access only through authorized request snapshot | T-008 |
| `pet_photos` | Metadata for pet image objects | `id`, `pet_id`, `customer_id`, bucket/path, caption/order/primary, timestamp | Customer-managed for owned pet; direct groomer reads not required | T-008 |
| `groomer_services` | Groomer's offered services | `id`, `groomer_id`, title/description/price/duration/sizes/active, timestamps | Groomer manages own; authenticated reads only as product flow requires | T-010 |
| `groomer_portfolio_photos` | Metadata for groomer portfolio objects | `id`, `groomer_id`, bucket/path, caption/order, timestamp | Groomer manages own; authenticated customers may read active groomer portfolio | T-010 |
| `grooming_requests` | Published customer request with frozen pet/photo snapshot | `id`, customer/pet references, snapshots, service/time/location, status/expiry, timestamps | Customer reads own; matched groomer reads only through an authorized match; client status transitions restricted | T-012 |
| `request_matches` | Assignment of an eligible request to a groomer | `id`, request/groomer/customer references, optional score/reason, status/event timestamps | Groomer reads/acts on own match; customer does not manage matches; creation is backend-controlled | T-012 |
| `groomer_offers` | Groomer's proposed time, price, and message | `id`, request/match/customer/groomer references, proposal, status/expiry, timestamps | Groomer reads own; customer reads offers for owned request; create/withdraw/status transitions controlled | T-015 |
| `bookings` | Durable result of accepted offer | `id`, request/offer/customer/groomer references, scheduled range/prices/status, timestamps | Participants read own; direct client insert and critical status updates denied | T-018 |
| `conversations` | Participant boundary created with booking | `id`, optional request, booking/customer/groomer references, timestamps | Booking participants only | T-018 |
| `messages` | Conversation messages and optional attachment metadata | `id`, `conversation_id`, `sender_id`, type/body/bucket/path, timestamps | Conversation participants read; sender must be a participant | T-020 |
| `reviews` | One customer review for a completed booking | `id`, unique `booking_id`, customer/groomer references, rating/content, timestamp | Eligible customer creates through RPC; intended marketplace reads defined with T-021 | T-021 |
| `favorites` | Name reserved by the Fresh Brief without a defined flow or fields | No contract approved | No access, migration, repository, or UI authorized | deferred |

## Planned Status Values

| Domain | Values | Implementation Note |
|---|---|---|
| Grooming request | `open`, `has_offers`, `booked`, `cancelled`, `expired` | Client cannot freely update status; transitions follow RPC/controlled mutation rules |
| Request match | `visible`, `viewed`, `dismissed`, `offered`, `hidden`, `expired` | Match creation and system hiding are backend-controlled |
| Groomer offer | `pending`, `accepted_by_customer`, `declined_by_customer`, `withdrawn_by_groomer`, `expired` | Acceptance and competing-offer closure occur atomically |
| Booking MVP | `confirmed`, `completed`, `cancelled_by_customer`, `cancelled_by_groomer` | `pending_confirmation`, `in_progress`, `no_show`, and `disputed` are reserved but not authorized for MVP behavior |

## Planned Invariants

- One profile role per Auth user; normal UI cannot switch role.
- At most three open requests per customer; a new request defaults to a 48-hour expiry contract.
- Request snapshots do not change when a pet profile changes later.
- At most one match per request/groomer pair.
- At most one active pending offer per request/groomer pair.
- A request and an offer can each create at most one booking.
- Active groomer bookings must not overlap: `start_a < end_b AND start_b < end_a`. Touching boundaries are allowed.
- One conversation is created for the accepted booking flow.
- One review per completed booking, written only by its customer.

Exact SQL types, constraints, indexes, cascading behavior, and enum/check implementation are decided and verified in the owning migration task, not invented in this documentation task.

## Planned RPCs

| Function | Inputs | Result | Required Server Checks | Roadmap |
|---|---|---|---|---|
| `create_grooming_request` | pet, service details, preferred range, location | Request ID and match count | Customer role; pet ownership; valid range; open-request limit; snapshots; request/match creation | T-012 |
| `dismiss_request_match` | match ID, optional reason | Updated match result | Groomer role; match ownership; valid current status | T-012 |
| `create_groomer_offer` | request ID, proposed range, price, optional message | Offer ID | Groomer role; assigned active match; request state; valid range/price; no active conflict; offer limit | T-015 |
| `withdraw_groomer_offer` | offer ID | Updated offer result | Groomer owns pending offer; request remains eligible | T-015 |
| `accept_groomer_offer` | offer ID | Booking ID | Customer owns request; pending offer/current request; booking uniqueness; conflict recheck; atomic booking/conversation/status updates | T-018 |
| `cancel_booking` | booking ID, actor-intended cancellation | Updated booking result | Participant identity; role-specific transition; current cancellable status | T-018/T-019 |
| `complete_booking` | booking ID | Updated booking result | Booked groomer; confirmed status; valid transition | T-021 |
| `create_review` | booking ID, rating, content | Review ID | Booked customer; completed booking; rating validity; uniqueness | T-021 |

Function signatures, return shapes, security mode, grants, and error codes are finalized in their owning tasks. Cross-record operations must be atomic and explicitly granted only to intended roles.

## Planned Storage Buckets

| Bucket | Default Visibility | Path Contract | Roadmap |
|---|---|---|---|
| `avatars` | Private; authenticated reads only when profile presentation requires them | `{user_id}/{file_id}.jpg` | T-004 |
| `pet-photos` | Private | `{customer_id}/{pet_id}/{file_id}.jpg` | T-008 |
| `groomer-portfolio` | Authenticated-readable, owner-writable | `{groomer_id}/{file_id}.jpg` | T-010 |
| `chat-attachments` | Private to conversation participants | `{conversation_id}/{message_id}.jpg` | T-020 |

Object extension is illustrative; implementation tasks must validate allowed MIME types, sizes, generated file IDs, and actual path/metadata consistency.

## Data API Exposure

New Supabase projects may not automatically expose newly created tables to the Data API. Each migration task must explicitly review schema exposure and table/function privileges in addition to enabling RLS. A table with RLS but no required grant is unavailable; a grant without correct RLS is unsafe.

## Client Rules

- Repositories, not SwiftUI views, own queries, RPC calls, and uploads.
- Publishable client keys may be configured in the app; secret/service-role keys may not.
- Client queries remain narrowly scoped even when RLS is present.
- The client does not calculate authoritative matches, accept offers by sequencing direct writes, or locally resolve booking conflicts.
- No runtime fixtures or cached server records act as production fact sources.
