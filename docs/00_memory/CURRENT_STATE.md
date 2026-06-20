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
- Test result: passed for T-007 on 2026-06-20 with 17 Swift Testing tests and 1 XCTest UI smoke test (`** TEST SUCCEEDED **`).
- General check: `./scripts/preflight.sh` and the active-doc placeholder/stale-term scan passed for T-003 on 2026-06-19.
- Supabase check: `./scripts/supabase-check.sh` passed for T-007 on 2026-06-20.
- Known failing checks: none reported. The first T-007 RPC validation exposed PostgreSQL `42702`; the separately approved corrective migration fixed the ambiguous conflict target and the complete validation then passed.

## Current Product State

- Fresh marketplace baseline plus real Supabase email/password authentication, atomic role onboarding, profile loading, and authenticated role routing; marketplace product flows are not implemented.
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

## Current iOS State

- Native project: `ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj`.
- Targets: app, Swift Testing unit tests, and XCTest UI tests; shared scheme `PetGroomerMarketplace`.
- Baseline: Swift 6, minimum iOS 18.0, bundle ID `com.prinnyyy.PetGroomerMarketplace`.
- Structure: feature-first App, Core models/configuration/infrastructure/repositories, DesignSystem, Auth bootstrap, Customer tabs, and Groomer tabs.
- Supabase Swift is pinned exactly to 2.46.0 with a checked-in package lock. App composition creates the client plus injectable Auth and profile repositories; SwiftUI views do not access Supabase directly.
- The tracked xcconfig has empty defaults and optionally includes a Git-ignored MCP-populated local xcconfig. Only modern `sb_publishable_` keys are accepted; missing/invalid configuration fails visibly.
- Email/password sign-up/sign-in, default confirmation-required handling, local-scope sign-out, cached-session restoration, and Auth event observation are implemented behind `AuthSessionRepository` and `AuthenticationStore`.
- `SupabaseProfileRepository` performs narrowly scoped profile lookup and the atomic onboarding RPC; `AuthenticatedEntryStore` distinguishes missing profile from failure, validates role setup, and routes from the authoritative result.
- `RoleOnboardingView` requires a 1–80 character trimmed display name and explicit Customer/Groomer selection. Role shells receive a minimal Account destination with current-device sign-out; all other tab content remains placeholder-only.
- No runtime demo mode, product-domain query, raw backend error, or token exposure exists.

## Current Backend State

- Supabase MCP connectivity was verified read-only on 2026-06-19 with `list_projects`.
- Visible remote project `Prinnyyy's Project` (ref `swdiiyypysyxbnfrxxsv`) is a legacy project and is explicitly out of scope for the fresh rebuild. Do not inspect, branch, migrate, reset, or otherwise mutate it.
- The fresh project `Pet Groomer Marketplace` (ref `lqmasbuqzvcvtawonjlb`) was created in organization `Prinnyyy`, region `us-west-1`, after the user confirmed the reported US$0/month cost. It is the only authorized Supabase target for this rebuild.
- T-004 migrations `20260620105202_t004_profile_foundation` and `20260620105409_t004_optimize_rls_auth_calls`, plus T-007 migrations `20260620172839_t007_create_my_profile` and corrective `20260620180607_t007_fix_create_my_profile_conflict_target`, are applied to the fresh project and mirrored under `supabase/migrations/`.
- Deployed backend objects are `public.user_role`, `profiles`, `customer_profiles`, `groomer_profiles`, `create_my_profile`, the private `avatars` bucket, and their explicit grants, triggers, owner-scoped RLS/Storage policies, and function privileges.
- `create_my_profile` is `security invoker` with an empty search path; anon cannot execute it, authenticated/service_role can execute it, and it rejects anonymous JWTs. It inserts the shared profile before exactly one marker, preserves the first name on same-role retry, and returns `P0001/profile_role_immutable` for role changes.
- Rollback-only Customer/Groomer/idempotency/immutable-role/cross-user/anonymous tests passed with zero persisted test users. Final MCP security and performance advisors returned no lints.
- The iOS app performs real Supabase Auth and profile lookup/onboarding operations but no later marketplace-domain operation.
- Legacy project tables, migrations, RPCs, RLS, and Storage objects were not inspected; no operation targeted the legacy ref.
- `docs/03_backend/` distinguishes the deployed T-004 foundation from later planned tables, RPCs, RLS rules, and Storage boundaries.
- The user placed `supabase_api_key` in the repository root. Its contents and key type were not read; the file remains local and ignored by Git and must never be embedded in app code or documentation.

## Known Risks

- The generated project uses Xcode 26.5 object version 77 and expects a current Xcode toolchain.
- The fixed iPhone 16 Pro/iOS 18.4 destination may report both arm64 and x86_64 matches; prior validation selected arm64 successfully.
- Only the T-004 profile/avatar foundation and T-007 profile-onboarding RPC are deployed. All marketplace-domain tables, later RPCs, and later Storage buckets remain unimplemented.
- Default email confirmation requires the user to confirm in a browser and then return to Sign In; automatic native deep-link completion and production SMTP configuration are not part of T-006.
- All current and future Supabase tasks must use Supabase MCP exclusively. Do not install or invoke the Supabase CLI, `npx supabase`, a local container stack, or direct database tools.
- Remote schema writes require explicit approval after the task-scoped SQL is reviewed; MCP `apply_migration` is the only authorized DDL path, followed by MCP verification and an exact local migration mirror.
- Favorites remain deferred because the Fresh Brief defines no fields, flow, screen, or acceptance behavior.

## Next Recommended Task

- T-008 — define pets, pet photos, private Storage, and RLS in a separate Deep task. Do not start it automatically.
