# T-051 Groomly Customer Bookings Messages Account Screenshot UI

## Status

- Status: Completed
- Mode: Standard
- Started: 2026-06-23
- Owner: Codex

## User Request

Redesign the Customer Bookings, Messages, and Account pages from three uploaded prototype screenshots:

- Bookings page: prototype-inspired title, Upcoming/Past segmented control, and compact booking cards.
- Messages page: prototype-inspired conversation list. If a booking has been completed and ended for more than 7 days, keep the conversation visible and readable, but disable sending new messages.
- Account page: ignore the prototype My Pets, Booking History, Payment Methods, and Demo Controls modules. Remove the dog emoji from the customer role label under the email.

Screenshot references:

- `docs/08_design/原型截图/截屏2026-06-22 上午12.27.41.png`
- `docs/08_design/原型截图/截屏2026-06-22 上午12.27.50.png`
- `docs/08_design/原型截图/截屏2026-06-22 上午12.27.57.png`

## Screenshot Analysis

Ignore rule: the long oval Customer/Groomer toggle above the phone frame is external prototype chrome and is not implemented.

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Bookings title and tab shell | visual-only | yes | `BookingsView` | `BookingsStore.bookings` | implement |
| Upcoming/Past segmented control | existing-feature rewire | yes | `BookingsView` | `Booking.status`, `scheduledStart` | implement locally as UI filter |
| Booking summary card | visual-only | partial | `BookingsView` | `Booking` | implement with existing support refs where real participant names are unavailable |
| Messages title/list/card | visual-only | yes | `ChatConversationsView` | `ChatStore.conversations` | implement |
| Chat unavailable 7 days after completed booking | existing-feature rewire | partial | `ChatStore`, `ChatConversation`, `SupabaseChatRepository`, `ChatThreadView` | existing `bookings.status/completed_at` can be read in current booking summary query | implement without schema/RPC change |
| Account title/profile card | visual-only | yes | `AuthenticatedAccountView` | `MarketplaceProfile`, `AuthSessionSnapshot` | implement |
| Account ignored modules | visual-only | yes | `AuthenticatedAccountView` | none | do not implement My Pets, Booking History, Payment, Demo Controls |
| Customer role label emoji removal | visual-only | yes | `AuthenticatedAccountView` | `UserRole` display only | implement `Pet Owner` label without emoji |

## Implementation Plan

1. Add failing ChatStore tests for conversation lock state and completed-older-than-7-days send blocking.
2. Extend `ChatConversation` with booking status/completedAt summary fields and a pure lock policy.
3. Extend `SupabaseChatRepository` booking summary query to fetch `status` and `completed_at`.
4. Redesign Bookings root list with a customer-style large title, Upcoming/Past segmented control, and compact cards while preserving existing detail navigation and role support.
5. Redesign Messages conversation list and thread composer disabled state while preserving existing message loading/sending paths.
6. Redesign Account root to match the profile-card/sign-out shell and remove the customer role emoji.
7. Update task ledger/memory, validate, and launch simulator.

## Validation Plan

- Red targeted ChatStore test before implementation.
- Green targeted ChatStore test after implementation.
- `git diff --check`.
- `./scripts/ios-build.sh`.
- Launch app in iOS Simulator for inspection.

## Closeout

Status: completed on 2026-06-23

Changed files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticatedAccountView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Chat.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseChatRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/ChatFeatureTests.swift`
- `docs/06_tasks/T-051_GROOMLY_CUSTOMER_BOOKINGS_MESSAGES_ACCOUNT_UI.md`
- memory/index docs listed in the task ledger/worklog updates

Validation:

- Red targeted ChatStore test first failed before implementation because `ChatStore` did not expose a clock-injected send lock and `ChatConversation` had no booking completion fields.
- Green targeted ChatStore test passed:
  `xcodebuild test -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PetGroomerMarketplaceTests/ChatStoreTests`
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on iPhone 17 simulator `B9639233-9E78-41C9-A372-330D36C38DA7` with no diagnostics warnings or errors.
- Screenshot confirmation captured at `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_72b7c21c-cddf-4a43-840c-863005df5e96.jpg`.

Risks:

- The 7-day completed-booking chat lock is enforced in the iOS model/store and shown in UI. Current backend `messages` RLS still permits valid booking participants to insert messages; server-enforced lock would require a future authorized backend/RLS/RPC change.
- Booking list cards still use existing booking facts and participant reference/business-name data. Pet/service names are not invented where the booking model does not expose them.
- Account debug/demo controls were removed from the visible Account surface for this screenshot task; the underlying debug diagnostics code remains available to developers elsewhere in the project.

Next:

- User can inspect Bookings, Messages, and Account in the running simulator. Future work should only add server-enforced chat expiry with explicit backend authorization.
