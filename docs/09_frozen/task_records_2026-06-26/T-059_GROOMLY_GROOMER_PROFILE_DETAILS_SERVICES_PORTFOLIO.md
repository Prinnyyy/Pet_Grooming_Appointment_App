# T-059 Groomly Groomer Profile Details, Services, Portfolio, and Avatar

## Status

Completed.

## Mode

Deep. The user explicitly authorized the required backend migration after the stop point for adding full groomer address fields and multi-select service-location capability.

## User Request

- Continue refining the groomer Edit Profile page.
- Remove Services and Portfolio from Edit Profile and expose them as separate Account entries.
- Rename `Bio` UI copy to `Biography`.
- Change Years Of Experience to a fixed 0 through 5+ selector.
- Replace the old partial address fields with a full address entry using the customer request address-search pattern.
- Change Service Radius to a 5 through 50+ mile slider.
- Change Service Location from single-select to multi-select.
- Give Profile Visibility its own section title.
- Add a top avatar editor that can upload a groomer profile photo.

## Backend Plan

- Extend `public.groomer_profiles` with:
  - `base_street_address text`
  - `base_zip_code text`
  - `service_location_modes text[]`
- Keep legacy `service_location_mode` for compatibility, synced from the canonical multi-select array.
- Normalize `years_experience` into `0...5` and `service_radius_miles` into `5...50`.
- Replace request matching in `create_grooming_request` so compatible groomers can match when their `service_location_modes` contains the customer's `location_mode`.
- Reuse the existing private `avatars` bucket and `profiles.avatar_path`; no new Storage bucket was added.

## Implementation Summary

- Reworked Groomer Account:
  - Account menu now contains `Edit Profile`, `Services`, `Portfolio`, and `Availability`.
  - Services and Portfolio open their own pages instead of living inside Edit Profile.
- Reworked Edit Profile:
  - added a profile-photo upload card at the top;
  - kept only profile details, full address, service settings, and profile visibility;
  - `Biography` replaces `Bio`;
  - Years Of Experience is a fixed menu with `0 Years` through `5+ Years`;
  - full address includes street, city, state picker, ZIP, and MapKit autocomplete;
  - Service Radius is a 5...50 slider that displays `50+ mi`;
  - Service Location is a multi-select control;
  - Profile Visibility has its own titled section.
- Extended `GroomerProfile`, `GroomerProfileDraft`, repository protocol, Supabase adapter, Store, tests, and preview fake to carry the new fields.
- Added avatar upload through the existing `avatars` bucket and `profiles.avatar_path`.
- Added owner-only avatar download through the repository so Account and Edit Profile render the uploaded photo instead of only showing an uploaded-state marker.
- Extended Booking groomer-summary enrichment to include the groomer's new street/ZIP fields so customer-visits-groomer booking detail can show a full groomer address when present.

## Supabase Migration

- Local migration: `supabase/migrations/20260623233559_t059_groomer_profile_address_location_modes.sql`.
- Remote project: `lqmasbuqzvcvtawonjlb`.
- Supabase CLI migration application: success.
- Supabase CLI migration list confirmed remote version `20260623233559_t059_groomer_profile_address_location_modes`.
- Metadata checks confirmed:
  - `groomer_profiles.base_street_address`, `base_zip_code`, and `service_location_modes` exist;
  - `groomer_profiles_sync_location_modes` trigger exists;
  - authenticated has SELECT/UPDATE grants on the new columns;
  - helper functions and `create_grooming_request` have empty `search_path`;
  - `create_grooming_request` remains `SECURITY DEFINER` and granted only to `authenticated`/`service_role`;
  - location-mode normalization smoke returned canonical order.
- Advisor checks:
  - Security advisor reports existing controlled `SECURITY DEFINER` RPC WARNs, including `create_grooming_request`; this is the established project pattern for controlled multi-row writes.
  - Performance advisor reports existing unindexed-FK/unused-index INFOs and the new `groomer_profiles_location_modes_gin_idx` as unused immediately after deployment; no blocking issue was identified.

## Validation

- Red tests:
  - Targeted groomer profile tests failed before implementation because avatar/location-mode/profile fields did not exist.
  - Targeted groomer profile + booking tests later exposed an expected canonical legacy `serviceLocationMode` assertion mismatch after multi-select location modes were introduced; the assertion was corrected to the normalized first mode.
- Green targeted tests:
  - `xcodebuild test ... -only-testing:PetGroomerMarketplaceTests/GroomerProfileStoreTests/saveProfileSendsFullAddressFixedExperienceRadiusAndMultipleLocationModes`
  - Passed after implementation.
- Final validation:
  - Targeted `GroomerProfileStoreTests` + `BookingStoreTests` passed.
  - `./scripts/ios-test.sh` passed.
  - `git diff --check` passed.
  - `./scripts/ios-build.sh` passed.
  - Simulator launch passed on iPhone 16 Pro (iOS 18.4, `4CB97394-9112-4FBB-8C99-628B416B922F`) via `xcrun simctl install` + `xcrun simctl launch com.prinnyyy.PetGroomerMarketplace`, returning pid `14057`. XcodeBuildMCP session defaults were unavailable, so launch used the already-built simulator app.

## Risks and Follow-ups

- Existing active groomer rows may not have street/ZIP data yet. The app requires full address fields before saving an active profile, while the DB active-completeness constraint keeps street/ZIP optional to avoid breaking older active rows.
- The app can render the owner groomer's avatar from the private `avatars` bucket. Broader customer-facing groomer avatar presentation still needs a separate signed-URL or participant-readable image contract if required.
- Groomer availability remains separate from these profile fields and is still not connected to request matching or booking conflict checks.
