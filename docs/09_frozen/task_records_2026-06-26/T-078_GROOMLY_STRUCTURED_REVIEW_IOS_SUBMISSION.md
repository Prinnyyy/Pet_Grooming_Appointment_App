# T-078 - Groomly Structured Review iOS Submission

## Status

Completed on 2026-06-25.

## Mode

Standard.

## User Request

Start implementing T-078 from the pet-fit evidence closure plan.

## Primary Task

Extend the iOS review draft, Store, Supabase RPC encoding, and review form so
customers can optionally submit structured pet-fit review outcomes through the
existing `create_review` RPC parameter `p_pet_fit_outcomes`.

Primary files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Booking.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/BookingFeatureTests.swift`

## Scope

In scope:

- Extend `BookingReviewDraft` with optional structured pet-fit outcomes.
- Encode `p_pet_fit_outcomes` in `CreateReviewParameters`.
- Keep rating/content-only reviews valid by sending an empty outcomes array by default.
- Add review-form controls that default every suggested signal to `Skip`.
- Let customers actively select `Went Well` or `Needs Care` only when confident.
- Cover Store forwarding, RPC payload encoding, and selection presentation with targeted tests.

Out of scope:

- Supabase schema, RLS, RPC signature, Storage, or remote writes.
- Public accusations, certifications, specialist labels, or expert-status claims.
- Groomer claim UI, portfolio tag UI, evidence dashboard, matching score changes, public directory browsing, direct booking, or slot discovery.

## Implementation Plan

1. Add failing tests for structured review draft forwarding, empty defaults, selected outcomes, and RPC payload encoding.
2. Add `BookingReviewPetFitOutcomeDraft`, outcome selection state, and default empty outcomes to the booking model layer.
3. Extend `BookingsStore.createReview` while preserving its existing rating/content call shape through a default argument.
4. Extend `SupabaseBookingRepository.CreateReviewParameters` to encode `p_pet_fit_outcomes`.
5. Add optional pet-fit note controls to the review form without direct Supabase access from SwiftUI.
6. Run targeted tests, build validation, diff check, simulator launch, and durable memory updates.

## Validation

- Red targeted booking/review tests: passed as a red check; the tests failed because the structured review outcome model, selection helper, Store argument, and `CreateReviewParameters` access/encoding did not exist yet.
- Green targeted booking/review tests passed:
  - `PetGroomerMarketplaceTests/BookingsStoreTests/customerSubmitsStructuredPetFitReviewOutcomes`
  - `PetGroomerMarketplaceTests/BookingsStoreTests/reviewPetFitOutcomeSelectionsDefaultToEmptyOutcomes`
  - `PetGroomerMarketplaceTests/BookingsStoreTests/reviewPetFitOutcomeSelectionsBuildSelectedOutcomesOnly`
  - `PetGroomerMarketplaceTests/BookingsStoreTests/createReviewParametersEncodePetFitOutcomesRpcPayload`
  - `PetGroomerMarketplaceTests/BookingsStoreTests/createReviewParametersEncodeEmptyPetFitOutcomes`
- `./scripts/ios-build.sh`: passed.
- XcodeBuildMCP `build_run_sim`: passed; installed and launched `com.prinnyyy.PetGroomerMarketplace` on iPhone 17 Pro iOS 26.5.
- `git diff --check`: passed.

## Closeout

T-078 is complete. Customers can now submit optional structured pet-fit outcomes from the existing completed-booking review form. Reviewable signals still come from the T-077 booking request context; the form starts every signal at `Skip`, and only selected `Went Well` or `Needs Care` values are encoded into `p_pet_fit_outcomes`.

The change is iOS-only and uses the existing T-067 backend contract. It adds no schema, RLS, Storage, matching, directory, direct-booking, claim-management, or portfolio-tag behavior.

Next executable pet-fit task is T-079 only after explicit user authorization.
