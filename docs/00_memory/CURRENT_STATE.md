# Current State

Update this only when project state meaningfully changes.

## Last Updated

- Date: 2026-06-19
- Updated by: Codex

## Current Branch

- Local Git state: initialized.
- Current branch: `main`
- Remote `origin`: `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App.git`
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`
- Repository URL: `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App`

## Current Build Status

- Last build command: `./scripts/ios-build.sh`
- Build result: passed (`** BUILD SUCCEEDED **`) according to T-001 implementation and specification-review reports.
- Last test command: `./scripts/ios-test.sh`
- Test result: passed with 4 Swift Testing tests and 1 XCTest UI smoke test according to existing T-001 reports.
- General check: `./scripts/preflight.sh` and the active-doc placeholder/stale-term scan passed for T-003 on 2026-06-19.
- Known failing checks: none reported.

## Current Product State

- Fresh marketplace baseline only; no product feature or backend flow is implemented.
- Production launch shows an explicit authentication placeholder.
- Customer and groomer tab shells are available only through explicit route injection and previews.
- Active product documentation now defines the canonical Open Request → Groomer Offer → Customer Confirmation → Booking model and planned screen ownership.

## Current Workflow State

- The lightweight single-agent workflow is active at `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- T-001 SwiftUI baseline is completed from existing implementation and review evidence.
- T-002 incremental roadmap is recorded at `docs/06_tasks/T-002_INCREMENTAL_BUILD_ROADMAP.md`.
- T-003 canonical product, architecture, and backend documentation alignment is completed.

## Current iOS State

- Native project: `ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj`.
- Targets: app, Swift Testing unit tests, and XCTest UI tests; shared scheme `PetGroomerMarketplace`.
- Baseline: Swift 6, minimum iOS 18.0, bundle ID `com.prinnyyy.PetGroomerMarketplace`.
- Structure: feature-first App, Core models, DesignSystem, Auth placeholder, Customer tabs, and Groomer tabs.
- No third-party dependencies, persistence, networking, or runtime demo mode.

## Current Backend State

- Supabase MCP connectivity was verified read-only on 2026-06-19 with `list_projects`.
- Visible remote project `Prinnyyy's Project` (ref `swdiiyypysyxbnfrxxsv`) is a legacy project and is explicitly out of scope for the fresh rebuild. Do not inspect, branch, migrate, reset, or otherwise mutate it.
- The fresh rebuild requires a separate new Supabase project. No new project has been created or selected yet.
- The repository still has no local Supabase configuration or migrations, and the iOS app has no Supabase client code.
- Legacy project tables, migrations, RPCs, RLS, and Storage objects were not inspected; no remote SQL or DDL was executed during the connection check.
- `docs/03_backend/` now records the planned tables, RPCs, grants/RLS rules, Storage boundaries, and migration rules; these are contracts, not deployed objects.
- The user placed `supabase_api_key` in the repository root. Its contents and key type were not read; the file remains local and ignored by Git and must never be embedded in app code or documentation.

## Known Risks

- The generated project uses Xcode 26.5 object version 77 and expects a current Xcode toolchain.
- The fixed iPhone 16 Pro/iOS 18.4 destination may report both arm64 and x86_64 matches; prior validation selected arm64 successfully.
- Planned Supabase objects remain unverified until T-004 creates a new project and validates the fresh foundation; Data API grants and RLS must both be tested.
- Supabase CLI and a local container runtime are not installed. MCP is available for read-only inspection, but remote schema writes still require explicit authorization and a migration-file strategy.
- Creating a new Supabase project may incur cost and requires explicit organization selection and cost confirmation before the MCP create-project action.
- Favorites remain deferred because the Fresh Brief defines no fields, flow, screen, or acceptance behavior.

## Next Recommended Task

- Paused for user instruction. T-004 must create or select a brand-new Supabase project for the fresh rebuild; the visible legacy project must not be used.
