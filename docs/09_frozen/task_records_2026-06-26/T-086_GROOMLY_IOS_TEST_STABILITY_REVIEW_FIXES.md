# T-086: Groomly iOS Test Stability Review Fixes

## Status

- Status: completed
- Date: 2026-06-26
- Mode: Standard
- Branch: `codex/pet-fit-structure-cleanup`

## Scope

Address post-review iOS validation issues without changing production auth semantics:

- Make `AppLaunchSmokeTests.testNormalLaunchShowsOnlyAuthenticationRoot()` deterministic when a simulator has a persisted Supabase session.
- Remove the default hard lock on `OS=26.5,name=iPhone 17 Pro` from the standard build/test scripts.

No Supabase schema, RLS, RPC, Storage, repository data contract, or user-facing app flow was changed.

## Files Changed

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/App/AppLaunchConfiguration.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/App/AppComposition.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/SignedOutAuthSessionRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/AppEntryModelsTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceUITests/AppLaunchSmokeTests.swift`
- `scripts/ios-destination.sh`
- `scripts/ios-build.sh`
- `scripts/ios-test.sh`
- `docs/04_ios/IOS_BUILD_AND_TESTING.md`
- `docs/06_tasks/T-086_GROOMLY_IOS_TEST_STABILITY_REVIEW_FIXES.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

## Implementation

- Added `AppLaunchConfiguration` with `--groomly-ui-test-signed-out-auth`.
- Added `SignedOutAuthSessionRepository`, a local repository used only when that launch argument is present. It returns no cached session and finishes its state stream, preserving normal Supabase session restore for ordinary app launches.
- Updated the launch smoke UI test to pass the signed-out auth launch argument before `app.launch()`.
- Added `scripts/ios-destination.sh`:
  - build defaults to `generic/platform=iOS Simulator`;
  - test auto-discovers a concrete available iPhone simulator and passes it by UDID;
  - `CODEX_IOS_DESTINATION` still overrides both scripts.
- Updated iOS build/testing docs to describe the generic build destination, auto-discovered test destination, and CI override path.

## Validation

- RED: targeted `AppEntryModelsTests` failed before implementation because `AppLaunchConfiguration` and `SignedOutAuthSessionRepository` did not exist.
- GREEN: targeted `AppEntryModelsTests` passed after implementation.
- Focused auth/UI smoke check passed for `AuthenticationStoreTests` and `AppLaunchSmokeTests.testNormalLaunchShowsOnlyAuthenticationRoot`.
- `bash -n scripts/ios-destination.sh scripts/ios-build.sh scripts/ios-test.sh` passed.
- Destination helper check returned `generic/platform=iOS Simulator` for build and a concrete iPhone simulator UDID for test.
- `./scripts/ios-build.sh` passed using `generic/platform=iOS Simulator`.
- `./scripts/ios-test.sh` passed using the auto-discovered iPhone 17 Pro simulator UDID, including the launch smoke test.
- `git diff --check` passed.

## Result

T-086 is complete. The standard iOS test command is no longer sensitive to persisted Supabase auth state in the simulator, and the default scripts no longer require one exact simulator runtime/device pair.
