Task ID: `T-052`

Mode: `Standard`

Date: `2026-06-23`

## User Request

Redesign selected customer-facing surfaces to better match the current Groomly visual style:

- Redesign the Add Pet page, with Edit Pet reusing the same form modules.
- Redesign the booking detail page. Hide hard-to-read ID text; keep at most one booking number. Add groomer-facing personal information where supported by existing data.
- Update booking list summary cards, using the bookings prototype as reference.
- Redesign Messages conversation summary cards based on the messages prototype.

Screenshot/source references:

- `docs/08_design/screenshots/screenshot-2026-06-22-am-12-27-41.png`
- `docs/08_design/screenshots/screenshot-2026-06-22-am-12-27-50.png`

## Primary Task

Rework only the customer Add/Edit Pet form, Bookings list/detail presentation, and Messages conversation list cards.

Target screen and role:

- Screen: Customer Add/Edit Pet, Customer Bookings, Customer Messages
- Role: Customer primary; shared booking UI must remain safe for groomer role where currently reused.

## Required Context

Read:

1. `AGENTS.md`
2. `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
3. `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`
4. SwiftUI view files:
   - `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
   - `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
   - `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatView.swift`
5. Existing models/repositories:
   - `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/CustomerPet.swift`
   - `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Booking.swift`
   - `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/BookingRepository.swift`
   - `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift`

## Screenshot Analysis

Ignore rule:

- Ignore any long oval Customer/Groomer toggle located above the visible app screen frame. Treat it as an external prototype/control annotation, not as an app module to map, classify, or implement.

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Booking page large title | visual-only | yes | `BookingsView` | `BookingsStore.bookings` | keep existing T-051 title style |
| Upcoming/Past segmented control | visual-only | yes | `BookingScopeControl` | local `BookingListScope` | refine only if needed |
| Booking summary card | visual-only / existing-feature rewire | partial | `BookingSummaryRow` | `Booking` exposes status, scheduled time, price, participant reference | implement better hierarchy; do not invent pet/service/groomer names |
| Booking detail order facts | visual-only | yes | `BookingDetailView` | `Booking.referenceCode`, `priceSummary`, scheduled dates, lifecycle | implement; hide request/offer/participant IDs |
| Booking detail groomer info | new feature if true profile fields are required | partial | `BookingDetailView` | current `Booking` has only `groomerID`/reference, no name/avatar/rating/profile query | implement readable "Assigned Groomer" overview from existing participant summary; record long-term contract gap |
| Messages page large title | visual-only | yes | `ChatConversationsView` | `ChatStore.conversations` | keep existing T-051 title style |
| Message summary card avatar/name/preview/time | visual-only / existing-feature rewire | partial | `ChatConversationRow` | `ChatConversation` exposes participant summary, scheduling summary, updatedAt, read-only state | implement prototype-like hierarchy from existing fields |
| Add Pet form title/actions | visual-only | yes | `CustomerPetFormView` | `CustomerPetsStore` form state | implement |
| Add/Edit Pet fixed species/breed/temperament controls | visual-only | yes | `CustomerPetFormView` | T-050 fixed taxonomy state | implement |
| Add/Edit Pet weight slider/size derivation | visual-only | yes | `CustomerPetFormView` | `CustomerPetSizeCode.code(forWeightLbs:)` | implement |
| Add/Edit Pet photo picker | visual-only | yes | `CustomerPetFormView` | existing pending photo upload via `CustomerPetsStore` | implement |

## Scope

In scope:

- SwiftUI layout, typography, card structure, copy, and icon changes.
- Reuse existing Stores, repository protocols/adapters, models, and backend contracts.
- Keep Add Pet and Edit Pet on one shared form view.
- Hide unnecessary booking IDs from user-facing booking detail.
- Keep one short booking number where helpful for support.

Out of scope:

- New booking profile joins, Supabase queries, RLS/RPC/storage changes, or repository contracts.
- New actual groomer profile fields on booking detail.
- Direct Supabase access from SwiftUI.
- New navigation flows or role capabilities.

## New Feature Stop Report

The requested "booking page needs some groomer personal information" is only partially supported.

- Existing support: `Booking` exposes `groomerID` and `participantSummary(for:)`, which currently formats a short reference code.
- Missing support for rich information: groomer display name, avatar/photo URL, rating, service address, and business/profile summary are not part of `Booking`, `BookingRepository`, or `SupabaseBookingRepository.bookingColumns`.
- Likely affected files for a future approved backend/model task:
  - `Core/Models/Booking.swift`
  - `Core/Repositories/BookingRepository.swift`
  - `Core/Infrastructure/Supabase/SupabaseBookingRepository.swift`
  - Possibly Supabase SELECT policy/SQL view/RPC if joined profile data is not directly selectable under current RLS.
- Current decision: do not add backend/model contract. Make the detail page readable with existing stable data and record the limitation.

## Implementation Plan

1. Replace the default grouped `Form` pet sheet with a custom `ScrollView` + card modules so Add/Edit Pet visually matches the rest of Groomly.
2. Keep all form controls bound to existing `CustomerPetsStore` fields and reuse the same `CustomerPetFormView` for create/edit.
3. Refine booking summary card hierarchy: status/date row, compact participant block, time/price metadata, chevron.
4. Refine booking detail: hero card, appointment card, assigned groomer card from existing participant data, lifecycle/review sections. Remove request/offer/participant reference rows.
5. Refine message cards: avatar square, participant title, preview copy, trailing relative time, subtle read-only badge.

## Validation Plan

Run:

```sh
git diff --check
./scripts/ios-build.sh
```

After validation, launch the app in iOS Simulator for inspection.

## Closeout

Status: `completed`

Changed files:

- `docs/06_tasks/T-052_GROOMLY_CUSTOMER_PET_BOOKING_MESSAGE_REFINEMENT.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatView.swift`

Validation:

- `git diff --check` passed.
- `./scripts/ios-build.sh` passed with `** BUILD SUCCEEDED **`.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on iPhone 17 simulator `B9639233-9E78-41C9-A372-330D36C38DA7`, bundle `com.prinnyyy.PetGroomerMarketplace`.
- Screenshot captured: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_2e765cce-bf0f-4a0a-ab58-21890e953bdf.jpg`.

## Notes And Risks

- Add Pet and Edit Pet continue to share `CustomerPetFormView`; no Store/repository/model/backend contract changed.
- Booking detail now hides request/offer/participant technical references and keeps only `Order #<booking reference>`.
- Rich groomer booking detail fields are still a contract gap. Current `BookingRepository` does not fetch groomer business name, avatar/photo, rating, address, or profile summary. A future approved model/repository/backend task is needed before the booking detail can show true groomer personal information.
- Messages conversation cards avoid fake latest-message content. They use existing conversation participant title, booking status, scheduled time, read-only state, and relative update time.
