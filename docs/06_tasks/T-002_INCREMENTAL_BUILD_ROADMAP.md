# T-002 — Incremental Build Roadmap

## Status

Completed on 2026-06-19.

## Purpose

Turn the Fresh Pet Groomer Marketplace brief into a sequence of small, independently verifiable tasks. This roadmap does not authorize implementation of later tasks; each task requires a separate user instruction and a just-in-time intake file.

## Sources and Precedence

1. `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` is the canonical product and engineering source.
2. `docs/00_memory/CURRENT_STATE.md` records the implemented state.
3. This roadmap controls implementation order and task boundaries.
4. Feature-specific product, architecture, and backend documents become authoritative only after T-003 aligns them with the Fresh Brief.

## Current Baseline

- T-001 is complete: the Swift 6/iOS 18 SwiftUI app, explicit entry routing, role tab shells, design tokens, and test targets exist.
- Production launch shows the authentication bootstrap.
- No Supabase dependency, configuration, migration, schema, RPC, RLS, Storage integration, persistence, or product workflow exists.
- The worktree was clean when T-002 started.

## Documentation Alignment Status

T-003 resolved the placeholder product/navigation/screen documents, standardized the Customer and Groomer roles, replaced runtime fixture adapters with preview/test-only rules, and documented the planned tables, RPCs, Storage paths, grants, and RLS boundaries. These contracts describe intended behavior; T-004 and later tasks must still implement and verify them.

## Execution Rules

- Run exactly one roadmap task per Codex run and stop after its acceptance checks.
- Create the task intake file only when that task starts; do not pre-create T-003 through T-022 files.
- Do not start an adjacent task to repair, polish, or complete the next layer.
- Backend, Auth, Storage, RLS, and atomic transaction tasks use Deep Mode with an explicit validation plan.
- Mock data is limited to previews and tests. Production paths must never report fake backend success.
- No dependency addition, remote mutation, commit, or push occurs without explicit authorization for that run.

## Phase A — Documentation and Platform Foundation

### T-003 — Canonical Documentation Alignment

- **Mode:** Quick.
- **Depends on:** T-002.
- **Goal:** Rewrite the active product, role, navigation, screen, architecture, data-flow, backend-contract, Storage, and RLS documents around Open Request → Groomer Offer → Customer Confirmation → Booking.
- **Boundary:** Documentation only; no Swift, Xcode, migration, or remote Supabase changes. Replace runtime demo guidance with preview/test fixtures only.
- **Acceptance:** Active documents contain no unresolved placeholders or old direct Task Card/Service Provider model, and identify the Fresh Brief as canonical.
- **Validation:** `./scripts/preflight.sh` plus a targeted stale-term scan.
- **Stop:** Stop after documentation and memory updates; do not initialize Supabase.

### T-004 — Supabase Profile Foundation

- **Mode:** Deep.
- **Depends on:** T-003.
- **Goal:** Establish local Supabase scaffolding and the profile foundation required by Auth onboarding.
- **Boundary:** Create or select a brand-new Supabase project for the fresh rebuild; never use the visible legacy project. Add only role/profile types, `profiles`, `customer_profiles`, `groomer_profiles`, the private-by-default `avatars` bucket, baseline RLS/Storage policies, migration conventions, and matching backend-contract documentation. Do not add pets, requests, offers, or bookings.
- **Acceptance:** Authenticated users can access only their permitted profile records and avatar paths; privileged keys are absent from client-facing files.
- **Validation:** Explicit backend plan including `./scripts/supabase-check.sh` and profile RLS positive/negative checks.
- **Stop:** Stop if a fresh project, organization/cost confirmation, or migration target is not explicitly authorized. Otherwise stop after the profile contract and migration validate; do not add the iOS SDK.

### T-005 — iOS Supabase Client and Session Boundary

- **Mode:** Deep.
- **Depends on:** T-004.
- **Goal:** Add the approved Supabase Swift dependency, non-secret environment configuration, client composition, and session repository boundary.
- **Boundary:** Infrastructure only. Keep the authentication placeholder; do not add sign-in, sign-up, onboarding, or product screens.
- **Acceptance:** The app builds with safe configuration handling, missing configuration fails visibly, and no service-role key or hard-coded credential exists.
- **Validation:** Explicit dependency/configuration review and one `./scripts/ios-build.sh` attempt.
- **Stop:** Stop with infrastructure wired but no user-authentication behavior.

## Phase B — Authentication and Role Entry

### T-006 — Email and Password Authentication

- **Mode:** Deep.
- **Depends on:** T-005.
- **Goal:** Implement sign-up, sign-in, sign-out, session restoration, loading, validation, and visible authentication errors.
- **Boundary:** Authentication only; users without a profile remain at an explicit onboarding-required route. Do not create role profiles here.
- **Acceptance:** A user can create a session, restore it after launch, sign out, and recover from invalid credentials without fake success.
- **Validation:** Explicit Auth test plan plus one iOS build attempt; no UI tests unless launch routing changes require them.
- **Stop:** Stop when session state is reliable; do not implement role selection.

### T-007 — Role Onboarding and Authenticated Routing

