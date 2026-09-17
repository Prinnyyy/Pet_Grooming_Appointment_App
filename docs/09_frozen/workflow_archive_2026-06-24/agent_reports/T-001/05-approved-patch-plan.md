# Approved Patch Plan

## Task ID

`T-001`

## Primary Objective

Create a native, buildable, and testable SwiftUI baseline for Pet Groomer Marketplace.

## Out of Scope

- Supabase, authentication behavior, persistence, networking, and marketplace business logic.
- Runtime mock data, debug role switching, or fake backend success.
- Third-party dependencies, commits, pushes, or pull requests.

## Files Allowed to Edit

- `ios/PetGroomerMarketplace/`
- `scripts/ios-build.sh`
- `scripts/ios-test.sh`
- `docs/04_ios/IOS_BUILD_AND_TESTING.md`
- T-001 reports and required durable memory/task files.

## Files Not Allowed to Edit

- `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`
- Deleted `Product_Architecture_Grooming_Request_Offers_Mode.md`
- Supabase/backend files and unrelated product/workflow docs.

## Implementation Steps

1. Generate a native Xcode iOS App project at `ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj` with app, Swift Testing unit-test, and XCTest UI-test targets; use Swift 6, iOS 18.0, bundle ID `com.prinnyyy.PetGroomerMarketplace`, and a shared scheme.
2. Establish the feature-first folders under the app target: `App`, `Core/Models`, `DesignSystem`, and `Features/{Auth,Customer,Groomer}`.
3. Before writing behavior implementations, add failing unit tests for `UserRole`, all four `AppEntryRoute` cases, role-to-route mapping, default authentication route, and exact ordered tab collections. Run the unit target and confirm RED because the types do not exist.
4. Implement only the types and values required to make the route and tab tests pass.
5. Add `AppRootView(route:)`, authentication/onboarding placeholders, Customer/Groomer tab shells, shared placeholder content, and minimal semantic design tokens. Production App construction must inject `.authentication`.
6. Add a UI smoke test that launches normally and asserts `auth.bootstrap` exists while customer/groomer tab roots do not.
7. Configure build/test scripts with explicit project, scheme, and iPhone 16 Pro/iOS 18.4 defaults while preserving environment overrides.
8. Build and test, address at most two focused implementation failures, then complete reviews and durable memory updates.

## Validation Steps

1. `./scripts/ios-build.sh`
2. `./scripts/ios-test.sh`
3. `./scripts/preflight.sh`
4. `git diff --check`
5. Inspect `git status --short --untracked-files=all` and confirm the user's deleted old document and unmodified new Brief remain intact.

## Stop Condition

After validation, final review, memory updates, and the T-001 final run report, stop and wait for the user. Do not start authentication or Supabase.

## Risk Level

Medium: native Xcode project generation and target membership require immediate build/test verification.
