# T-050 Groomly Pet Data Contract and Add Pet UI

## Status

- Status: Completed
- Mode: Deep
- Started: 2026-06-23
- Owner: Codex

## User Request

Modify customer pet profile data types and update the Add Pet page:

- `species` becomes a fixed option with Dog and Cat.
- `breed` becomes a fixed option list of common pet breeds plus Unspecified.
- `size` is no longer user-entered and is derived from `weight_lbs`.
- `birthday` uses date input.
- `temperament` becomes fixed common temperament options.
- Add Pet UI follows the new data contract with pickers, a weight slider, no size input, and date selection.
- Add or reuse a storage container for pet photos.

## Initial Audit

- `pet-photos` private Storage bucket and `pet_photos` metadata table already exist from T-008/T-009.
- iOS already has `CustomerPetPhotoPath`, `CustomerPetRepository.uploadPhoto`, `SupabaseCustomerPetRepository.uploadPhoto`, and post-create photo upload/delete UI.
- The current Add/Edit Pet form still uses free-text `species`, `breed`, `size`, `birthday`, and `temperament`.
- Existing request creation snapshots `pets%rowtype`, including `size`, so `size` should remain stored for compatibility but become client/server-derived from `weight_lbs`.
- This run will prepare a local Supabase migration but will not deploy it remotely without separate explicit remote-write authorization.

## Implementation Plan

1. Add failing tests for fixed pet taxonomy, weight-to-size mapping, and create-time pending photo upload.
2. Add shared iOS pet taxonomy enums/options while preserving repository boundaries.
3. Update `CustomerPetsStore` to validate fixed options, derive `size`, use date-backed birthday state, stage pending photos for new pets, and upload staged photos after create.
4. Update `CustomerPetFormView` to use pickers, chips/menus, a weight slider, `DatePicker`, and a photo picker.
5. Add a local Supabase migration tightening `pets` constraints to the fixed contract and deriving `size` from `weight_lbs` with triggers/checks.
6. Update backend docs, task ledger, and durable memory after validation.

## Validation Plan

- Run targeted red tests before implementation and verify they fail.
- Run targeted Pet tests after implementation.
- Run `git diff --check`.
- Run `./scripts/ios-build.sh`.
- Launch the app in iOS Simulator because the Add/Edit Pet UI changes.

## Notes

- The existing `pet-photos` bucket is the correct pet photo storage container; adding a second bucket would duplicate policy and repository paths.
- Long term, if product needs breed lists filtered by species beyond this fixed in-app list, the list should move to a server-managed taxonomy table.

## Implementation Summary

- Added shared iOS taxonomy for `CustomerPetSpecies`, `CustomerPetBreed`, `CustomerPetSizeCode`, and `CustomerPetTemperament`.
- Kept the existing `CustomerPet`/`CustomerPetDraft` repository string contract to avoid broad repository churn, while the Store now emits only fixed values.
- `CustomerPetsStore` now:
  - uses fixed species/breed/temperament state;
  - uses a numeric weight state clamped to the UI range;
  - derives `size` from weight before repository save;
  - stores birthday from a date value instead of free text;
  - stages Add/Edit Pet form photos and uploads them through `CustomerPetRepository.uploadPhoto` after the pet exists.
- `CustomerPetFormView` now uses Picker controls for fixed fields, a Slider for weight, a DatePicker behind a `Birthday Known` toggle, removes the user-editable Size field, and adds a PhotosPicker-backed form photo section.
- Customer pet/request UI display paths now use `CustomerPet` display helpers so existing raw strings and fixed values present consistently.
- Prepared local migration `supabase/migrations/20260623013113_t050_pet_fixed_taxonomy_derived_size.sql`:
  - reuses and idempotently confirms the existing private `pet-photos` bucket configuration;
  - normalizes existing pet data to fixed species/breed/temperament values;
  - backfills missing weight to `10`;
  - adds `app_private.pet_size_code_for_weight_lbs`;
  - adds a trigger to keep `pets.size` derived from `pets.weight_lbs`;
  - tightens check constraints for fixed options and weight range.
- Review follow-up: granted `execute` on the pure immutable `app_private.pet_size_code_for_weight_lbs(numeric)` mapping function to `authenticated` so authenticated `pets` writes can satisfy the derived-size check after deployment. The trigger function remains private and `security invoker`.

## Validation Log

- Red test command: `xcodebuild test -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PetGroomerMarketplaceTests/CustomerPetsStoreTests` failed before implementation because the fixed taxonomy, date state, pending photo API, and upload tracking did not exist.
- Green targeted test command: same command passed after implementation.
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on the `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`) with no diagnostics warnings or errors. The app is launched for inspection.
- Review follow-up validation: `git diff --check` passed and `./scripts/ios-test.sh` passed after the function grant fix.

## Deployment Notes

- No remote Supabase migration was applied in this run.
- The local T-050 migration should be deployed only after explicit remote-write authorization for project `lqmasbuqzvcvtawonjlb`, then validated with an authenticated pet insert/update smoke test.

## Closeout

- Completed the iOS pet data/UI update and local backend contract draft.
- Reused the existing `pet-photos` private Storage bucket and `CustomerPetRepository.uploadPhoto` path rather than adding a duplicate container.
- Size remains stored for compatibility with existing request snapshots, but it is now derived from weight in the Store and guarded by the local migration trigger/check.
- Remaining backend step: apply and validate the local T-050 Supabase migration after explicit remote-write authorization.
