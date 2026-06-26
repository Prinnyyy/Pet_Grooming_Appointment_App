# T-077 - Groomly Booking Pet-Fit Context Enrichment

## Status

Completed on 2026-06-25.

## Mode

Standard.

## User Request

Start implementing T-077 from the pet-fit evidence closure plan.

## Primary Task

Extend booking model and repository enrichment so completed bookings expose the
request pet snapshot context needed for structured review suggestions.

Primary files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Booking.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/BookingFeatureTests.swift`

## Scope

In scope:

- Add optional request pet snapshot context to `Booking`.
- Reuse the existing booking repository request enrichment path.
- Derive `reviewableFitSignals` in the model layer with the T-076 `PetFitSignal` vocabulary.
- Cover poodle, terrier, anxious, senior, and weight-derived size contexts with targeted tests.

Out of scope:

- Supabase schema, RLS, RPC, Storage, or remote writes.
- Direct Supabase access from SwiftUI views.
- Structured review submission UI or RPC encoding.
- Claim management UI, portfolio tag UI, matching changes, public directory browsing, direct booking, or slot discovery.

## Implementation Plan

1. Add failing booking tests for completed-booking signal derivation.
2. Add request pet snapshot context and `reviewableFitSignals` to `Booking`.
3. Extend the existing `SupabaseBookingRepository` request enrichment select to include `pet_snapshot`.
4. Re-run targeted booking tests.
5. Run `git diff --check` and one `./scripts/ios-build.sh` attempt.
6. Update task closeout and durable memory.

## Validation

- Red targeted booking tests: passed as a red check; the tests failed because `Booking` did not expose `reviewableFitSignals` or accept `requestPetSnapshot`.
- Green targeted booking tests passed:
  - `PetGroomerMarketplaceTests/BookingsStoreTests/completedBookingDerivesReviewablePetFitSignalsFromRequestContext`
  - `PetGroomerMarketplaceTests/BookingsStoreTests/reviewablePetFitSignalsRequireCompletedBookingAndRequestContext`
  - `PetGroomerMarketplaceTests/BookingsStoreTests/bookingReviewableSignalsIncludeTerrierServiceFitAndSizeContext`
- `./scripts/ios-build.sh`: passed.
- `git diff --check`: passed.

Simulator launch is skipped because T-077 changes model/repository enrichment and tests, with no visible app behavior.

## Closeout

T-077 is complete. `Booking` now carries optional `requestPetSnapshot` context and derives `reviewableFitSignals` only for completed bookings with a known service type and request snapshot. `SupabaseBookingRepository` reuses its existing related grooming-request enrichment path and adds `pet_snapshot` to the request query, keeping SwiftUI views out of backend access.

Next executable pet-fit task is T-078 only after explicit user authorization.
