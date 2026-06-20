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
- Test result: passed with 4 Swift Testing tests and 1 XCTest UI smoke test according to existing T-001 reports.
- General check: `./scripts/preflight.sh` and the active-doc placeholder/stale-term scan passed for T-003 on 2026-06-19.
- Supabase check: `./scripts/supabase-check.sh` passed for T-004 on 2026-06-20 after its secret scan was narrowed to actual key-value patterns instead of legitimate SQL role grants.
- Known failing checks: none reported. One earlier T-005 build was intentionally cancelled when the user paused; the resumed build and targeted AppInfo configuration rebuild passed. The first T-004 static check exposed a validator false positive, which was corrected and passed on targeted rerun.

## Current Product State

- Fresh marketplace baseline plus Supabase client/session infrastructure; no authentication or product flow is implemented.
- Production launch still shows the explicit authentication bootstrap. A missing/invalid Supabase configuration is displayed as an error rather than treated as signed out or successful.
- Customer and groomer tab shells are available only through explicit route injection and previews.
- Active product documentation now defines the canonical Open Request → Groomer Offer → Customer Confirmation → Booking model and planned screen ownership.

## Current Workflow State

- The lightweight single-agent workflow is active at `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- T-001 SwiftUI baseline is completed from existing implementation and review evidence.
- T-002 incremental roadmap is recorded at `docs/06_tasks/T-002_INCREMENTAL_BUILD_ROADMAP.md`.
- T-003 canonical product, architecture, and backend documentation alignment is completed.
- T-004 Supabase profile foundation is completed and deployed to the authorized fresh project.
- T-005 iOS Supabase client and session boundary is completed at `docs/06_tasks/T-005_IOS_SUPABASE_CLIENT_SESSION_BOUNDARY.md`.

## Current iOS State

- Native project: `ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj`.
- Targets: app, Swift Testing unit tests, and XCTest UI tests; shared scheme `PetGroomerMarketplace`.
- Baseline: Swift 6, minimum iOS 18.0, bundle ID `com.prinnyyy.PetGroomerMarketplace`.
- Structure: feature-first App, Core models/configuration/infrastructure/repositories, DesignSystem, Auth bootstrap, Customer tabs, and Groomer tabs.
- Supabase Swift is pinned exactly to 2.46.0 with a checked-in package lock. App composition creates the client and an injectable Auth session repository; SwiftUI views do not access Supabase directly.
- The tracked xcconfig has empty defaults and optionally includes a Git-ignored MCP-populated local xcconfig. Only modern `sb_publishable_` keys are accepted; missing/invalid configuration fails visibly.
- No sign-in/up/out behavior, session-based routing, product query, backend mutation, or runtime demo mode exists.

## Current Backend State

- Supabase MCP connectivity was verified read-only on 2026-06-19 with `list_projects`.
- Visible remote project `Prinnyyy's Project` (ref `swdiiyypysyxbnfrxxsv`) is a legacy project and is explicitly out of scope for the fresh rebuild. Do not inspect, branch, migrate, reset, or otherwise mutate it.
- The fresh project `Pet Groomer Marketplace` (ref `lqmasbuqzvcvtawonjlb`) was created in organization `Prinnyyy`, region `us-west-1`, after the user confirmed the reported US$0/month cost. It is the only authorized T-004 target.
- T-004 migrations `20260620105202_t004_profile_foundation` and `20260620105409_t004_optimize_rls_auth_calls` are applied to the fresh project and mirrored under `supabase/migrations/`.
- Deployed backend objects are `public.user_role`, `profiles`, `customer_profiles`, `groomer_profiles`, the private `avatars` bucket, and their explicit grants, triggers, and owner-scoped RLS/Storage policies. Rollback-only isolation tests passed and final MCP security/performance advisors returned no lints.
- The iOS app has a configured Supabase client/session boundary but does not yet perform Auth operations or query the deployed profile schema.
- Legacy project tables, migrations, RPCs, RLS, and Storage objects were not inspected; no operation targeted the legacy ref.
- `docs/03_backend/` distinguishes the deployed T-004 foundation from later planned tables, RPCs, RLS rules, and Storage boundaries.
- The user placed `supabase_api_key` in the repository root. Its contents and key type were not read; the file remains local and ignored by Git and must never be embedded in app code or documentation.

## Known Risks

- The generated project uses Xcode 26.5 object version 77 and expects a current Xcode toolchain.
- The fixed iPhone 16 Pro/iOS 18.4 destination may report both arm64 and x86_64 matches; prior validation selected arm64 successfully.
- Only the T-004 profile/avatar foundation is deployed. Auth behavior and all product-domain tables, RPCs, and later Storage buckets remain unimplemented.
- All current and future Supabase tasks must use Supabase MCP exclusively. Do not install or invoke the Supabase CLI, `npx supabase`, a local container stack, or direct database tools.
- Remote schema writes require explicit approval after the task-scoped SQL is reviewed; MCP `apply_migration` is the only authorized DDL path, followed by MCP verification and an exact local migration mirror.
- Favorites remain deferred because the Fresh Brief defines no fields, flow, screen, or acceptance behavior.

## Next Recommended Task

- T-006 — implement email/password authentication against the completed T-004/T-005 foundations. Do not start it automatically.
