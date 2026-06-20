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
- Test result: passed for T-011 on 2026-06-20 with 32 Swift Testing tests and 1 XCTest UI smoke test (`** TEST SUCCEEDED **`).
- General check: `./scripts/preflight.sh` and the active-doc placeholder/stale-term scan passed for T-003 on 2026-06-19.
- Supabase check: `./scripts/supabase-check.sh` passed for T-010 on 2026-06-20.
- Known failing checks: none blocking. T-009 local iOS validation passed, and the approved remote Storage API upload/delete smoke passed with zero persisted validation data. T-010 backend validation passed; no iOS build/test was run because T-010 was backend-only. T-011 iOS validation passed; no remote Supabase validation was run because T-011 changed only iOS client code and docs.

## Current Product State

- Fresh marketplace baseline plus real Supabase email/password authentication, atomic role onboarding, profile loading, authenticated role routing, customer pet management, and groomer profile management; request/offer/booking/chat/review marketplace flows are not implemented.
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

## Current iOS State

- Native project: `ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj`.
- Targets: app, Swift Testing unit tests, and XCTest UI tests; shared scheme `PetGroomerMarketplace`.
- Baseline: Swift 6, minimum iOS 18.0, bundle ID `com.prinnyyy.PetGroomerMarketplace`.
- Structure: feature-first App, Core models/configuration/infrastructure/repositories, DesignSystem, Auth bootstrap, Customer tabs, Customer pets, Groomer tabs, and Groomer profile management.
- Supabase Swift is pinned exactly to 2.46.0 with a checked-in package lock. App composition creates the client plus injectable Auth, profile, customer pet, and groomer profile repositories; SwiftUI views do not access Supabase directly.
- The tracked xcconfig has empty defaults and optionally includes a Git-ignored MCP-populated local xcconfig. Only modern `sb_publishable_` keys are accepted; missing/invalid configuration fails visibly.
- Email/password sign-up/sign-in, default confirmation-required handling, local-scope sign-out, cached-session restoration, and Auth event observation are implemented behind `AuthSessionRepository` and `AuthenticationStore`.
- `SupabaseProfileRepository` performs narrowly scoped profile lookup and the atomic onboarding RPC; `AuthenticatedEntryStore` distinguishes missing profile from failure, validates role setup, and routes from the authoritative result.
- `RoleOnboardingView` requires a 1–80 character trimmed display name and explicit Customer/Groomer selection. Customer role receives customer pet management on Home and Account sign-out. Groomer role receives profile/services/portfolio management in Account plus an account/sign-out link; other marketplace tabs remain placeholder-only.
- Customer Home now loads real customer-owned pets through `CustomerPetRepository`, supports add/edit, soft-delete, private photo upload/delete controls, loading/error/empty states, and Storage path generation matching the T-008 backend contract. Photo display is metadata-only; signed URLs/image downloads remain later work.
- Groomer Account now loads the real groomer profile/services/portfolio metadata through `GroomerProfileRepository`, supports profile activation validation, service create/edit/delete, and private `groomer-portfolio` Storage upload/delete controls. Portfolio display is metadata-only; signed URLs/image downloads and remote smoke remain later work.
- No runtime demo mode, product-domain query, raw backend error, or token exposure exists.

## Current Backend State

