# T-019 — Booking Acceptance and Role UI

## Status

- Mode: Standard.
- State: completed.
- Depends on: T-018 booking backend.

## Goal

Wire the deployed T-018 booking contract into iOS so customers can accept one pending offer and both roles can see and cancel their participant bookings.

## Scope

In scope:

- Add booking models, repository boundary, Supabase adapter, shared store, and shared booking list/detail UI.
- Customer offer detail calls `accept_groomer_offer` only for pending offers on open/has-offers requests.
- Customer acceptance refreshes owned requests and offers after the backend RPC returns.
- Customer and groomer Bookings tabs load participant-visible `bookings` rows through RLS.
- Confirmed booking cancellation calls `cancel_booking`.
- Cancelled bookings clearly state that the original request and offers remain closed.
- Add focused store tests for offer acceptance, conflict messaging, booking loading, and booking cancellation.

Out of scope:

- New Supabase schema, migrations, RLS changes, or Storage work.
- Chat messages, conversation UI, completion, reviews, notification, payment, dispute, or rebooking flows.
- Customer request cancellation.
- Runtime fixture/demo success paths.

## Implementation Notes

- `BookingRepository` owns booking reads plus `acceptOffer` and `cancelBooking`.
- `SupabaseBookingRepository` selects from `bookings` by role-specific participant column and calls T-018 RPCs with lowercased UUID parameters.
- `BookingRepositoryError` maps stable T-018 PostgREST/RPC errors, including `booking_conflict`, `booking_already_exists`, and `booking_not_cancellable`.
- `CustomerRequestsStore` updates local request/offer state from the authoritative accept RPC result, reports a refresh hint if local state is missing, and then performs a best-effort refresh of requests/offers.
- `BookingsView` is shared by Customer and Groomer tabs. It shows readable short participant/support reference codes from existing booking data; richer request/profile joins are deferred until a later UX polish task.
- Booking detail includes cancellation only for confirmed bookings. Completion/review and messaging remain explicit later-task placeholders.

## Validation

Completed validation:

- Initial `./scripts/ios-test.sh` failed on a missing stored `role` property in `BookingsView`; the user approved a targeted fix.
- The next `./scripts/ios-test.sh` failed on an ambiguous `.unavailable` enum in `CustomerRequestsStore`; the user approved a targeted fix.
- Code-review follow-up improved booking references and local update fallback; the first follow-up validation exposed Swift 6 default MainActor isolation on new pure model helpers, fixed by marking those helpers `nonisolated`.
- Final `./scripts/ios-test.sh` passed with 55 Swift Testing tests and 1 XCTest UI smoke test.

No Supabase remote validation was run because T-019 changes only iOS client code and documentation against the already deployed and backend-validated T-018 contract.

## Closeout

T-019 is complete. Customers can accept an eligible offer through the T-018 atomic backend transaction, customer/groomer Bookings tabs show participant bookings with readable support references, and confirmed bookings can be cancelled without implying that the original request or offers reopened. Chat, completion, and reviews remain separate later tasks.
