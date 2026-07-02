# T-083: Groomly Score Display De-Emphasis

## Status

- Status: completed
- Date: 2026-06-26
- Mode: Standard
- Branch: `codex/pet-fit-structure-cleanup`

## Scope

Replace raw score-forward match display in existing groomer request and customer offer evidence surfaces with explanation-first copy. Keep backend `match_score` available in model data, but avoid presenting it as a public ability percentage.

## Files Changed

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/CustomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Requests/GroomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/GroomerRequestFeatureTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `docs/06_tasks/T-075_TO_T-085_GROOMLY_PET_FIT_EVIDENCE_CLOSURE_PLAN.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

## Implementation Notes

- `GroomerMatchedRequest.matchSummary` now shows `Fit evidence available` when an existing backend reason is present instead of rendering a rounded `match_score` as match copy.
- Groomer and customer fit-evidence presentation keeps the trimmed backend reason, but exposes no score text.
- Backend reason copy is summarized into explanation-first sections:
  - `Location And Service Fit`
  - `Earned Evidence`
  - `Starter Signals`
  - `Fit Evidence` fallback for unrecognized reason text
- The groomer detail view no longer falls back to a visible raw `Score` metadata row when a score exists without presentation copy.
- No Supabase schema, RLS, RPC, repository, matching, Storage, or lifecycle behavior changed.

## Validation

- RED: class-level `GroomerRequestsStoreTests` failed before implementation for the new no-raw-score fit evidence and match summary expectations.
- RED: class-level `CustomerRequestsStoreTests` failed before implementation for the new customer offer no-raw-score expectation.
- GREEN: `xcodebuild test -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro' -only-testing:PetGroomerMarketplaceTests/GroomerRequestsStoreTests` passed.
- GREEN: `xcodebuild test -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro' -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` passed. A parallel attempt hit an Xcode build database lock, then the sequential rerun passed.
- GREEN: `./scripts/ios-build.sh` passed.
- GREEN: XcodeBuildMCP `build_run_sim` passed on `iPhone 17 Pro` iOS 26.5 with no warnings/errors, and screenshot capture confirmed the app rendered.
- GREEN: `git diff --check` passed.

## Risks And Follow-Up

- Existing persisted `request_matches.match_score` values are not recalculated or backfilled.
- The score remains available internally through existing backend/model data for future calibrated use, but current customer/groomer UI no longer presents it as a public ability grade.
- T-084 remains a separate, explicit authorization task for end-to-end rollback SQL validation.
