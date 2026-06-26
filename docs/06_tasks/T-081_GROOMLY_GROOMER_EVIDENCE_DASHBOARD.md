# T-081 - Groomly Groomer Evidence Dashboard

## Status

Backend blocker resolved on 2026-06-26. iOS implementation not resumed.

## Mode

Standard.

## User Request

Start implementing T-081 from the pet-fit evidence closure plan.

## Primary Task

Surface earned pet-fit evidence from `groomer_pet_fit_evidence_summary` in
Groomer Account, showing only aggregate completed counts, review outcomes, and
confidence tiers.

Primary files originally expected:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerProfile.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/GroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`

## Blocker

T-081 cannot be implemented safely as an iOS-only dashboard against the current
`groomer_pet_fit_evidence_summary` view.

The view is correctly configured as `security_invoker=true`, which means direct
client reads must pass the RLS policies of every underlying table. The
completed-booking evidence path joins `bookings` to `grooming_requests` so it
can derive traits from `grooming_requests.pet_snapshot`. The current
`grooming_requests_select_customer_or_matched_groomer` policy lets groomers read
matched requests only while the request is `open` or `has_offers`; accepted
requests are set to `booked`, and completed evidence comes from completed
bookings. That makes the snapshot-derived completed-booking evidence unreliable
for owner-side direct client reads.

Read-only remote metadata check on project `lqmasbuqzvcvtawonjlb` confirmed:

- `groomer_pet_fit_evidence_summary` has `security_invoker=true` and
  `security_barrier=true`.
- `authenticated` has SELECT on the evidence view.
- `grooming_requests_select_customer_or_matched_groomer` still restricts groomer
  request visibility to `status in ('open', 'has_offers')` plus active match
  states.

Per the T-081 execution note, this run stops instead of weakening SwiftUI or
repository assumptions.

## Not Implemented

- No Swift model, repository, Store, or SwiftUI dashboard code was added.
- No Supabase schema, RLS, grant, RPC, Storage, or remote write was performed.
- No customer-facing evidence surface, public directory, direct booking, or
  expertise proof behavior was added.

## Follow-Up

Created and completed Deep backend follow-up:

- `docs/06_tasks/T-081A_GROOMLY_EVIDENCE_DASHBOARD_OWNER_VISIBILITY_BACKEND.md`

That task established `get_my_groomer_pet_fit_evidence_summary()` as the
owner-readable aggregate evidence contract. The iOS dashboard can now resume as
a separate Standard task using that RPC behind `GroomerProfileRepository`.

## Backend Follow-Up Result

T-081A deployed remote migration
`20260626021651_t081a_evidence_dashboard_owner_rpc` to project
`lqmasbuqzvcvtawonjlb`.

The new RPC returns only the authenticated groomer's aggregate T-068 evidence
rows: canonical trait pairs, completed booking counts, structured outcome
counts, safe timestamps, and conservative confidence tiers. It does not expose
raw customer, pet, request, booking, offer, review, content, or `pet_snapshot`
details, and it does not broaden `grooming_requests` RLS.

## Validation

- Supabase changelog reviewed for current Data API/view exposure risks.
- Supabase official docs checked for Data API views, Swift filters, and
  `security_invoker` view/RLS behavior.
- Local T-068/T-012/T-018/T-067 migrations inspected for view columns and
  underlying RLS visibility.
- Read-only remote metadata query confirmed the current view options, SELECT
  grant, and request policy predicate.
- `git diff --check`: passed.

## Closeout

T-081 remains unimplemented in Swift, but its backend visibility blocker is
resolved by T-081A. Resume the Groomer Evidence Dashboard as an iOS Standard task
only when explicitly requested, and query
`get_my_groomer_pet_fit_evidence_summary()` rather than direct-reading the T-068
view for owner dashboard evidence.
