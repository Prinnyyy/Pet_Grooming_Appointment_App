# T-076 - Groomly Pet-Fit Signal Vocabulary Bridge

## Status

Completed on 2026-06-25.

## Mode

Standard.

## User Request

Start implementing T-076 from the pet-fit evidence closure plan.

## Primary Task

Add one pure Swift vocabulary type for canonical pet-fit signals shared by
claims, portfolio tags, structured reviews, and request previews.

Primary files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomingRequestTaxonomy.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/PetFitTaxonomyTests.swift`

## Scope

In scope:

- Add `PetFitSignal` with canonical `traitType`, `traitValue`, `title`, and grouping metadata.
- Reuse existing `PetBreedGroup`, `PetCareFlag`, `PetFitTrait`, `CustomerPetSizeCode`, and `GroomingServiceType`.
- Keep the implementation pure Swift with no repository, UI, or Supabase dependency.
- Add focused tests proving Swift trait pairs align with deployed SQL constraints.

Out of scope:

- Supabase schema, RLS, RPC, Storage, or remote writes.
- Claim management UI, portfolio tag UI, review submission UI, or request preview UI.
- Matching score changes, evidence summary changes, public directory browsing, direct booking, or slot discovery.

## Implementation Plan

1. Add failing taxonomy tests for canonical signal pairs and grouping metadata.
2. Implement `PetFitSignal` in the existing taxonomy model.
3. Re-run targeted taxonomy tests.
4. Run `git diff --check` and one `./scripts/ios-build.sh` attempt.
5. Update task closeout and durable memory.

## Validation

- Red targeted `PetFitTaxonomyTests`: passed as a red check; the tests failed because `PetFitSignal` did not exist.
- Green targeted `PetFitTaxonomyTests`: passed after implementation.
- `./scripts/ios-build.sh`: passed.
- `git diff --check`: passed.

Simulator launch is skipped because T-076 changes pure model/test code and has no visible app behavior.

## Closeout

T-076 is complete. `PetFitSignal` now exposes canonical Swift-side `traitType` and `traitValue` pairs for breed group, size band, care flag, and service-fit signals, with stable grouping metadata and titles. `PetFitTrait` raw values now use the backend `service_fit` snake_case values. Request-context signal derivation reuses existing pet snapshot taxonomy and service type logic without adding repository, UI, Supabase, Storage, or matching behavior.

Next executable pet-fit task is T-077 only after explicit user authorization.
