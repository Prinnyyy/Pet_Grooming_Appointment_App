# T-056 Groomly Booking Chat And Next Booking Polish

Mode: Standard

Date: 2026-06-23

## User Request

Fix and refine customer booking surfaces:

- Customer Home `Next Booking` should not flash a temporary white card when switching tabs and no booking exists.
- Booking summary cards should show the groomer name instead of `Assigned Groomer`.
- Booking detail's groomer module should show the groomer name.
- Booking detail's conversation module should become a chat button that routes to the matching Messages thread.
- Appointment details should include whether the groomer comes to the customer or the customer visits the groomer, plus the relevant address.

## Investigation

- The `Next Booking` flash had the same shape as the earlier `Active Request` empty-card flash: while `BookingsStore` was loading and no nearest booking existed, Home rendered a loading/card surface for a transient empty state.
- `accept_groomer_offer` already creates one `conversations` row atomically with the confirmed booking. `ChatRepository` exposes conversation listing and message send/read, but no authenticated client-side conversation creation path.
- Backend RLS and task history indicate customer/groomer clients should not directly insert conversations. Therefore this task reuses the existing booking-created conversation and does not create a duplicate or synthetic conversation in the UI.
- `BookingRepository` could fetch booking rows, reviews, and IDs, but did not expose groomer display information or request location fields needed by the redesigned booking card/detail.
- The available groomer public profile data includes `groomer_profiles.business_name`, `base_city`, and `base_state`. There is no street-level groomer address field in the current backend contract.

## Implementation

- Updated Home `Next Booking` presentation to use an inline empty text state and never render a loading/empty card when no nearest booking exists.
- Extended `Booking` with optional groomer summary and request-location fields, plus presentation helpers for partner title, service-location title, and appointment address summary.
- Extended `SupabaseBookingRepository` with optional enrichment queries against `groomer_profiles` and `grooming_requests`, keeping booking list loading resilient if either enrichment query is denied or unavailable.
- Replaced booking card/detail fallback copy from `Assigned Groomer` to groomer-name presentation through `Booking.partnerDisplayTitle(for:)`.
- Replaced the detail `Conversation` info card with a primary `Open Chat` action.
- Added a customer-tab focus path from booking detail to Messages. It switches to Messages and opens the conversation whose `bookingID` matches the booking.
- Added safe missing-conversation handling: if the existing booking conversation is not available, the Messages tab reports `Booking chat is not available yet.` instead of creating unsupported client-side data.
- Added appointment detail rows for service location and address. Customer-address bookings show the request's full customer address; customer-visits-groomer bookings show the groomer's base city/state when available or `Groomer address pending`.

## Changed Files

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Booking.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/CustomerTabView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/BookingFeatureTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/ChatFeatureTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `docs/06_tasks/T-056_GROOMLY_BOOKING_CHAT_AND_NEXT_BOOKING_POLISH.md`

## Validation

- Red targeted test run failed before implementation because the booking presentation/chat focus APIs did not exist.
- Targeted green test run passed:
  - `CustomerRequestsStoreTests/homeNextBookingPresentationUsesInlineEmptyTextInsteadOfCard`
  - `BookingsStoreTests/bookingPresentationUsesGroomerNameAndAppointmentLocationContext`
  - `BookingsStoreTests/bookingPresentationUsesGroomerLocationFallbackWhenCustomerVisits`
  - `ChatStoreTests/conversationLookupFindsLoadedBookingConversation`
  - `ChatStoreTests/missingBookingConversationReportsSafeUnavailableMessage`
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.

## Risks

- The user asked to create a new conversation if missing, but the current backend contract creates booking conversations during offer acceptance and does not expose a safe authenticated client insert path. This task intentionally avoids duplicate/synthetic conversations. A future backend-authorized task would be required if booking detail must create a conversation after the fact.
- Street-level groomer address is not available in the current groomer profile contract. `Customer Comes To Groomer` bookings can show only groomer base city/state or a pending-address fallback until a future backend/model/repository change adds groomer service addresses.

## Closeout

Status: completed.

## Simulator Launch

- XcodeBuildMCP `build_run_sim` passed on iPhone 17 simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Runtime diagnostics had no errors and one existing warning: `SupabaseAuthSessionRepository.swift:17` reports no async operation inside an `await` expression.
- Runtime log: `/Users/liafenyua/Library/Developer/XcodeBuildMCP/workspaces/Pet_Grooming_Appointment_App-78bef82efd6d/logs/com.prinnyyy.PetGroomerMarketplace_2026-06-23T21-38-15-250Z_helperpid53272_ownerpid9091_70093642.log`
- Screenshot confirmation: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_21f51c5b-b973-4edd-b6c4-2b87b56a3d17.jpg`
