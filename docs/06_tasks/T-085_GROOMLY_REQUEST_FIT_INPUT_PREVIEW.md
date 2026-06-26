# T-085: Groomly Request Fit Input Preview

## Status

- Status: completed
- Date: 2026-06-26
- Mode: Standard
- Branch: `codex/pet-fit-structure-cleanup`

## Scope

Show customers the app's interpreted pet-fit needs on the Customer Request wizard Review step before publishing.

The preview is derived from the selected pet and selected service using the existing canonical `PetFitSignal` vocabulary. It does not add backend fields, schema, RLS, RPCs, Storage behavior, matching behavior, or a new request state.

## Files Changed

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `docs/06_tasks/T-085_GROOMLY_REQUEST_FIT_INPUT_PREVIEW.md`
- `docs/06_tasks/T-075_TO_T-085_GROOMLY_PET_FIT_EVIDENCE_CLOSURE_PLAN.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

## Implementation

- Added `CustomerRequestsStore.requestFitInputSignals(referenceDate:)`, which turns the currently selected `CustomerPet` into the same request pet snapshot shape used by matching and derives `PetFitSignal` values from the selected service type.
- Added `CustomerRequestWizardFitInputPresentation` so Review-step chips use customer-readable labels such as `Breed`, `Pet Size`, `Care Need`, and `Service Fit` instead of backend trait keys.
- Added a `Fit Needs` card to the Review step. It shows the derived chips in an adaptive grid, or a neutral empty state when no specific needs are detected.

## Validation

- RED: targeted `CustomerRequestsStoreTests` failed before implementation because `CustomerRequestsStore` had no `requestFitInputSignals`.
- GREEN: targeted `CustomerRequestsStoreTests` passed after implementation, including the new derived-signal and readable-label tests.
- `./scripts/ios-build.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17 Pro` iOS 26.5 with no warnings/errors, and screenshot capture succeeded.
- `git diff --check` passed.

## Result

T-085 is complete. Customers can now see the request's derived fit needs before publishing, using existing pet/service inputs and the existing canonical signal vocabulary. The publish draft and backend contract are unchanged.
