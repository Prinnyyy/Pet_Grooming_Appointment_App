# T-055 Groomly Customer Home Next Booking And Request Wizard Stability

Mode: Standard

Date: 2026-06-23

## User Request

Fix three customer-side issues:

- Customer Home `Next Booking` should behave like `Active Request` when there is no booking: no empty card module, just an inline empty text state.
- The `Start Grooming Request` wizard progress bar and step labels are visually misaligned and need adjustment.
- The request wizard can freeze on the Time/Location page after turning on `I'm Flexible With Time` and scrolling; inspect logs and fix the stability issue.

## Investigation

- Current worktree was clean before edits.
- Simulator logs for `com.prinnyyy.PetGroomerMarketplace` showed no recent app crash report and no `PetGroomerMarketplace` diagnostic crash file in recent DiagnosticReports.
- The relevant log window did show sustained high-frequency UIKit event dispatch during the reported frozen interaction window, which points to a UI/gesture/layout loop rather than a thrown Swift exception.
- Code inspection found the Time/Location step applied broad `.animation(..., value:)` modifiers to the whole long form for both `selectedTimeWindow` and `isFlexibleWithTime`. Turning on flexible time while scrolling could animate the entire location form, address suggestions, keyboard-aware scroll view, and validation state together.
- Code inspection also found the wizard step labels were outside the progress-track container, while the progress track was inside the row next to the back button. That made the labels span a wider frame than the progress track.

## Implementation

- Added `CustomerHomeNextBookingPresentation` so Home Next Booking has explicit loading/booking/inline-empty states and never renders an empty card when there is no confirmed booking.
- Reused a new `CustomerHomeInlineEmptyText` helper for both Home Active Request and Home Next Booking empty states.
- Moved request wizard step labels into the same right-side container as the progress track, so labels and bar share the same width after the back button.
- Added `CustomerRequestWizardProgressLayout` to centralize the back-button/progress-track layout metrics used by the header and tested by focused Store/UI presentation tests.
- Removed broad Time/Location step animations tied to `selectedTimeWindow` and `isFlexibleWithTime` to avoid animating the entire long form during scrolling.
- Added query-fragment de-duplication inside `CustomerRequestAddressSearch` so MapKit autocomplete is not updated when the computed query did not actually change.

## Changed Files

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `docs/06_tasks/T-055_GROOMLY_CUSTOMER_HOME_NEXT_BOOKING_AND_REQUEST_WIZARD_STABILITY.md`

## Validation

- Red targeted test run failed before implementation because `CustomerHomeNextBookingPresentation` and `CustomerRequestWizardProgressLayout` did not exist.
- Targeted green test run passed:
  - `CustomerRequestsStoreTests/homeNextBookingPresentationUsesInlineEmptyTextInsteadOfCard`
  - `CustomerRequestsStoreTests/requestWizardProgressLabelsUseProgressTrackWidth`
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.

## Simulator Launch

- XcodeBuildMCP `build_run_sim` passed on iPhone 17 simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- App launched successfully with no MCP diagnostics errors.
- Runtime log: `/Users/liafenyua/Library/Developer/XcodeBuildMCP/workspaces/Pet_Grooming_Appointment_App-78bef82efd6d/logs/com.prinnyyy.PetGroomerMarketplace_2026-06-23T20-49-38-365Z_helperpid32799_ownerpid9091_ce7b1716.log`
- Screenshot confirmation: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_12af9905-ba0b-4323-bd08-84f7da666325.jpg`

## Risks

- The freeze was not accompanied by an app crash report, so the fix addresses the identified UI layout/animation risk and MapKit query churn rather than a crash stack.
- Manual smoke should still verify the exact path: open Start Grooming Request, reach Time/Location, toggle `I'm Flexible With Time`, scroll through Location, and confirm no freeze.

## Closeout

Status: completed.
