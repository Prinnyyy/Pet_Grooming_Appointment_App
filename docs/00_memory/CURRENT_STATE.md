# Current State

Update this only when project state meaningfully changes.

## Last Updated

- Date: 2026-06-20
- Updated by: Codex

## Current Branch

- Local Git state: initialized.
- Current branch: `main`
- Remote `origin`: `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App.git`
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`
- Repository URL: `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App`

## Current Build Status

- Last build command: `./scripts/ios-build.sh`
- Build result: passed (`** BUILD SUCCEEDED **`) for T-005 on 2026-06-20 with Supabase Swift 2.46.0.
- Last test command: `./scripts/ios-test.sh`
- Test result: passed for T-017 on 2026-06-20 with 47 Swift Testing tests and 1 XCTest UI smoke test (`** TEST SUCCEEDED **`).
- General check: `./scripts/preflight.sh` and the active-doc placeholder/stale-term scan passed for T-003 on 2026-06-19.
- Supabase check: `./scripts/supabase-check.sh` passed for T-018 on 2026-06-20.
- Known failing checks: none blocking. T-009 local iOS validation passed, and the approved remote Storage API upload/delete smoke passed with zero persisted validation data. T-010 backend validation passed; no iOS build/test was run because T-010 was backend-only. T-011 iOS validation passed; no remote Supabase validation was run because T-011 changed only iOS client code and docs. T-012 backend validation passed; no iOS build/test was run because T-012 was backend-only. T-013 iOS validation passed; no Supabase remote validation was run because T-013 changed only iOS client code and docs. T-014 iOS validation passed; no Supabase remote validation was run because T-014 changed only iOS client code and docs. T-015 backend validation passed; no iOS build/test was run because T-015 was backend-only. T-016 iOS validation passed after an approved targeted naming-collision fix; no Supabase remote validation was run because T-016 changed only iOS client code and docs. T-017 iOS validation passed; no Supabase remote validation was run because T-017 changed only iOS client code and docs. T-018 backend validation passed; no iOS build/test was run because T-018 was backend-only.

## Current Product State

- Fresh marketplace baseline plus real Supabase email/password authentication, atomic role onboarding, profile loading, authenticated role routing, customer pet management, groomer profile management, request/match backend, offer backend, booking/conversation backend, customer request publishing/list/detail UI with read-only customer offer review, groomer matched request feed/detail/dismiss UI, and groomer offer creation/withdrawal UI; booking UI, chat, and review marketplace flows are not implemented.
- Production launch validates configuration, restores/observes the real Auth session, then loads the authoritative profile. A missing profile enters display-name/role onboarding; existing or newly created profiles enter the matching Customer or Groomer tabs. Missing configuration remains blocking, and no path fabricates a session/profile.
- Customer and groomer tab shells remain available through explicit route injection/previews, but production reaches them only from a real session and authoritative profile.
- Active product documentation now defines the canonical Open Request → Groomer Offer → Customer Confirmation → Booking model and planned screen ownership.

## Current Workflow State

- The lightweight single-agent workflow is active at `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- T-001 SwiftUI baseline is completed from existing implementation and review evidence.
- T-002 incremental roadmap is recorded at `docs/06_tasks/T-002_INCREMENTAL_BUILD_ROADMAP.md`.
- T-003 canonical product, architecture, and backend documentation alignment is completed.
- T-004 Supabase profile foundation is completed and deployed to the authorized fresh project.
- T-005 iOS Supabase client and session boundary is completed at `docs/06_tasks/T-005_IOS_SUPABASE_CLIENT_SESSION_BOUNDARY.md`.
- T-006 email/password authentication is completed at `docs/06_tasks/T-006_EMAIL_PASSWORD_AUTHENTICATION.md`.
- T-007 role onboarding and authenticated routing is completed at `docs/06_tasks/T-007_ROLE_ONBOARDING_AND_ROUTING.md`.
- T-008 pet data/photo Storage is completed at `docs/06_tasks/T-008_PET_DATA_AND_PHOTO_STORAGE_CONTRACT.md`.
- T-009 customer pet management is completed at `docs/06_tasks/T-009_CUSTOMER_PET_MANAGEMENT.md`; approved remote Storage API upload/delete smoke passed and cleaned up all temporary validation data.
- T-010 groomer profile and portfolio backend is completed at `docs/06_tasks/T-010_GROOMER_PROFILE_PORTFOLIO_BACKEND.md`; the primary migration and corrective select-policy merge migration are applied and mirrored, backend behavior checks passed, and T-010 performance WARNs are resolved.
- T-011 groomer profile management is completed at `docs/06_tasks/T-011_GROOMER_PROFILE_MANAGEMENT.md`; Account-tab profile/services/portfolio UI, repository boundary, Supabase adapter, and focused tests are implemented.
- T-012 grooming request and match backend is completed at `docs/06_tasks/T-012_GROOMING_REQUEST_MATCH_BACKEND.md`; the primary migration, corrective conflict-target migration, and corrective photo-snapshot cap migration are applied and mirrored, backend behavior checks passed, and advisory results are recorded.
- T-013 customer grooming request wizard is completed at `docs/06_tasks/T-013_CUSTOMER_GROOMING_REQUEST_WIZARD.md`; Customer Requests-tab publishing/list/detail UI, repository boundary, Supabase adapter, and focused tests are implemented.
- T-014 groomer matched request feed is completed at `docs/06_tasks/T-014_GROOMER_MATCHED_REQUEST_FEED.md`; Groomer Requests-tab feed/detail/dismiss UI, repository boundary, Supabase adapter, and focused tests are implemented.
- T-015 groomer offer backend is completed at `docs/06_tasks/T-015_GROOMER_OFFER_BACKEND.md`; the migration is applied and mirrored, backend behavior checks passed, and advisory results are recorded.
- T-016 groomer offer creation is completed at `docs/06_tasks/T-016_GROOMER_OFFER_CREATION.md`; Groomer Requests detail can show latest own offer status, submit an offer, withdraw a pending offer, and surface validation/backend errors through repository boundaries.
- T-017 customer offer review is completed at `docs/06_tasks/T-017_CUSTOMER_OFFER_REVIEW.md`; Customer request detail can load, refresh, compare pending offers before historical offers, and inspect read-only offers for owned requests through repository boundaries.
- T-018 offer acceptance and booking backend is completed at `docs/06_tasks/T-018_OFFER_ACCEPTANCE_BOOKING_BACKEND.md`; the migration is applied and mirrored, backend behavior checks passed, and advisor results are recorded.

