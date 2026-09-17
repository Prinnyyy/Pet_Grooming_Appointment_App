# T-053 Groomly Customer Home, Pet, Request, Booking, and Chat Fixes

Task ID: `T-053`

Mode: `Standard`

Date: `2026-06-23`

## User Request

Fix several customer-facing issues across Home, Add/Edit Pet, Requests, Bookings, Messages, and Chat. The uploaded chat-thread screenshot is the visual reference for the formal chat page.

Screenshot/source reference:

- `docs/08_design/screenshots/screenshot-2026-06-23-am-11-44-01.png`

## Primary Task

Rework only the requested customer surfaces while preserving existing product boundaries.

Target screen and role:

- Screen: Customer Home, Add/Edit Pet, Requests carousel, Bookings summary cards, Messages list, Chat thread
- Role: Customer / Shared booking participant chat

## Screenshot Analysis

Ignore rule:

- Ignore any long oval Customer/Groomer toggle located above the visible app screen frame. Treat it as an external prototype/control annotation, not as an app module to map, classify, or implement.

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Chat header with back button, avatar, participant name, online state | visual-only | partial | `ChatThreadView` | `ChatConversation`, `ChatStore` | Implement with existing participant title; use active/read-only state instead of adding realtime presence. |
| Booking context card at top of chat | visual-only | partial | `ChatThreadView` | `ChatConversation.bookingReferenceCode`, booking status/date fields | Implement with available booking summary; do not add pet/service query fields. |
| Booking status pill | visual-only | yes | `ChatThreadView` | `BookingStatus` in `ChatConversation` | Implement. |
| Message bubbles and composer | visual-only / existing-feature rewire | yes | `ChatThreadView`, `ChatComposerView` | Existing `ChatStore.messages` and `sendMessage` | Restyle only; preserve text-only send and 7-day completed-booking read-only rule. |
| Messages list subtitle | existing-feature rewire | yes | `ChatConversationsView` | Existing messages table via `ChatRepository` / `SupabaseChatRepository` | Fetch latest body through repository adapter and fall back safely. |
| Add/Edit Pet form order and labels | visual-only | yes | `CustomerPetFormView` | `CustomerPetsStore` | Move Photos first, add visible care-note labels, preserve form state. |
| Breed and temperament option order | existing-feature rewire | yes | `CustomerPet` taxonomy and form chips | `CustomerPetBreed`, `CustomerPetTemperament` | Keep contract values; sort display options with special first option. |
| Edit Pet cancel flash | existing-feature rewire | yes | `CustomerPetsStore.cancelForm` | Existing sheet state | Defer edit-state reset until after dismissal animation. |
| Home pet card weight/size line | visual-only | yes | `CustomerPetsView` | `CustomerPet.weightLbs`, derived/display size | Implement. |
| Active Request card single-line service title and Home tap-to-Requests focus | existing-feature rewire | yes | `CustomerPetsView`, `CustomerRequestsView`, `CustomerTabView` | Existing request cards and tab state | Reuse card data, add front-end focus binding only. |
| Home Next Booking reuse and booking sort | visual-only / existing-feature rewire | yes | `CustomerPetsView`, `BookingsView` | Existing `BookingsStore.bookings` | Reuse `BookingSummaryRow`; sort by scheduled start. |

No module required a new backend/schema/RLS/RPC/Storage change.

## Implementation

- `CustomerPet` now exposes weight/size display text, keeps `Unspecified` first for breeds, sorts the remaining breed options A-Z, and keeps `Not Sure` first for temperament while sorting the remaining options A-Z.
- Add/Edit Pet now shows Photos before profile/details, gives both care-note fields persistent titles, and delays edit-state reset on Cancel so the sheet does not visually flash into Add Pet while closing.
- Customer Home pet cards now include a compact `weight • size` line under the breed.
- Customer Home Active Request summary cards keep `[service] for [pet name]` on one line and can navigate to the matching request card in the Requests tab with a smooth carousel scroll.
- Customer Home Next Booking now uses the same `BookingSummaryRow` as the Bookings tab and selects the nearest upcoming confirmed booking; Bookings lists are sorted by scheduled time.
- Messages list previews now show the latest message body when available instead of generic booking text.
- Chat thread was reworked around a custom header, appointment context card, status pill, refined bubbles, and a bottom composer while preserving the existing text-only chat and read-only behavior.

## Changed Files

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseChatRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Chat.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/CustomerPet.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/CustomerTabView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/ChatFeatureTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerPetFeatureTests.swift`

## Validation

- Red targeted tests failed before implementation because the new latest-message preview and taxonomy-order expectations were not implemented.
- `xcodebuild test -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PetGroomerMarketplaceTests/ChatStoreTests`: passed.
- `xcodebuild test -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PetGroomerMarketplaceTests/CustomerPetsStoreTests -only-testing:PetGroomerMarketplaceTests/CustomerPetPhotoPathTests`: passed.
- `./scripts/ios-build.sh`: passed.
- `git diff --check`: passed.

## Simulator Launch

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`) with app process `84123`.
- Runtime launch had no errors. It reported one existing warning in `SupabaseAuthSessionRepository.swift:17`: `no 'async' operations occur within 'await' expression`.
- Screenshot confirmation: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_efbf131c-e359-40ef-8f68-9dc80a1e1fa0.jpg`.

## Risks

- The chat screenshot shows pet/service information in the chat context card, but the current `ChatConversation` repository/model contract does not expose request pet/service fields. T-053 uses the existing booking reference/date/status fields and does not add backend or repository contract changes.
- The breed list already supports Husky through the existing `Siberian Husky` contract value. A separate raw `Husky` option was not added because it would diverge from the current fixed pet taxonomy contract and local T-050 migration draft.
- Latest-message preview uses the existing `messages` table through the repository adapter. If that best-effort query fails, the list falls back to the prior safe empty-preview text instead of blocking the conversations list.

## Closeout

Status: `completed`

Next:

- App is running in Simulator for inspection. Wait for user feedback before further screenshot rework or chat/booking contract changes.
