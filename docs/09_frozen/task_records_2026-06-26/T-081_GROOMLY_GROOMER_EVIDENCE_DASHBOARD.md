# T-081 - Groomly Groomer Evidence Dashboard

## Status

Completed on 2026-06-26.

## Mode

Standard.

## User Request

Continue T-081 after the T-081A backend owner-visibility blocker was resolved.

## Primary Task

Surface earned pet-fit evidence in Groomer Account using the T-081A
`get_my_groomer_pet_fit_evidence_summary()` owner aggregate RPC behind
`GroomerProfileRepository`.

The dashboard shows only aggregate evidence rows for the signed-in groomer:
completed booking counts, structured review outcome counts, safe evidence
timestamps, and confidence tiers.

Primary files changed:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerProfile.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/GroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/GroomerProfileFeatureTests.swift`

## Implementation

- Added `GroomerPetFitEvidenceSummary` and
  `GroomerPetFitEvidenceConfidenceTier`.
- Added `petFitEvidenceSummary(groomerID:)` to
  `GroomerProfileRepository`.
- Implemented the Supabase adapter by calling
  `get_my_groomer_pet_fit_evidence_summary()` through `.rpc(...).execute()`.
- Mapped RPC rows to canonical `PetFitSignal` values and dropped unknown trait
  rows instead of inventing UI labels.
- Filtered returned rows to the active groomer ID in the repository/store path.
- Loaded evidence alongside the groomer profile in `GroomerProfileStore`.
- Sorted evidence by confidence tier, completed booking count, positive outcome
  count, structured outcome count, and signal order.
- Added a Groomer Account `Evidence Dashboard` entry and a read-only dashboard
  page with summary totals, confidence chips, per-signal aggregate counts, and
  an empty state.
- Updated the fake repository, previews, and focused Store tests.
- Fixed a validation-surfaced Swift concurrency warning in the existing avatar
  `PhotosPicker` label by capturing local display values before the closure.

## Boundaries

- No Supabase schema, RLS, grant, RPC, Storage, matching, or lifecycle behavior
  changed in T-081.
- No direct SwiftUI or repository reads of raw request, customer, pet, booking,
  review, content, or `pet_snapshot` details were added.
- No customer-facing evidence surface, public groomer directory, direct booking,
  slot discovery, expertise proof, or ML ranking behavior was added.
- Unknown trait rows are ignored; unknown confidence tiers fall back to low.
- The original `groomer_pet_fit_evidence_summary` view remains a backend
  aggregate source. Owner iOS reads use the T-081A RPC contract.

## Validation

- RED targeted Store test failed before implementation because
  `GroomerPetFitEvidenceSummary` and
  `GroomerPetFitEvidenceConfidenceTier` did not exist.
- GREEN targeted evidence Store test passed after implementation.
- Focused `GroomerProfileStoreTests` passed.
- `./scripts/ios-build.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on iPhone 17 Pro iOS 26.5 with no final
  warnings or errors.
- XcodeBuildMCP UI snapshots confirmed Account contains `Evidence Dashboard`
  and that the dashboard page renders its aggregate summary and empty state.
- `git diff --check` passed.

## Closeout

T-081 is complete. Groomer Account now has a repository-backed, owner-only
Evidence Dashboard that consumes the T-081A aggregate RPC and stays within the
request-first marketplace model. Stop here unless the user asks for commit/push
or explicitly starts a later T-082+ task.
