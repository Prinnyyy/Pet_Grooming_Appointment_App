# T-001 Implementation Report

## Status

DONE

## Files

- Created the native project and shared scheme under `ios/PetGroomerMarketplace/`.
- Added the feature-first app source under `PetGroomerMarketplace/{App,Core/Models,DesignSystem,Features}`.
- Added Swift Testing coverage in `PetGroomerMarketplaceTests/AppEntryModelsTests.swift`.
- Added the XCTest launch smoke test in `PetGroomerMarketplaceUITests/AppLaunchSmokeTests.swift`.
- Updated `scripts/ios-build.sh`, `scripts/ios-test.sh`, and `docs/04_ios/IOS_BUILD_AND_TESTING.md`.
- Added `ios/.gitignore` for Xcode personal state.

## RED Evidence

1. Unit-model RED command:

   ```bash
   xcodebuild -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' -only-testing:PetGroomerMarketplaceTests test
   ```

   Result: exit 65. Compilation failed because `UserRole`, `AppEntryRoute`, `CustomerTab`, and `GroomerTab` did not exist. This was the expected feature-missing failure.

2. UI launch RED command:

   ```bash
   xcodebuild -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' -only-testing:PetGroomerMarketplaceUITests/AppLaunchSmokeTests/testNormalLaunchShowsOnlyAuthenticationRoot test
   ```

   Result: exit 65. The template app launched, but `auth.bootstrap` did not appear within five seconds. This was the expected missing-root failure.

## GREEN / Verification

- Targeted unit GREEN: 4 Swift Testing tests passed after implementing the route and tab value types.
- Targeted UI GREEN: the normal-launch smoke test passed; `auth.bootstrap` existed and `customer.tabs` / `groomer.tabs` did not.
- `./scripts/ios-build.sh`: exit 0, `** BUILD SUCCEEDED **`.
- `./scripts/ios-test.sh`: exit 0, `** TEST SUCCEEDED **`; 4 unit tests and 1 UI test passed.
- `./scripts/preflight.sh`: passed.
- `git diff --check`: passed.
- Project inspection confirmed three targets, one `PetGroomerMarketplace` scheme, Swift 6, iOS 18.0, the required bundle identifier, and no `DEVELOPMENT_TEAM` setting.
- Static scan found no Supabase, Task Card, runtime mock/demo, launch-argument route, persistence, or network markers in the implementation.

## Assumptions

- “Team None” is represented by omitting `DEVELOPMENT_TEAM`; simulator builds use local ad-hoc signing.
- Xcode 26.5 native file-system-synchronized groups are acceptable because target membership is separated by the three generated root groups.
- Customer and groomer shells are intentionally reachable only through explicit `AppRootView(route:)` construction and previews; production injects `.authentication` directly.

## Risks

- The Xcode 26.5-generated project uses object version 77 and therefore expects a current Xcode toolchain.
- The fixed simulator destination reports both arm64 and x86_64 matches for the same simulator; `xcodebuild` consistently selects arm64 and all checks pass.
- Authentication, role onboarding, and marketplace features remain honest placeholders by scope; no backend behavior exists yet.