## Current iOS State

- Native project: `ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj`.
- Targets: app, Swift Testing unit tests, and XCTest UI tests; shared scheme `PetGroomerMarketplace`.
- Baseline: Swift 6, minimum iOS 18.0, bundle ID `com.prinnyyy.PetGroomerMarketplace`.
- Structure: feature-first App, Core models/configuration/infrastructure/repositories, DesignSystem, Auth bootstrap, Customer tabs, Customer pets, Customer requests, Groomer tabs, Groomer requests, and Groomer profile management.
- Supabase Swift is pinned exactly to 2.46.0 with a checked-in package lock. App composition creates the client plus injectable Auth, profile, customer pet, customer request, groomer profile, and groomer request repositories; SwiftUI views do not access Supabase directly.
- The tracked xcconfig has empty defaults and optionally includes a Git-ignored MCP-populated local xcconfig. Only modern `sb_publishable_` keys are accepted; missing/invalid configuration fails visibly.
- Email/password sign-up/sign-in, default confirmation-required handling, local-scope sign-out, cached-session restoration, and Auth event observation are implemented behind `AuthSessionRepository` and `AuthenticationStore`.
- `SupabaseProfileRepository` performs narrowly scoped profile lookup and the atomic onboarding RPC; `AuthenticatedEntryStore` distinguishes missing profile from failure, validates role setup, and routes from the authoritative result.
- `RoleOnboardingView` requires a 1–80 character trimmed display name and explicit Customer/Groomer selection. Customer role receives customer pet management on Home, request publishing/list/detail on Requests, and Account sign-out. Groomer role receives matched request feed/detail/dismiss/offer creation on Requests and profile/services/portfolio management in Account plus an account/sign-out link; the separate Offers tab, Bookings, and Messages remain placeholder-only.
- Customer Home now loads real customer-owned pets through `CustomerPetRepository`, supports add/edit, soft-delete, private photo upload/delete controls, loading/error/empty states, and Storage path generation matching the T-008 backend contract. Photo display is metadata-only; signed URLs/image downloads remain later work.
- Customer Requests now loads real customer-owned pets and grooming requests, validates request drafts, publishes through `create_grooming_request`, reloads authoritative owned requests, shows match-count feedback, displays frozen pet/request details, and reviews received offers with pending offers separated from historical offers plus active groomer summaries through `CustomerRequestRepository`. Request cancellation is not connected because the backend has no customer request cancel RPC. Offer acceptance UI is not connected yet; the T-018 backend transaction exists and is reserved for T-019 iOS integration. T-018 booking cancellation does not reopen the original request or offers.
- Groomer Account now loads the real groomer profile/services/portfolio metadata through `GroomerProfileRepository`, supports profile activation validation, service create/edit/delete, and private `groomer-portfolio` Storage upload/delete controls. Portfolio display is metadata-only; signed URLs/image downloads and remote smoke remain later work.
- Groomer Requests now loads active own `request_matches`, readable open/has-offers `grooming_requests`, and latest own `groomer_offers` through `GroomerRequestRepository`; it displays frozen request/pet details, dismisses visible/viewed matches through `dismiss_request_match`, submits offers through `create_groomer_offer`, and withdraws pending offers through `withdraw_groomer_offer`.
- No runtime demo mode, product-domain query, raw backend error, or token exposure exists.

