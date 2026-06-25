# T-064 - Groomly Pet-Fit Taxonomy Foundation

## Status

In progress.

## Mode

Standard.

## User Request

Execute T-064 according to the T-063 pet-fit matching plan, after first organizing the task boundary.

## Primary Task

Add the pure Swift pet-fit taxonomy foundation needed for later request-first matching evidence:

- `PetBreedGroup`
- `PetCareFlag`
- `PetFitTrait`
- `serviceFit`
- focused unit tests for Westie/terrier, poodle/curly coat, anxious care flags, and senior/age handling

## Out of Scope

- Supabase migrations, schema/RLS/RPC changes, Storage changes, or remote writes.
- Public groomer directory browsing, direct customer slot booking, AI/ML recommendations, payments, or calendar enforcement.
- UI rewrites or new navigation.
- Replacing the existing Open Request -> Groomer Offer -> Customer Confirmation -> Booking product model.
- T-065+ backend pet-fit evidence tasks.

## Existing Mapping

- Add pure taxonomy/domain helpers in `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomingRequestTaxonomy.swift`.
- Use existing `CustomerPetBreed`, `CustomerPetTemperament`, `GroomingServiceType`, and request pet snapshot fields.
- Keep backend access behind current repositories; this task should not introduce repository or Supabase code.

## Implementation Plan

1. Add failing focused unit tests for the four required taxonomy behaviors.
2. Implement the smallest pure Swift enums/helpers needed to pass those tests.
3. Run targeted tests, then `git diff --check` and one `./scripts/ios-build.sh` attempt.
4. Close out this task doc and memory/ledger entries if validation reaches completion.

## Required Validation

- Red targeted unit test run before implementation.
- Green targeted unit test run after implementation.
- `git diff --check`
- `./scripts/ios-build.sh`

Simulator launch is skipped because T-064 is model/test-only and has no visible app behavior change.

## Stop Condition

Stop and report if the implementation requires new persistence, Supabase schema/RLS/RPC changes, a new repository path, or product behavior beyond pure local taxonomy derivation.

## Closeout

Status: completed

Changed files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomingRequestTaxonomy.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/PetFitTaxonomyTests.swift`
- `docs/06_tasks/T-064_GROOMLY_PET_FIT_TAXONOMY_FOUNDATION.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- Red targeted test run failed before implementation because `PetBreedGroup`, `PetCareFlag`, and `PetFitTrait.serviceFit` did not exist.
- Targeted `PetFitTaxonomyTests` passed after implementation.
- `git diff --check`: passed
- `./scripts/ios-build.sh`: passed

Simulator launch:

- skipped because model/test-only

Risks:

- T-064 is local iOS taxonomy only. It does not deploy backend traits, evidence tables, matching score changes, availability enforcement, or UI surfacing.

Next:

- T-065+ backend pet-fit tasks still require separate task files and explicit Supabase migration authorization before any remote writes.
