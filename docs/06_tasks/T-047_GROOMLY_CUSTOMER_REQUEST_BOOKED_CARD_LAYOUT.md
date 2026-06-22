# T-047 Groomly Customer Request Booked Card Layout

Task ID: `T-047`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Refine the booked quest action card in Customer Requests:

- Replace the booked-card supporting copy `Your grooming appointment is ready...` with the original quest task summary, such as `Bath for Banksy`.
- Add the request address under the booked appointment time.
- Make the unconfirmed quest action card and booked quest action card reuse the same card style and dimensions.
- Keep the booked quest behavior from T-046: green confirmed border, one `View Booking` button, and no reappearing after same-device app restart.
- Record the work as T-047.

Follow-up refinement request:

- Center the first quest action card in the screen.
- Make `Open request` and `Booking confirmed` occupy two lines and use a larger headline.
- Make the time range occupy two lines, with the second time moving after the `-` separator.
- Unify the visual style of `Detail`, `Cancel`, and `View Booking`.
- Continue optimizing the quest action card layout so it feels visually balanced.

## Existing Capability Audit

- T-046 already renders booked handoffs through `CustomerRequestProgressCard`; no separate card route needs to remain.
- The request summary already exists as `CustomerGroomingRequest.title`, and the address exists as `CustomerGroomingRequest.locationSummary`.
- Booking time remains available from the existing `Booking.scheduledTimeSummary`.
- Same-device handoff acknowledgement persistence already exists in `CustomerRequestsStore` through customer-scoped `UserDefaults`.
- No backend field, RPC, schema, RLS, repository method, or navigation route is required for this refinement.

## Implementation Plan

1. Add a failing presentation test that proves a booked handoff card uses the quest summary and includes appointment time plus address.
2. Add a small `CustomerRequestProgressCardPresentation` value model so active and booked cards consume the same header/info-line structure.
3. Remove booked-only card chrome differences by sharing padding, content spacing, and timeline density between active and booked quest action cards.
4. Keep booked-only behavior limited to selected green border, Booking chip, and one `View Booking` action.
5. Run Standard-mode validation and launch the app in Simulator.

## Implementation Notes

- `CustomerRequestProgressCardPresentation` now supplies headline, subtitle, chip, and info lines for both active requests and booked handoffs.
- Booked handoff cards now show:
  - headline: `Booking confirmed`
  - subtitle: the original request title, for example `Full groom for Mochi`
  - info line 1: confirmed booking time
  - info line 2: request address
- Active and booked cards now share the same `GroomlyCard` padding, content spacing, and regular timeline density.
- The regular timeline density was tightened so the header, timeline, and action row fit more cleanly in a phone viewport while preserving the same layout for both states.
- T-046 local acknowledgement persistence was preserved; no data deletion or backend mutation was added.
- Follow-up: card width now uses the horizontal scroll viewport length directly so the first card centers within the content column while preserving screen-edge scroll bleed.
- Follow-up: request-card headlines now use explicit two-line strings such as `Open\nrequest` and `Booking\nconfirmed`, rendered with a larger rounded heavy title.
- Follow-up: active and booked time ranges now format as `start -\nend`.
- Follow-up: `View Booking`, `Detail`, and `Cancel` now all render through `CustomerRequestActionLabel`, with tone-only color differences instead of unrelated button structures.

## Files Changed

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `docs/06_tasks/T-047_GROOMLY_CUSTOMER_REQUEST_BOOKED_CARD_LAYOUT.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

## Validation Plan

```sh
xcodebuild -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' test -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress
git diff --check
./scripts/ios-build.sh
```

Completion launch:

- Launch the app in the iOS Simulator for inspection.

## Validation Results

- Targeted TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress` failed before implementation because `CustomerRequestProgressCardPresentation` did not exist.
- Targeted green check: the same test passed after adding the presentation model and shared card layout.
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`). App launched successfully for inspection.
- Simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_944098b2-cb6c-45d1-be79-9e4a1d32606b.jpg`.

Follow-up validation:

- Follow-up TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` failed before implementation on `bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress` and `openRequestCardPresentationUsesTwoLineHeadlineAndTimeRange`.
- Follow-up green check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` passed after the presentation and card layout updates.
- Follow-up `git diff --check` passed.
- Follow-up `./scripts/ios-build.sh` passed.
- Follow-up XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`). App launched successfully for inspection.
- Follow-up simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_21a2af42-0578-4de8-bdab-6dd390783648.jpg`.

## Risks And Follow-Up

- The card layout is now structurally shared, but visual verification still depends on available runtime data containing booked and unconfirmed cards.
- Same-device handoff acknowledgement remains local `UserDefaults` state from T-046. It still does not survive reinstall, app data clearing, or cross-device use.
- No Supabase changes were made in this task.