## Current Backend State

- Supabase MCP connectivity was verified read-only on 2026-06-19 with `list_projects`.
- Visible remote project `Prinnyyy's Project` (ref `swdiiyypysyxbnfrxxsv`) is a legacy project and is explicitly out of scope for the fresh rebuild. Do not inspect, branch, migrate, reset, or otherwise mutate it.
- The fresh project `Pet Groomer Marketplace` (ref `lqmasbuqzvcvtawonjlb`) was created in organization `Prinnyyy`, region `us-west-1`, after the user confirmed the reported US$0/month cost. It is the only authorized Supabase target for this rebuild.
- T-004 migrations `20260620105202_t004_profile_foundation` and `20260620105409_t004_optimize_rls_auth_calls`, T-007 migrations `20260620172839_t007_create_my_profile` and corrective `20260620180607_t007_fix_create_my_profile_conflict_target`, T-008 migration `20260620192648_t008_pet_data_photo_storage`, T-010 migration `20260620224418_t010_groomer_profile_portfolio_backend`, corrective T-010 migration `20260620225308_t010_merge_groomer_select_policies`, T-012 migration `20260621000444_t012_grooming_request_match_backend`, corrective T-012 migration `20260621002211_t012_fix_create_grooming_request_conflict_target`, corrective T-012 migration `20260621010315_t012_limit_request_photo_snapshot`, T-015 migration `20260621024848_t015_groomer_offer_backend`, and T-018 migration `20260621044424_t018_offer_acceptance_booking_backend` are applied to the fresh project and mirrored under `supabase/migrations/`.
- Deployed backend objects include `public.user_role`, profile/role tables, `create_my_profile`, `pets`, `pet_photos`, `groomer_services`, `groomer_portfolio_photos`, `grooming_requests`, `request_matches`, `groomer_offers`, `bookings`, `conversations`, `create_grooming_request`, `dismiss_request_match`, `create_groomer_offer`, `withdraw_groomer_offer`, `accept_groomer_offer`, `cancel_booking`, the private `avatars`, `pet-photos`, and `groomer-portfolio` buckets, and their explicit grants, constraints, indexes, triggers, RLS/Storage policies, and function privileges.
- `create_my_profile` is `security invoker` with an empty search path; anon cannot execute it, authenticated/service_role can execute it, and it rejects anonymous JWTs. It inserts the shared profile before exactly one marker, preserves the first name on same-role retry, and returns `P0001/profile_role_immutable` for role changes.
- T-004/T-007 rollback-only access/RPC tests passed with zero persisted test users and their final advisors returned no lints. T-008 metadata inspection and corrected owner/cross-user/role/anonymous/constraint/Storage-upload assertions passed with zero persisted validation data. Direct SQL Storage deletion is intentionally blocked by Supabase; MCP inspection confirmed the DELETE policy exactly matches the behavior-tested owner-only SELECT predicate. T-008 security advisor returned no lints. Its single performance INFO about the composite photo foreign key was reviewed as non-blocking because the existing B-tree contains both equality columns. T-009 approved remote smoke passed the real authenticated REST/RPC/Storage path for pet photo upload/delete and MCP cleanup confirmed zero remaining smoke Auth/profile/pet/photo/object data. T-010 metadata inspection and rollback-only groomer/customer/Storage checks passed with zero persisted validation data; security advisor returned no lints; corrective select-policy merge removed T-010 performance WARNs. T-012 metadata inspection and rollback-only request/match/RLS/RPC checks passed with zero persisted validation data; corrective conflict-target migration resolved PostgreSQL `42702` in `create_grooming_request`, and corrective photo-snapshot cap migration passed a 21-photo rollback regression with zero persisted validation data. T-015 metadata inspection and rollback-only offer/RLS/RPC checks passed with zero persisted validation data. T-018 metadata inspection and rollback-only booking/RLS/RPC checks passed with zero persisted validation data. Remaining advisor findings were reviewed as non-blocking at T-018 closeout: six intentional SECURITY DEFINER WARNs for controlled T-012/T-015/T-018 RPCs plus composite-FK and unused-index INFOs.
- The iOS app performs real Supabase Auth, profile lookup/onboarding, customer pet CRUD, pet-photo metadata, groomer profile/service CRUD, groomer portfolio metadata, customer grooming request creation/owned-request reads/customer offer reads, groomer matched request reads/dismissal, groomer offer creation/withdrawal, and private `pet-photos`/`groomer-portfolio` Storage upload/delete operations through repository boundaries. T-018 booking RPCs are backend-deployed but not yet wired into iOS.
- Legacy project tables, migrations, RPCs, RLS, and Storage objects were not inspected; no operation targeted the legacy ref.
- `docs/03_backend/` distinguishes the deployed T-004 foundation from later planned tables, RPCs, RLS rules, and Storage boundaries.
- The user placed `supabase_api_key` in the repository root. Its contents and key type were not read; the file remains local and ignored by Git and must never be embedded in app code or documentation.

