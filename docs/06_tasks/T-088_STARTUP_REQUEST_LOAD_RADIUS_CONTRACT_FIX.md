# T-088 Startup Request Load Radius Contract Fix

Mode: Deep

Date: 2026-06-26

## User Request

Fix the app startup error shown as:

- `We Could Not Update Requests`
- `We could not load grooming requests. Please try again.`

## Primary Task

Fix the Supabase request radius contract mismatch that can make request loading fail on app startup.

## Scope

Included:

- Align customer request loading with the hosted Supabase request radius column.
- Align groomer matched-request loading with the hosted Supabase request radius column.
- Align request creation RPC payloads with the hosted Supabase radius parameter.
- Add focused contract tests for the Supabase request radius naming.
- Update local task/memory records under this new task ID instead of appending the bugfix to an older task.

Out of scope:

- Supabase remote migration writes.
- Remote migration history reconciliation.
- Broad request UI or data model redesign.

## Root Cause

The app selected and decoded `travel_range_miles`, while the linked hosted Supabase project exposes the request radius contract as:

- `grooming_requests.travel_radius_miles`
- `create_grooming_request(..., p_travel_radius_miles integer default null)`

The missing column caused request repository loading to fail and the Store mapped that backend failure into the generic startup request-load banner.

## Fix

- Updated `SupabaseCustomerRequestRepository` to select and decode `travel_radius_miles`.
- Updated `CreateGroomingRequestParameters` to encode `p_travel_radius_miles`.
- Updated `SupabaseGroomerRequestRepository` to select and decode `travel_radius_miles`.
- Updated the local T-049 migration draft to use `travel_radius_miles` naming so local code and SQL contract names match.
- Added focused tests for customer rows, groomer matched-request rows, and create-request RPC payloads.

## Validation

- Red check failed first on the new contract tests while the old/private repository contract was still present.
- Targeted contract tests passed:
  - `xcodebuild -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/supabaseRequestContractUsesBackendTravelRadiusColumn -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/supabaseCreateRequestParametersUseBackendTravelRadiusRPCName -only-testing:PetGroomerMarketplaceTests/GroomerRequestsStoreTests/supabaseMatchedRequestContractUsesBackendTravelRadiusColumn test`
- `./scripts/ios-build.sh` passed.
- `git diff --check` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17 Pro` simulator (`45D452E8-DC6C-4CD4-A747-4D21671E68A6`) with no diagnostics errors.
- Runtime UI snapshot landed on Groomer Requests empty state with no request-load error banner.
- Runtime logs contained no old-column or PostgREST column errors.

## Closeout

Status: completed

Changed files:

- `docs/06_tasks/T-088_STARTUP_REQUEST_LOAD_RADIUS_CONTRACT_FIX.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseCustomerRequestRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerRequestRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/GroomerRequestFeatureTests.swift`
- `supabase/migrations/20260626175855_t049_request_location_and_image_readback.sql`

Risks:

- Linked remote and local Supabase migration history are divergent. Do not blindly push the local T-049 migration; handle remote migration reconciliation as a separate explicitly approved backend task.
- This bugfix verified the current logged-in startup surface on the simulator as Groomer Requests. Customer Requests uses the same corrected customer repository contract but was not manually navigated with a customer session in this run.