- **Mode:** Deep.
- **Depends on:** T-006.
- **Goal:** Let a new user select Customer or Groomer, create the corresponding profile safely, and enter the correct tab shell.
- **Boundary:** Role/profile creation and root routing only. Do not implement detailed customer, pet, or groomer profile forms.
- **Acceptance:** Missing profile routes to onboarding; Customer and Groomer profiles route to their own shells; a failed profile write remains visible and retryable.
- **Validation:** Profile/RLS checks plus iOS build and focused routing tests defined in the task intake.
- **Stop:** Stop after role-based entry works; do not add profile-management features.

## Phase C — Customer Pets and Groomer Profiles

### T-008 — Pet Data and Photo Storage Contract

- **Mode:** Deep.
- **Depends on:** T-007.
- **Goal:** Add `pets`, `pet_photos`, pet-photo Storage paths, ownership rules, and RLS.
- **Boundary:** Backend contract and migrations only; no pet-management UI.
- **Acceptance:** Customers can manage only their own pets and photo objects; groomers cannot browse unrelated pet records.
- **Validation:** `./scripts/supabase-check.sh` with pet/table/Storage RLS positive and negative cases.
- **Stop:** Stop after the backend contract validates; do not create Swift pet screens.

### T-009 — Customer Pet Management

- **Mode:** Standard.
- **Depends on:** T-008.
- **Goal:** Implement pet list, create/edit form, photo upload, and visible loading/empty/error states through repository boundaries.
- **Boundary:** Customer pet management only; no grooming request creation.
- **Acceptance:** A customer can create, read, update, and display an owned pet and upload its photo; failed writes preserve recoverable input.
- **Validation:** One iOS build attempt and focused unit tests only where state logic warrants them.
- **Stop:** Stop after pet management works; do not start the request wizard.

### T-010 — Groomer Profile and Portfolio Backend

- **Mode:** Deep.
- **Depends on:** T-007.
- **Goal:** Add groomer profile details, `groomer_services`, portfolio-photo records, Storage paths, and ownership RLS.
- **Boundary:** Backend contract and migrations only; no groomer profile UI or matching logic.
- **Acceptance:** Groomers can manage only their own profile, services, and portfolio uploads; customers receive only intentionally readable groomer data.
- **Validation:** `./scripts/supabase-check.sh` with table and Storage permission cases.
- **Stop:** Stop after backend validation; do not build request matching.

### T-011 — Groomer Profile, Services, and Portfolio UI

- **Mode:** Standard.
- **Depends on:** T-010.
- **Goal:** Implement groomer profile editing, service settings, portfolio upload, and all async UI states.
- **Boundary:** Groomer profile management only; no request feed or offers.
- **Acceptance:** A groomer can save and reload the profile, service settings, and portfolio without direct Supabase calls from views.
- **Validation:** One iOS build attempt and focused state tests where needed.
- **Stop:** Stop after profile management works; do not add marketplace discovery.

## Phase D — Requests and Matching

### T-012 — Grooming Request and Match Backend

- **Mode:** Deep.
- **Depends on:** T-009 and T-011.
- **Goal:** Add `grooming_requests`, `request_matches`, status rules, request creation/matching RPC, dismiss RPC, limits, and RLS.
- **Boundary:** Backend contract and migrations only; no request wizard or feed UI. Matching remains within the MVP rules in the Fresh Brief.
- **Acceptance:** One valid open request produces authorized matches; unmatched groomers cannot read it; dismiss is groomer-scoped; duplicate or invalid submissions are rejected.
- **Validation:** `./scripts/supabase-check.sh` with request, match, limit, and RLS cases.
- **Stop:** Stop after backend behavior validates; do not implement request screens.

### T-013 — Customer Grooming Request Wizard

- **Mode:** Standard.
- **Depends on:** T-012.
- **Goal:** Implement pet selection, service type, preferred time window, review, publish, and result states.
- **Boundary:** Customer creation, own-request display, and cancellation of an eligible open request only; no groomer feed or offers.
- **Acceptance:** A customer can publish and, while eligible, cancel one valid owned request through controlled backend operations; duplicate submission is blocked and failure preserves form input.
- **Validation:** One iOS build attempt plus focused wizard/state tests.
- **Stop:** Stop after customer publishing works; do not build the groomer feed.

### T-014 — Groomer Matched Request Feed

- **Mode:** Standard.
- **Depends on:** T-012.
- **Goal:** Implement matched-request list, detail, refresh, empty/error states, and dismiss behavior.
- **Boundary:** Read and dismiss only; no offer creation.
- **Acceptance:** A groomer sees only active matched requests and can dismiss one without affecting another groomer.
- **Validation:** One iOS build attempt and focused feed state tests.
- **Stop:** Stop after feed and dismiss work; do not add an offer form.

## Phase E — Offers

### T-015 — Groomer Offer Backend

