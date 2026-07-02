# T-080 - Groomly Portfolio Fit Tags UI

## Status

Completed on 2026-06-25.

## Mode

Standard.

## User Request

Start implementing T-080 from the pet-fit evidence closure plan.

## Primary Task

Add owner-managed fit tags for existing portfolio photos through
`GroomerProfileRepository`, then expose per-photo tag controls on the groomer
Portfolio page.

Primary files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerProfile.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/GroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/GroomerProfileFeatureTests.swift`

## Scope

In scope:

- Add `GroomerPortfolioFitTag` and `GroomerPortfolioFitTagDraft` model types.
- Load existing `groomer_portfolio_fit_tags` through the profile repository
  boundary and group selections by portfolio photo ID.
- Save fit tags one portfolio photo at a time.
- Bound each photo to six selected tags in the Store before repository writes.
- Clear local tag state when a portfolio photo is deleted, while continuing to
  rely on the existing database FK cascade remotely.
- Add per-photo Fit Tags controls on the existing groomer Portfolio page.
- Cover load, save, limit enforcement, and delete-photo cleanup with targeted
  `GroomerProfileStore` tests.

Out of scope:

- Supabase schema, RLS, grant, RPC, Storage, or remote writes.
- Photo upload, Storage bucket behavior, signed URL behavior, or portfolio image
  rendering changes.
- New matching behavior, score weighting, evidence summaries, or match reasons.
- Customer-visible portfolio tags outside the existing match-reason path.
- Verified expertise, specialist labels, public directory browsing, or direct
  booking.

## Implementation Plan

1. Add failing Store tests for portfolio-tag load, one-photo save, limit
   enforcement, and delete-photo local cleanup.
2. Add model and repository protocol types for portfolio fit tags.
3. Implement Supabase direct table access behind `GroomerProfileRepository`.
4. Extend `GroomerProfileStore` with loaded tags, per-photo selected tag IDs,
   bounded toggling, save draft generation, and delete cleanup.
5. Add per-photo Fit Tags controls to the existing Portfolio photo cards.
6. Run targeted tests, iOS build validation, simulator launch, diff check, and
   durable memory updates.

## Validation

- Red targeted `GroomerProfileStore` tests: passed as a red check; the tests
  failed because `GroomerPortfolioFitTag` did not exist yet.
- Green targeted `GroomerProfileStore` tests passed:
  - `PetGroomerMarketplaceTests/GroomerProfileStoreTests/loadPopulatesProfileServicesAndPortfolio`
  - `PetGroomerMarketplaceTests/GroomerProfileStoreTests/savePortfolioFitTagsPersistsOnePhotoSelection`
  - `PetGroomerMarketplaceTests/GroomerProfileStoreTests/portfolioFitTagSelectionIsBoundedBeforeRepositoryCall`
  - `PetGroomerMarketplaceTests/GroomerProfileStoreTests/deletePortfolioPhotoClearsLocalFitTagsAfterRepositoryDelete`
- `./scripts/ios-build.sh`: passed.
- XcodeBuildMCP `build_run_sim`: passed; installed and launched
  `com.prinnyyy.PetGroomerMarketplace` on iPhone 17 Pro iOS 26.5.
- XcodeBuildMCP UI snapshot: passed for Account -> Portfolio navigation. The
  signed-in groomer account had no portfolio photos, so per-photo tag chips were
  validated by tests and previews rather than by seeded remote data.
- `git diff --check`: passed.

## Closeout

T-080 is complete. Groomers can now manage up to six canonical fit tags on each
existing Portfolio photo, saving one photo's tags at a time through the existing
T-066 `groomer_portfolio_fit_tags` table behind `GroomerProfileRepository`.

The change is iOS-only and keeps photo upload, Storage, matching, public
surfaces, and customer-visible tag display unchanged. It adds no schema, RLS,
grants, RPCs, Storage policy, public directory, direct booking, or expertise
proof behavior.

Next executable pet-fit task is T-081 only after explicit user authorization.