- Supabase MCP connectivity was verified read-only on 2026-06-19 with `list_projects`.
- Visible remote project `Prinnyyy's Project` (ref `swdiiyypysyxbnfrxxsv`) is a legacy project and is explicitly out of scope for the fresh rebuild. Do not inspect, branch, migrate, reset, or otherwise mutate it.
- The fresh project `Pet Groomer Marketplace` (ref `lqmasbuqzvcvtawonjlb`) was created in organization `Prinnyyy`, region `us-west-1`, after the user confirmed the reported US$0/month cost. It is the only authorized Supabase target for this rebuild.
- T-004 migrations `20260620105202_t004_profile_foundation` and `20260620105409_t004_optimize_rls_auth_calls`, T-007 migrations `20260620172839_t007_create_my_profile` and corrective `20260620180607_t007_fix_create_my_profile_conflict_target`, T-008 migration `20260620192648_t008_pet_data_photo_storage`, T-010 migration `20260620224418_t010_groomer_profile_portfolio_backend`, and corrective T-010 migration `20260620225308_t010_merge_groomer_select_policies` are applied to the fresh project and mirrored under `supabase/migrations/`.
- Deployed backend objects include `public.user_role`, profile/role tables, `create_my_profile`, `pets`, `pet_photos`, `groomer_services`, `groomer_portfolio_photos`, the private `avatars`, `pet-photos`, and `groomer-portfolio` buckets, and their explicit grants, constraints, indexes, triggers, RLS/Storage policies, and function privileges.
- `create_my_profile` is `security invoker` with an empty search path; anon cannot execute it, authenticated/service_role can execute it, and it rejects anonymous JWTs. It inserts the shared profile before exactly one marker, preserves the first name on same-role retry, and returns `P0001/profile_role_immutable` for role changes.
- T-004/T-007 rollback-only access/RPC tests passed with zero persisted test users and their final advisors returned no lints. T-008 metadata inspection and corrected owner/cross-user/role/anonymous/constraint/Storage-upload assertions passed with zero persisted validation data. Direct SQL Storage deletion is intentionally blocked by Supabase; MCP inspection confirmed the DELETE policy exactly matches the behavior-tested owner-only SELECT predicate. T-008 security advisor returned no lints. Its single performance INFO about the composite photo foreign key was reviewed as non-blocking because the existing B-tree contains both equality columns. T-009 approved remote smoke passed the real authenticated REST/RPC/Storage path for pet photo upload/delete and MCP cleanup confirmed zero remaining smoke Auth/profile/pet/photo/object data. T-010 metadata inspection and rollback-only groomer/customer/Storage checks passed with zero persisted validation data; security advisor returned no lints; corrective select-policy merge removed T-010 performance WARNs. Remaining performance INFOs are non-blocking: the existing T-008 composite-FK advisory and a T-010 unused active-city index expected before groomer discovery queries exist.
- The iOS app performs real Supabase Auth, profile lookup/onboarding, customer pet CRUD, pet-photo metadata, groomer profile/service CRUD, groomer portfolio metadata, and private `pet-photos`/`groomer-portfolio` Storage upload/delete operations through repository boundaries.
- Legacy project tables, migrations, RPCs, RLS, and Storage objects were not inspected; no operation targeted the legacy ref.
- `docs/03_backend/` distinguishes the deployed T-004 foundation from later planned tables, RPCs, RLS rules, and Storage boundaries.
- The user placed `supabase_api_key` in the repository root. Its contents and key type were not read; the file remains local and ignored by Git and must never be embedded in app code or documentation.

## Known Risks

- The generated project uses Xcode 26.5 object version 77 and expects a current Xcode toolchain.
- The fixed iPhone 16 Pro/iOS 18.4 destination may report both arm64 and x86_64 matches; prior validation selected arm64 successfully.
- T-008 pet tables/private photo bucket and T-010 groomer profile/services/portfolio backend are deployed and backend-validated. T-009 implements the iOS Storage API upload/delete path for pet photos and its approved remote upload/delete smoke passed. T-011 implements the iOS groomer profile/services/portfolio path, but remote portfolio upload/delete smoke has not been run. Request/match/offer/booking/chat/review tables, RPCs, and Storage buckets remain unimplemented.
- Default email confirmation requires the user to confirm in a browser and then return to Sign In; automatic native deep-link completion and production SMTP configuration are not part of T-006.
- All current and future Supabase tasks must use Supabase MCP exclusively. Do not install or invoke the Supabase CLI, `npx supabase`, a local container stack, or direct database tools.
- Remote schema writes require explicit approval after the task-scoped SQL is reviewed; MCP `apply_migration` is the only authorized DDL path, followed by MCP verification and an exact local migration mirror.
- Favorites remain deferred because the Fresh Brief defines no fields, flow, screen, or acceptance behavior.

## Next Recommended Task

- T-012 — add the grooming request and match backend in a separate Deep task with an explicit Supabase MCP validation plan; do not start automatically.
