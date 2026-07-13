# RLS and RPC Policy

This is the active access-control policy index. It records current rules, not deployment history.

Archived pre-trim version: `../09_frozen/backend_policies/RLS_RPC_POLICY_2026-07-02_PRE_INDEX_TRIM.md`.

## Current Contract

- RLS and explicit grants are both required. RLS controls rows; grants control relation/function access.
- Auth identity comes from Supabase Auth. App role, ownership, and participant relationships come from database rows, not user-editable metadata.
- iOS uses repositories/services for all Supabase reads, RPC calls, and uploads. SwiftUI views must not call Supabase directly.
- Critical multi-row writes and status transitions use controlled RPCs. Direct table writes are denied where they could bypass ownership, status, limits, uniqueness, matching, booking, review, or evidence rules.
- Public controlled RPCs use `SECURITY INVOKER` API wrappers with a safe search path and explicit execute grants.
- Privileged `SECURITY DEFINER` logic lives under `app_private`, performs explicit auth/role/ownership/status checks, revokes broad execution, and is reached only through controlled wrappers or trigger/service-role paths.

## Access Matrix

| Resource | Customer | Groomer | Direct Critical Writes |
|---|---|---|---|
| `profiles`, `customer_profiles`, `groomer_profiles` | Own safe profile/contact/avatar fields | Own safe profile/business/avatar fields | Role changes denied after onboarding except future privileged process |
| `pets`, `pet_photos` | CRUD owned active pets/photos | No general direct access | Ownership reassignment denied |
| Groomer services, portfolio, availability, preferences, time off | Marketplace-safe active reads where intended | Manage own rows | Availability/preferences enforced by matching/offer/acceptance RPCs |
| `grooming_requests`, `request_photos` | Read own; create/cancel through controlled path; upload owned open request photos | Read only through active match | Publication, matching, and status transitions controlled |
| `request_matches` | Read offered match evidence for own requests only | Read/update own allowed match state | Insert/system statuses denied |
| `groomer_offers` | Read offers on owned requests; accept one through RPC | Create/withdraw own offers through RPC | Offer status transitions controlled |
| `bookings` | Participant read; allowed cancellation/review path | Participant read; allowed cancellation/completion path | Insert and critical transitions controlled |
| `conversations`, `messages` | Participant-pair conversation and related booking-event reads only | Participant-pair conversation and related booking-event reads only | Authenticated inserts are self-authored text only; booking cards are RPC-authored; update/delete denied |
| `customer_notifications` | Read own; update own read state; mark-read RPCs | No direct access | Inserts and push state are system/service-role paths |
| `groomer_notifications` | No direct access | Read own; update own read state; mark-read RPCs | Inserts are system trigger paths |
| `customer_booking_handoff_acknowledgements` | Read/acknowledge own confirmed booking handoff | No direct access | Insert through acknowledgement path only |
| `customer_push_tokens` | Register/unregister own device tokens through RPC | No access | Push claim/delivery updates are service-role only |
| `reviews`, `review_pet_fit_outcomes` | Create one review through RPC for own completed booking; read own | Read own booking review/outcomes | Direct outcome DML denied |
| `account_deletion_requests` | Read own deletion request; request deletion through RPC | Read own deletion request; request deletion through RPC | Auth soft-delete/failure recording is service-role only |
| `app_private.address_locations` | No direct table access; current-owner profile address through controlled RPC | No direct table access; current-owner profile address through controlled RPC | Exact coordinates/Place IDs remain private; profile/Request writes are atomic; backfill and tagged TestOps cleanup are service-role only |
| Evidence summary and fit claims/tags | No owner dashboard contract | Manage own claims/tags; read own aggregate evidence through owner RPC | Claims/tags are low-confidence signals only and do not create eligibility |

## Controlled Operations

Public controlled RPCs currently include:

- `create_my_profile`
- `create_grooming_request_v2`
- `get_my_customer_profile_address_v2`
- `save_customer_profile_address_v2`
- `get_my_groomer_profile_address_v2`
- `save_groomer_profile_address_v2`
- `cancel_grooming_request`
- `dismiss_request_match`
- `create_groomer_offer`
- `withdraw_groomer_offer`
- `accept_groomer_offer`
- `cancel_booking`
- `complete_booking`
- `create_review`
- `get_my_groomer_pet_fit_evidence_summary`
- `mark_customer_notification_read`
- `mark_all_customer_notifications_read`
- `mark_groomer_notification_read`
- `mark_all_groomer_notifications_read`
- `get_acknowledged_booking_handoff_request_ids`
- `acknowledge_booking_handoff`
- `register_customer_push_token`
- `unregister_customer_push_token`
- `request_account_deletion`

These operations must reject unauthenticated callers, resolve role and ownership from trusted database state, validate current status and inputs, lock or constrain rows where concurrency matters, commit atomically, return stable typed results/errors, and expose execute privileges only to intended roles. The retired pre-coordinate `create_grooming_request` wrapper has no client execute grant. Service-role-only operations include address backfill list/write/summary, exact-tag TestOps request-location cleanup, push claim/delivery recording, and account-deletion Auth finalization/failure recording.

## Required Negative Tests

Every backend access change must cover the relevant negative cases:

- Anonymous callers cannot execute onboarding or controlled RPCs.
- A user cannot switch role, read/update another user's private profile, or reassign ownership.
- Customers cannot read another customer's pets, private request data, bookings, reviews, or unoffered match evidence.
- Groomers cannot read unmatched requests or manage another groomer's profile, services, portfolio, availability, claims, tags, or evidence dashboard.
- Direct request, match, offer, booking, review, evidence, and outcome writes cannot bypass controlled RPC rules.
- Non-participants cannot read or insert conversation messages.
- Authenticated participants cannot forge `booking_card` rows or set message kinds/booking references directly; acceptance and first cancellation insert one live card followed by actor-authored text without duplicate pair conversations.
- Customers cannot review incomplete, unrelated, or already reviewed bookings.
- Customers cannot read another customer's notifications, push tokens, handoff acknowledgements, or account deletion request.
- Groomers cannot read another groomer's notifications or create notification rows directly.
- Authenticated users cannot execute service-role push delivery or account deletion finalization RPCs.
- Authenticated users cannot execute address backfill or tagged TestOps private-location cleanup RPCs.
- Authenticated users cannot execute the retired pre-coordinate Request publication RPC.
- Storage metadata and table predicates must agree with bucket object policies when files are involved.

Current chat migration/RLS evidence: `../06_tasks/sql_reviews/T-351_PARTICIPANT_CHAT_ROLLBACK_VALIDATION.sql` plus `../../tests/migrations/participant-chat-booking-events.test.mjs`. Notification evidence remains `../06_tasks/sql_reviews/T-220_NOTIFICATION_RLS_NEGATIVE_CONTRACT.sql` plus `../../tests/migrations/notification-rls-negative-contract.test.mjs`.

## Update Rules

- Exact SQL, signatures, constraints, policies, grants, and function bodies belong in `../../supabase/migrations/`.
- Update this file only when the active access contract changes.
- Put long migration narratives in task closeout or frozen archives, not here.

Official reference: [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).
