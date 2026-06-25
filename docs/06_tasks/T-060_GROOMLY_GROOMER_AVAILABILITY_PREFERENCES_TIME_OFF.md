# T-060 Groomly Groomer Availability Preferences and Time Off

## Status

Completed.

## Mode

Deep. The screenshot implied new persistence for booking preferences and time off. Codex stopped with a new-feature report, and the user explicitly authorized the backend work with "授权".

## User Request

Source screenshots:

- `docs/08_design/screenshots/screenshot-2026-06-23-pm-06-56-11.png`
- `docs/08_design/screenshots/screenshot-2026-06-23-pm-06-56-24.png`

Add functionality to the groomer Availability page based on the two screenshots.

## Screenshot Analysis

- The long oval Customer/Groomer switch above the phone frame is an external prototype annotation and was ignored per workflow rule.
- Existing-feature mapping:
  - `Available for bookings`: reuses `groomer_profiles.is_active`.
  - `Weekly Hours`: reuses T-058 `groomer_availability_windows`.
- Newly authorized features:
  - `Booking Preferences`: max appointments per day, minimum advance notice, auto-accept bookings.
  - `Time Off`: groomer-owned unavailable date windows with create/delete UI.

## Backend Plan

- Add `public.groomer_booking_preferences` with one row per groomer:
  - `max_appointments_per_day` from 1 to 12.
  - `minimum_advance_notice_days` from 0 to 2.
  - `auto_accept_bookings`.
- Add `public.groomer_time_off_windows`:
  - owner `groomer_id`, title, start/end date.
- Enable RLS and explicit Data API grants.
- Use owner-only `SELECT`/`INSERT`/`UPDATE`/`DELETE` policies for authenticated non-anonymous groomers.
- Do not connect these settings to request matching, booking conflict detection, or customer-facing availability in this task.

## Implementation Summary

- Added `GroomerBookingPreferences`, `GroomerBookingPreferencesDraft`, `GroomerTimeOffWindow`, and `GroomerTimeOffDraft`.
- Extended `GroomerProfileRepository` and `SupabaseGroomerProfileRepository` with:
  - `bookingPreferences(groomerID:)`
  - `timeOffWindows(groomerID:)`
  - `updateBookingPreferences(groomerID:draft:)`
  - `createTimeOff(groomerID:draft:)`
  - `deleteTimeOff(_:)`
- Extended `GroomerProfileStore` with booking preference form state, time off form state, save behavior, and create/delete time off actions.
- Time off date-only values are formatted from the local calendar date components to avoid DatePicker local-midnight values shifting to the previous day in non-UTC time zones.
- Reworked `GroomerAvailabilityEditorView` to match the screenshot hierarchy:
  - custom header/back button;
  - available-for-bookings card;
  - weekly hours card with compact day rows;
  - booking preferences card with stepper, segmented advance notice, and auto-accept toggle;
  - time off cards and add-time-off sheet;
  - bottom Save Availability CTA.

## Supabase Migration

- Local migration: `supabase/migrations/20260624021122_t060_groomer_availability_preferences.sql`.
- Remote project: `lqmasbuqzvcvtawonjlb`.
- MCP migration application: success.
- MCP migration list confirmed remote version `20260624022107_t060_groomer_availability_preferences`.
- Metadata checks confirmed:
  - both tables exist;
  - RLS enabled on both tables;
  - owner-only select/insert/update/delete policies exist on both tables;
  - authenticated/service_role grants exist and no anon grants were returned;
  - constraints exist for max daily appointments, advance notice, time off title, and date window;
  - updated_at triggers exist on both tables.
- Advisors:
  - Security advisor returned only existing controlled `SECURITY DEFINER` RPC warnings plus leaked-password protection, not new T-060 table warnings.
  - Performance advisor returned existing INFOs and an expected immediate `unused_index` INFO for `groomer_time_off_groomer_start_idx`.

## Validation

- Red targeted tests:
  - `xcodebuild test ... -only-testing:PetGroomerMarketplaceTests/GroomerProfileStoreTests/loadPopulatesProfileServicesAndPortfolio -only-testing:PetGroomerMarketplaceTests/GroomerProfileStoreTests/saveAvailabilityPersistsProfileWeeklyHoursAndBookingPreferences -only-testing:PetGroomerMarketplaceTests/GroomerProfileStoreTests/createAndDeleteTimeOffValidateAndUpdateLocalState`
  - Failed as expected because `GroomerBookingPreferences`, `GroomerTimeOffWindow`, drafts, and repository methods did not exist.
- Green targeted tests:
  - Same command with simulator UDID `4CB97394-9112-4FBB-8C99-628B416B922F`.
  - Passed after implementation.
- Final checks:
  - `git diff --check`: passed.
  - `./scripts/ios-build.sh`: passed.
  - `./scripts/ios-test.sh`: passed, including the full Swift Testing suite and the UI launch smoke test.
  - Simulator launch: installed and launched `com.prinnyyy.PetGroomerMarketplace` on iPhone 16 Pro iOS 18.4 simulator (`4CB97394-9112-4FBB-8C99-628B416B922F`), pid `34832`.

## Risks and Follow-ups

- Booking preferences and time off are persisted for groomer self-editing, but they are not yet used by request matching, customer slot discovery, booking creation, or booking conflict checks.
- Weekly availability still supports one window per weekday.
- Availability save now updates `groomer_profiles.is_active`, weekly rows, and booking preferences in sequence. This follows the existing simple direct-table approach, but it is not an atomic RPC.
- Time off create/delete is persisted immediately rather than waiting for the Save Availability button.
