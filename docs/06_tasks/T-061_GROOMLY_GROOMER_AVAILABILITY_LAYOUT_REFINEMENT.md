# T-061 Groomly Groomer Availability Layout Refinement

## Status

Completed.

## Mode

Standard. This is a groomer Availability UI refinement with no backend or repository contract changes.

## User Request

- Fix the Availability page width jump when enabling Monday or Tuesday.
- Remove all Booking Preferences UI controls except Auto-accept bookings.

## Root Cause

The enabled weekly-hours row used fixed widths for the weekday label, two time menus, the separator, the toggle, and several `md` spacings. Inside the default `GroomlyCard` padding, the enabled row exceeded the available iPhone content width and widened the ScrollView content. Disabled rows did not show the issue because they used a flexible `Unavailable` text instead of the two fixed time controls.

## Implementation

- Tightened `GroomerAvailabilityDayRow` spacing and fixed widths:
  - weekday label width reduced;
  - time menu width reduced;
  - separator width fixed;
  - the time-control group now occupies flexible row space rather than forcing the row wider.
- Reduced the weekly-hours card padding from `lg` to `md`.
- Simplified `GroomerBookingPreferencesSection` to only show Auto-accept bookings.
- Removed the unused max-appointments stepper and advance-notice segmented control from the Availability UI.
- Kept the underlying persisted booking-preference fields intact so existing repository/model behavior remains compatible.

## Validation

- `./scripts/ios-build.sh`: passed after fixing one SwiftUI `.frame` argument error.
- `git diff --check`: passed.
- Simulator launch: installed and launched `com.prinnyyy.PetGroomerMarketplace` on iPhone 16 Pro iOS 18.4 simulator (`4CB97394-9112-4FBB-8C99-628B416B922F`), pid `49788`.

## Notes

- No Supabase schema, RLS, RPC, Storage, repository protocol, or Store behavior changes were made in this task.
