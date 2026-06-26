# T-079 - Groomly Groomer Claimed Fit Signals UI

## Status

Completed on 2026-06-25.

## Mode

Standard.

## User Request

Start implementing T-079 from the pet-fit evidence closure plan.

## Primary Task

Add groomer-owned fit-claim loading and saving behind
`GroomerProfileRepository`, then expose a dedicated Groomer Account page where
groomers can activate or deactivate bounded starter fit signals.

Primary files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerProfile.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/GroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/GroomerProfileFeatureTests.swift`

## Scope

In scope:

- Add `GroomerFitClaim` and `GroomerFitClaimDraft` model types.
- Load existing `groomer_fit_claims` through the profile repository boundary.
- Save active and inactive claim states with Supabase upsert on
  `groomer_id,trait_type,trait_value`.
- Bound active selections to six signals in the Store before repository writes.
- Add a Groomer Account `Fit Signals` page with starter-signal copy.
- Prioritize service-fit, breed, and care groups, while keeping size-band
  claims manageable as lower-priority signals.
- Cover load, save, inactive toggling, and limit enforcement with targeted
  `GroomerProfileStore` tests.

Out of scope:

- Supabase schema, RLS, grant, RPC, Storage, or remote writes.
- New matching behavior, score weighting, evidence summaries, or match reasons.
- Verified expertise, specialist labels, public directory browsing, direct
  booking, portfolio fit tags, or customer-facing claim displays.

## Implementation Plan

1. Add failing Store tests for fit-claim load, save, inactive toggling, and
   active-selection limit enforcement.
2. Add model and repository protocol types for groomer fit claims.
3. Implement Supabase direct table access behind `GroomerProfileRepository`.
4. Extend `GroomerProfileStore` with loaded claims, selected claim IDs, bounded
   toggling, and save draft generation.
5. Add a Groomer Account `Fit Signals` editor page using existing Groomly
   primitives.
6. Run targeted tests, iOS build validation, simulator launch, diff check, and
   durable memory updates.

## Validation

- Red targeted `GroomerProfileStore` tests: passed as a red check; the tests
  failed because `GroomerFitClaim` and `GroomerFitClaimDraft` did not exist yet.
- Green targeted `GroomerProfileStore` tests passed:
  - `PetGroomerMarketplaceTests/GroomerProfileStoreTests/loadPopulatesProfileServicesAndPortfolio`
  - `PetGroomerMarketplaceTests/GroomerProfileStoreTests/saveFitClaimsPersistsActiveAndInactiveSupportedSignals`
  - `PetGroomerMarketplaceTests/GroomerProfileStoreTests/fitClaimSelectionIsBoundedBeforeRepositoryCall`
- `./scripts/ios-build.sh`: passed.
- XcodeBuildMCP `build_run_sim`: passed; installed and launched
  `com.prinnyyy.PetGroomerMarketplace` on iPhone 17 Pro iOS 26.5.
- XcodeBuildMCP UI snapshot: passed; Groomer Account showed `Fit Signals`, and
  the Fit Signals page showed the bounded selector groups plus bottom
  `Save Fit Signals` action.
- `git diff --check`: passed.

## Closeout

T-079 is complete. Groomers can now open Account -> Fit Signals, choose up to
six starter signals, and save active/inactive claim state through the existing
T-066 `groomer_fit_claims` table. The UI copy frames claims as routing signals
that improve with completed bookings and reviews, not proof of expertise.

The change is iOS-only and uses existing Supabase table access behind the
profile repository boundary. It adds no schema, RLS, grants, RPCs, Storage,
matching behavior, portfolio tags, public directory, direct booking, or
customer-facing claim display.

Next executable pet-fit task is T-080 only after explicit user authorization.
