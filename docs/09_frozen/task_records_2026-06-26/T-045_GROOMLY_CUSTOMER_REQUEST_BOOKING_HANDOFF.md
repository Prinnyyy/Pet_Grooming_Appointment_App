# T-045 Groomly Customer Request Booking Handoff

Task ID: `T-045`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Implement the Customer Requests booked-quest handoff scheme.

When a customer request reaches `booked`, the request should no longer appear as a normal active request action card. It should appear as a booking handoff card that tells the user the appointment is confirmed and routes them to the corresponding booking detail. After the user opens the booking detail from the handoff, remove that handoff from the current Customer Requests UI session only.

Do not add backend persistence for the handoff acknowledgement in this task.

## Existing Capability Audit

- `Booking` already includes `requestID`.
- `SupabaseBookingRepository.bookings(participantID:role:)` already selects `request_id` and booking `status`.
- `BookingDetailView` already displays booking detail and owns booking lifecycle actions through `BookingsStore`.
- Customer Home already opens `BookingDetailView` from a local `BookingsStore`, so Customer Requests can reuse the same front-end pattern.
- No new Supabase RPC, table, RLS policy, or repository method is required for this task.

## Implementation Plan

1. Add Store tests first for active request filtering, confirmed booking handoff creation, handoff acknowledgement, and completed/cancelled booking suppression.
2. Extend `CustomerRequestsStore` to load customer bookings through the existing `BookingRepository`, expose active requests and booking handoffs, and maintain session-only acknowledged handoff request IDs.
3. Add a `BookingsStore` initializer that can seed a booking detail store with the selected booking.
4. Update `CustomerRequestsView` so the carousel shows open/has_offers request cards plus booked handoff cards, excludes cancelled/expired requests, and routes handoff CTA taps to `BookingDetailView`.
5. Document validation and long-term persistence risk.

## Validation Plan

```sh
git diff --check
./scripts/ios-build.sh
./scripts/ios-test.sh
```

Completion launch:

- Launch the app in the iOS Simulator for inspection.

## Closeout

Status: `completed`

## Implementation Notes

- Reused the existing `Booking.requestID` mapping and `BookingRepository.bookings(participantID:role:)`; no Supabase migration, RPC, schema, RLS, or repository contract was added.
- `CustomerRequestsStore.activeRequests` now exposes only `open` and `has_offers` requests for the active request carousel.
- `CustomerRequestsStore.bookingHandoffs` exposes `booked` requests only when there is a matching `confirmed` booking, which suppresses handoff cards after the booking is completed or cancelled.
- Handoff acknowledgement is session-local through `acknowledgedBookingHandoffRequestIDs`; opening `View Booking` removes the card from the current Customer Requests UI without deleting or mutating request data.
- `CustomerRequestsView` renders booked handoffs as distinct booking handoff cards and routes `View Booking` to the existing `BookingDetailView` with a seeded `BookingsStore`.
- Request cancellation remains guarded to `open` and `has_offers` requests only; booked quests are handed off to booking lifecycle UI.

## Files Changed

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `docs/06_tasks/T-045_GROOMLY_CUSTOMER_REQUEST_BOOKING_HANDOFF.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

## Validation Results

- Targeted TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` initially failed because the new Store API did not exist yet.
- Targeted green check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` passed after implementation.
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.
- `./scripts/ios-test.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`). App launched successfully for inspection.
- Simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_dd6ed701-2f0a-4011-bd05-9a9bb245a263.jpg`.

## Risks And Follow-Up

- Handoff acknowledgement is intentionally not persisted in this task. Long term, add a customer-scoped persisted acknowledgement such as `request_booking_handoff_acknowledged_at` or a small request-handoff acknowledgement table so the card does not reappear after reinstall, device switch, or a fresh session.
- The handoff relies on existing booking data containing a matching `requestID` and status. If a booked request exists without a locally returned matching booking row, the Customer Requests page will not show a handoff card for it.
- No backend changes were made. If product later needs persistent handoff acknowledgement, that should be authorized as a separate backend/model task.
