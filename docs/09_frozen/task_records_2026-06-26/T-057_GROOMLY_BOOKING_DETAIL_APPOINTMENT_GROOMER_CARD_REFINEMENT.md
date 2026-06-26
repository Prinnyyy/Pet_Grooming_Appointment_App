# T-057 Groomly Booking Detail Appointment And Groomer Card Refinement

Mode: Standard

Date: 2026-06-23

## User Request

Refine the booking order detail page:

- Add a `Service` item to the `Appointment` module, above `Date`.
- Delete the separate chat module and move the chat button into the groomer module.
- Delete the lifecycle module.

## Investigation

- The Booking detail page rendered modules in this order: hero, `Appointment`, groomer/customer overview, separate `Chat`, and `Lifecycle`.
- The current backend already stores the request service as `grooming_requests.service_type`; no new backend field or RPC is required.
- T-056 had already enriched bookings with request location data through repository-owned optional queries, so this task extends the same query path to include `service_type`.

## Implementation

- Added optional `serviceType` to `Booking` and preserved it through `replacing(...)`.
- Added `Booking.appointmentServiceTitle`, using the fixed `GroomingServiceType.title` or `Service Details` fallback.
- Extended `SupabaseBookingRepository` request enrichment to select and decode `grooming_requests.service_type`.
- Added `Service` as the first row in the Booking detail `Appointment` module.
- Removed the separate Booking detail `Chat` card from the page.
- Moved the `Open Chat` button into `BookingPartnerOverviewCard`, keeping the existing booking-to-Messages routing from T-056.
- Removed the Booking detail `Lifecycle` module from the page. The underlying `BookingsStore`/repository cancellation and completion methods remain in code for existing domain behavior, but the visible detail module is no longer shown.

## Changed Files

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Booking.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/BookingFeatureTests.swift`
- `docs/06_tasks/T-057_GROOMLY_BOOKING_DETAIL_APPOINTMENT_GROOMER_CARD_REFINEMENT.md`

## Validation

- Red targeted test run failed before implementation because `Booking.appointmentServiceTitle` and `Booking.serviceType` did not exist.
- Targeted green test run passed:
  - `BookingsStoreTests/bookingPresentationUsesGroomerNameAndAppointmentLocationContext`
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.
- iOS Simulator launch passed.

## Risks

- Removing the visible lifecycle module also removes the detail-page buttons for booking cancellation and groomer completion from this screen. The underlying repository and store methods were intentionally left intact because the user requested a UI removal, not a domain deletion.

## Closeout

Status: completed.

## Simulator Launch

- XcodeBuildMCP `session_show_defaults` confirmed the current project, scheme, and iPhone 17 simulator.
- XcodeBuildMCP `build_run_sim` passed on iPhone 17 simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Runtime diagnostics had no errors and one existing warning: `SupabaseAuthSessionRepository.swift:17` reports no async operation inside an `await` expression.
- Runtime log: `/Users/liafenyua/Library/Developer/XcodeBuildMCP/workspaces/Pet_Grooming_Appointment_App-78bef82efd6d/logs/com.prinnyyy.PetGroomerMarketplace_2026-06-23T21-52-59-928Z_helperpid59589_ownerpid9091_d11d3431.log`
- Screenshot confirmation: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_0f8ec295-361f-4d4a-a8a4-46ece496133c.jpg`