- **Mode:** Deep.
- **Depends on:** T-012.
- **Goal:** Add `groomer_offers`, statuses, offer limits, create/withdraw RPCs, and RLS.
- **Boundary:** Backend contract and migrations only; no offer UI and no offer acceptance.
- **Acceptance:** Only a matched groomer can submit a valid offer; limits and duplicate rules are enforced server-side; customers can read offers for their requests only.
- **Validation:** `./scripts/supabase-check.sh` with authorization, limit, and negative RLS cases.
- **Stop:** Stop after offer creation validates; do not add booking behavior.

### T-016 — Groomer Offer Creation UI

- **Mode:** Standard.
- **Depends on:** T-014 and T-015.
- **Goal:** Implement proposed time, price, optional message, validation, submission, withdrawal, and offer-status display.
- **Boundary:** Groomer offer creation only; no customer comparison or acceptance.
- **Acceptance:** A matched groomer can submit one valid offer, duplicate taps are blocked, and backend errors remain visible.
- **Validation:** One iOS build attempt and focused form/state tests.
- **Stop:** Stop after groomer submission works; do not add customer acceptance.

### T-017 — Customer Offer Review

- **Mode:** Standard.
- **Depends on:** T-015.
- **Goal:** Implement customer offer list, detail, comparison information, refresh, and empty/error states.
- **Boundary:** Read-only offer review; the accept action remains unavailable until T-018.
- **Acceptance:** A customer sees only offers for owned requests with stable status and groomer information.
- **Validation:** One iOS build attempt and focused list/state tests.
- **Stop:** Stop after offer review works; do not create bookings.

## Phase F — Atomic Booking

### T-018 — Offer Acceptance and Booking Transaction

- **Mode:** Deep.
- **Depends on:** T-015 and T-017.
- **Goal:** Add `bookings`, `conversations`, an atomic accept-offer RPC that creates one booking and conversation, and a controlled role-specific booking-cancellation operation.
- **Boundary:** Backend transaction, status transitions, uniqueness, time-overlap protection, and RLS only; no booking-list UI or chat messages.
- **Acceptance:** A request creates at most one booking; competing offers close; overlapping groomer times are rejected while boundary-touching times are allowed; participant cancellation follows valid transitions; unauthorized direct booking writes fail.
- **Validation:** `./scripts/supabase-check.sh` with atomicity, duplicate, overlap, boundary, concurrency, and RLS tests.
- **Stop:** Stop after the transaction validates; do not build booking screens.

### T-019 — Customer and Groomer Booking UI

- **Mode:** Standard.
- **Depends on:** T-018.
- **Goal:** Enable customer acceptance and implement role-specific booking lists/details and valid participant cancellation backed by the same booking state.
- **Boundary:** Acceptance UI and booking display only; no chat, completion, or reviews.
- **Acceptance:** Customer acceptance refreshes request/offer state; both users see the same booking; conflict errors are explained without local fake writes.
- **Validation:** One iOS build attempt plus focused acceptance and booking-state tests.
- **Stop:** Stop after booking visibility is consistent; do not add chat.

## Phase G — Chat, Completion, and Review

### T-020 — Booking Participant Chat

- **Mode:** Deep.
- **Depends on:** T-018 and T-019.
- **Goal:** Add `messages`, participant-only RLS, repository/state handling, and basic conversation UI.
- **Boundary:** Text chat for booking participants only; no push notifications, typing indicators, or realtime polish.
- **Acceptance:** Only the customer and groomer attached to the booking can read or send messages; failures are visible.
- **Validation:** Backend RLS tests, one iOS build attempt, and focused message-state tests defined in the intake.
- **Stop:** Stop after basic chat works; do not add deferred chat polish.

### T-021 — Booking Completion and Customer Review

- **Mode:** Deep.
- **Depends on:** T-019.
- **Goal:** Add completion and review RPCs, `reviews`, RLS, groomer completion UI, and customer review UI.
- **Boundary:** Completion and one customer review per completed booking only; no disputes, refunds, or moderation tools.
- **Acceptance:** Only the booked groomer can complete the booking; only the booked customer can review a completed booking once.
- **Validation:** Backend transition/RLS tests and one iOS build attempt with focused state tests.
- **Stop:** Stop after completion and review validate; do not start non-MVP features.

## Phase H — MVP Hardening

### T-022 — Security, Diagnostics, and End-to-End Acceptance

- **Mode:** Deep.
- **Depends on:** T-020 and T-021.
- **Goal:** Complete loading/empty/error/validation states, add a developer-only safe Debug Panel, and verify the Fresh Brief MVP end to end.
- **Boundary:** Stabilization only. No payments, push notifications, social login, complex calendar/map UI, admin dashboard, subscriptions, or other deferred features.
- **Acceptance:** Core customer-to-groomer flow passes; booking uniqueness and conflict boundaries pass; required RLS negative cases pass; Debug Panel exposes no tokens, passwords, or full keys.
- **Validation:** Explicit full plan covering `./scripts/supabase-check.sh`, `./scripts/ios-test.sh`, `./scripts/preflight.sh`, core E2E, overlap/boundary tests, and RLS negative tests.
- **Stop:** Stop when Fresh Brief MVP acceptance criteria are documented as passed or the first unresolved real failure is reported.

## Next Task

T-003 — Canonical Documentation Alignment. Do not begin it without a separate user instruction.
