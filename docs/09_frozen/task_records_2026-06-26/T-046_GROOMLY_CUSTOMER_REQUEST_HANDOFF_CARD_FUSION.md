# T-046 Groomly Customer Request Handoff Card Fusion

Task ID: `T-046`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Abandon the separate booking handoff card style. Keep the existing quest action card shape, but let booked quests inherit the handoff behavior:

- When progress reaches `Booking confirmed`, the quest action card should replace its `Detail` / `Cancel` buttons with a single `View Booking` button.
- The card header title and supporting text should use the booking handoff message, while the pet avatar remains unchanged.
- The card should keep the green confirmed-state border from the previous handoff treatment.
- The fused card layout should be redesigned so the text, progress timeline, and action fit cleanly in one screen.
- The `View Booking` acknowledgement must survive app restart; the handoff should not reappear after relaunching the client on the same device.

## Existing Capability Audit

- The request-to-booking mapping from T-045 remains valid: `Booking.requestID` links a booked quest to its booking.
- Existing `BookingDetailView` and `BookingsStore` can still be reused for `View Booking`; no navigation or backend contract change is needed.
- No existing persisted handoff acknowledgement state was found. T-045 intentionally used session-only acknowledgement.
- A backend field/table would be required for cross-device or reinstall persistence, but the current bug only requires surviving client restart on the same device. This task uses customer-scoped local `UserDefaults` persistence and does not add Supabase schema/RPC changes.

## Implementation Plan

1. Add a failing Store test proving that acknowledging a booked request handoff stays hidden after constructing a fresh `CustomerRequestsStore` with the same customer and local defaults.
2. Persist acknowledged booked request IDs in `CustomerRequestsStore` using a customer-scoped `UserDefaults` key.
3. Render booked handoffs with `CustomerRequestProgressCard` instead of the standalone handoff card.
4. In the fused card, keep the pet avatar, replace the title/subtitle/info lines with booking handoff content, switch the chip to `Booking`, compact the completed timeline, and replace the two-button request action row with one `View Booking` primary button.
5. Run Standard-mode validation and launch the app in Simulator.

## Implementation Notes

- `CustomerRequestsStore` now loads and persists acknowledged handoff request IDs under `groomly.customerRequests.bookingHandoffAcknowledgements.<customerID>`.
- `acknowledgeBookingHandoff(for:)` still does not mutate request or booking data; it records only the UI acknowledgement locally.
- `bookingHandoffs` still requires a `booked` request and a matching `confirmed` booking, so completed/cancelled bookings remain hidden from Customer Requests.
- The booking handoff is now rendered through `CustomerRequestProgressCard` with `GroomlyCard(isSelected: true)` for the green confirmed border.
- The fused card uses a compact timeline density for booked handoffs to keep the header, completed progress, and `View Booking` CTA visually balanced.
- `View Booking` still opens existing `BookingDetailView` with a seeded `BookingsStore`, then hides the handoff card through the persisted acknowledgement.

## Files Changed

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `docs/06_tasks/T-046_GROOMLY_CUSTOMER_REQUEST_HANDOFF_CARD_FUSION.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

## Validation Plan

```sh
xcodebuild -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' test -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests
git diff --check
./scripts/ios-build.sh
./scripts/ios-test.sh
```

Completion launch:

- Launch the app in the iOS Simulator for inspection.

## Validation Results

- Targeted TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` failed before implementation because `CustomerRequestsStore` did not yet accept `handoffAcknowledgementDefaults`.
- Targeted green check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` passed after the local persistence and fused-card changes.
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.
- `./scripts/ios-test.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`). App launched successfully for inspection.
- Simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_ccbc9736-7014-4da9-887a-aaeb1ef7cbfd.jpg`.

## Risks And Follow-Up

- The acknowledgement now survives app restart on the same installed client, but it remains local device state. Reinstalling the app, clearing app data, or using another device can show the handoff again.
- A future backend/model task should add a persisted customer-scoped acknowledgement, for example `request_booking_handoff_acknowledged_at` or a small acknowledgement table, if cross-device suppression becomes product-critical.
- No Supabase schema/RPC/RLS changes were made in this task.
