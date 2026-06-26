# T-090 Customer Home Request Load Legacy Location Mode Fix

Mode: Standard

Date: 2026-06-26

## User Request

Fix the customer Home request-loading toast that still appeared after quick login.

## Primary Task

Restore customer Home request loading for hosted request rows that still use legacy location-mode values.

## Root Cause

Customer Home loads `CustomerRequestsStore`, which decodes Supabase `grooming_requests` rows. The hosted customer account had existing rows with legacy `location_mode` values:

- `customer_comes_to_groomer`
- `groomer_comes_to_customer`

The app model only accepted the newer local values `visit_groomer` and `come_to_me`, so row decoding failed and the Home surface displayed `We Could Not Update Requests`.

## Scope

Included:

- Add decoding compatibility for legacy and current request location-mode values.
- Keep app-facing request models non-optional.
- Keep null/missing legacy `location_mode` rows defaulting to `.comeToMe`.
- Add regression coverage for customer and groomer Supabase request row decoding.

Out of scope:

- Supabase schema writes or migration reconciliation.
- UI redesign or toast suppression.
- Request-specific attachment work.

## Implementation Notes

- `GroomingRequestLocationMode` now uses a custom decoder that maps both current and legacy raw values to the existing app enum cases.
- Customer and groomer Supabase row adapters treat null `location_mode` as `.comeToMe`.
- No remote database writes were made. A read-only Supabase query was used to inspect the hosted customer request row shape.

## Validation

- Red check: `xcodebuild test -quiet -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' -only-testing:PetGroomerMarketplaceTests` failed on the new legacy location-mode decoding tests before the decoder fix.
- Green check: the same unit target passed after the decoder fix.
- `./scripts/ios-build.sh` passed.
- `git diff --check` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17 Pro` simulator (`45D452E8-DC6C-4CD4-A747-4D21671E68A6`) with no diagnostics errors.
- Simulator UI snapshot showed customer Home rendering an Active Request card and no `We Could Not Update Requests` toast.

## Closeout

Status: completed

Changed files:

- `docs/06_tasks/T-090_CUSTOMER_HOME_REQUEST_LOAD_LEGACY_LOCATION_MODE_FIX.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/CustomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseCustomerRequestRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerRequestRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/GroomerRequestFeatureTests.swift`

Risks:

- This is client-side compatibility only. The linked remote and local Supabase migration history still diverge and should be reconciled separately before any remote migration writes.