## Known Risks

- The generated project uses Xcode 26.5 object version 77 and expects a current Xcode toolchain.
- The fixed iPhone 16 Pro/iOS 18.4 destination may report both arm64 and x86_64 matches; prior validation selected arm64 successfully.
- T-008 pet tables/private photo bucket, T-010 groomer profile/services/portfolio backend, T-012 request/match backend, T-015 offer backend, and T-018 booking/conversation backend are deployed and backend-validated. T-009 implements the iOS Storage API upload/delete path for pet photos and its approved remote upload/delete smoke passed. T-011 implements the iOS groomer profile/services/portfolio path, but remote portfolio upload/delete smoke has not been run. T-013 implements customer request publishing/list/detail, but request cancellation is blocked until a backend request-cancel RPC exists. T-014 implements groomer matched request feed/detail/dismiss. T-016 implements groomer-side offer creation/withdrawal. T-017 implements customer read-only offer review. T-019 must wire offer acceptance/cancellation and booking list/detail UI while preserving T-018's no-reopen cancellation rule; chat/review tables, RPCs, and Storage buckets remain unimplemented remotely.
- Default email confirmation requires the user to confirm in a browser and then return to Sign In; automatic native deep-link completion and production SMTP configuration are not part of T-006.
- All current and future Supabase tasks must use Supabase MCP exclusively. Do not install or invoke the Supabase CLI, `npx supabase`, a local container stack, or direct database tools.
- Remote schema writes require explicit approval after the task-scoped SQL is reviewed; MCP `apply_migration` is the only authorized DDL path, followed by MCP verification and an exact local migration mirror.
- Favorites remain deferred because the Fresh Brief defines no fields, flow, screen, or acceptance behavior.

## Next Recommended Task

- T-019 — implement booking acceptance and role-specific booking UI; do not start automatically.
