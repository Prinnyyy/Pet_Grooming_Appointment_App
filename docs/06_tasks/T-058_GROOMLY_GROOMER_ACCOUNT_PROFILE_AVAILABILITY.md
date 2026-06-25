# T-058 Groomly Groomer Account, Edit Profile, and Availability

## Status

Completed.

## Mode

Deep. User explicitly authorized the Supabase-backed availability work after the stop report identified that no reliable groomer availability persistence existed.

## Screenshot Analysis

Source screenshot: `docs/08_design/screenshots/screenshot-2026-06-23-pm-03-17-46.png`.

- The long oval Customer/Groomer switch above the phone frame is an external prototype annotation and was ignored per workflow rule.
- In-app modules mapped:
  - Account title and groomer profile card: visual rework of groomer account root using existing `GroomerProfileStore.profile`.
  - Edit Profile row: navigation to current groomer profile/service/portfolio editing, redesigned as the editable profile page.
  - Availability row: new persistent availability feature because no existing model/repository/table existed.
  - Payouts: ignored per user request.
  - Demo Controls: ignored per user request.
  - Bottom tabs: existing groomer tab shell, relabeled to match the prototype surface (`Board`, `Offers`, `Schedule`, `Messages`, `Account`) without changing feature ownership.

## Backend Plan

- Add one `public.groomer_availability_windows` table with one weekly window per groomer per ISO weekday.
- Use direct table access through `GroomerProfileRepository`; no `SECURITY DEFINER` RPC was added.
- Enable RLS and explicitly grant `authenticated` select/insert/update/delete because current Supabase Data API behavior may require explicit grants.
- Policies restrict all access to authenticated non-anonymous groomer owners.
- This task does not connect availability to request matching, booking conflict logic, or customer-facing search.

## Implementation Summary

- Added `GroomerAvailabilityWeekday`, `GroomerAvailabilityWindow`, and `GroomerAvailabilityDraft`.
- Extended `GroomerProfileRepository` and `SupabaseGroomerProfileRepository` with:
  - `availabilityWindows(groomerID:)`
  - `replaceAvailability(groomerID:drafts:)`
- Extended `GroomerProfileStore` with weekly availability state, local validation, load population, and save behavior.
- Reworked `GroomerProfileManagementView`:
  - account root now follows the screenshot hierarchy and removes Payouts/Demo Controls;
  - Edit Profile is a dedicated page containing all currently editable non-availability groomer profile/service/portfolio fields;
  - Availability is a dedicated weekly schedule editor with day toggles and time menus;
  - sign-out is wired directly from the authenticated shell instead of going through the old toolbar account link.
- Relabeled groomer tabs from `Requests`/`Bookings` to `Board`/`Schedule`.

## Supabase Migration

- Local migration: `supabase/migrations/20260623223830_t058_groomer_availability_windows.sql`.
- Remote project: `lqmasbuqzvcvtawonjlb`.
- MCP migration application: success.
- MCP migration list confirmed remote version `20260623223830_t058_groomer_availability_windows`.
- Metadata check confirmed:
  - table exists;
  - RLS enabled;
  - policies: select/insert/update/delete own;
  - trigger: `groomer_availability_set_updated_at`.
- Grant check confirmed `authenticated` has select/insert/update/delete and no anon grants were returned for the table.

## Validation

- Red test:
  - `xcodebuild test ... -only-testing:PetGroomerMarketplaceTests/GroomerProfileStoreTests/loadPopulatesProfileServicesAndPortfolio`
  - Failed as expected on missing `GroomerAvailabilityWindow`.
- Green targeted tests:
  - `xcodebuild test ... -only-testing:PetGroomerMarketplaceTests/GroomerProfileStoreTests/loadPopulatesProfileServicesAndPortfolio -only-testing:PetGroomerMarketplaceTests/GroomerProfileStoreTests/saveAvailabilityNormalizesEnabledWindowsAndSendsCanonicalOrder -only-testing:PetGroomerMarketplaceTests/GroomerProfileStoreTests/invalidAvailabilityWindowDoesNotCallRepository`
  - Passed.
- Related store tests:
  - `xcodebuild test -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PetGroomerMarketplaceTests/GroomerProfileStoreTests`
  - Passed.
- Full iOS tests:
  - `./scripts/ios-test.sh`
  - Passed after updating `TabModelsTests.groomerTabsHaveExactOrderTitlesAndSymbols()` for the deliberate groomer tab label change from `Requests`/`Bookings` to `Board`/`Schedule`.
- Build:
  - `./scripts/ios-build.sh`
  - Passed.
- Whitespace:
  - `git diff --check`
  - Passed.
- Simulator:
  - XcodeBuildMCP `session_show_defaults` confirmed project `ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj`, scheme `PetGroomerMarketplace`, simulator `iPhone 17`.
  - XcodeBuildMCP `build_run_sim` passed and launched `com.prinnyyy.PetGroomerMarketplace` on simulator `B9639233-9E78-41C9-A372-330D36C38DA7`.

## Risks and Follow-ups

- Availability is now persisted and editable, but not yet used by request matching or booking conflict checks.
- The schema supports one time window per weekday. Multiple windows per day, blackout dates, holidays, and per-date exceptions need a later explicit product/backend task.
- The repository uses delete-then-insert replacement for the groomer's weekly rows. It is simple and RLS-safe, but not an atomic RPC. If partial-write resilience becomes important, add a controlled RPC in a future authorized backend task.
- No Supabase advisor MCP tool was available in this session; metadata, migration-list, RLS, trigger, and grants were checked through MCP SQL instead.
