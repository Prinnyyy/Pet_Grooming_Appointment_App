# T-062 - Groomly Groomer Schedule Screenshot UI

Mode: Standard

Date: 2026-06-24

## User Request

Redesign the groomer Schedule page from the uploaded prototype screenshot. The prototype's function is useful but the visual design should be improved for a merchant-facing appointment schedule. Also record that future simulator testing should use iPhone 17 Pro on iOS 26.

Screenshot/source reference:

- `docs/08_design/screenshots/screenshot-2026-06-24-am-12-16-03.png`

## Screenshot Analysis

Ignore rule:

- The long oval Customer/Groomer switch above the phone frame is external prototype chrome and was ignored.

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Schedule title | visual-only | yes | `BookingsView` for `role == .groomer` | none | Implement as groomer-only schedule title |
| Date chips | visual-only / existing-feature rewire | yes | `GroomerScheduleDayStrip` | `Booking.scheduledStart` | Implement horizontal day selector from today + future booking days |
| Timeline appointment display | existing-feature rewire | yes | `GroomerScheduleTimeline` and card subviews | `BookingsStore.bookings`, `Booking.scheduledStart`, `scheduledEnd`, `status`, `serviceType`, `locationMode` | Implement improved agenda cards rather than copying prototype geometry |
| Status chip | existing-feature rewire | yes | existing `GroomlyStatusChip` | `Booking.status` | Reuse existing status tone/icon mapping |
| Message button | existing-feature rewire | yes | `GroomerTabView` focused conversation routing | existing `ChatConversationsView(focusedBookingID:)` | Wire groomer Schedule message action to Messages tab |
| Complete button | existing-feature rewire | yes | `BookingsStore.complete(_:)` | existing booking completion RPC through repository | Reuse existing completion path |
| Pet/customer names in screenshot | new model data if exact | partial | `Booking` currently lacks pet name/customer display name | `SupabaseBookingRepository` does not join pet/customer names | Do not add backend/model joins in this task; use safe existing fallback copy |

## Implementation Plan

1. Keep the existing customer Bookings list unchanged.
2. Branch `BookingsView` by role so groomers see a dedicated Schedule page.
3. Add groomer-only date chips, selected-day summary, timeline rows, and appointment cards.
4. Reuse existing booking detail, chat focus, and completion actions.
5. Update build/test script defaults and memory to use `iPhone 17 Pro` on installed iOS 26 runtime.
6. Validate with `./scripts/ios-build.sh`, `git diff --check`, and simulator launch.

## Implementation Notes

- Added a groomer-only Schedule branch inside `BookingsView`; customer Bookings still uses the existing Upcoming/Past segmented list and card rows.
- The Schedule page now shows:
  - a large `Schedule` title;
  - horizontal day chips for today plus six days and any future booking days outside that window;
  - a daily snapshot card with booking count, next start time, and total booked duration;
  - a vertical agenda timeline with appointment cards.
- Appointment cards reuse current booking data only: time window, status, service title, service location mode, order number, detail navigation, message action, and complete action.
- `GroomerTabView` now passes an `onOpenChat` handler into `BookingsView`; the Schedule `Message` button uses the existing focused booking conversation route into Messages.
- No Supabase schema, RPC, RLS, Storage, or repository contract changed.
- Existing model gap: booking cards still cannot display real pet name or customer display name because `Booking`/`SupabaseBookingRepository` do not expose those joins. This task intentionally avoids hardcoded names.
- `scripts/ios-build.sh` and `scripts/ios-test.sh` now default to `platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro`, matching the available local iOS 26 runtime.

## Changed Files

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/GroomerTabView.swift`
- `scripts/ios-build.sh`
- `scripts/ios-test.sh`
- `docs/06_tasks/T-062_GROOMLY_GROOMER_SCHEDULE_SCREENSHOT_UI.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

## Validation

- `./scripts/ios-build.sh`: passed on `platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro`.
- `git diff --check`: passed.

## Simulator Launch

- Installed and launched `com.prinnyyy.PetGroomerMarketplace` on iPhone 17 Pro iOS 26.5 simulator (`45D452E8-DC6C-4CD4-A747-4D21671E68A6`), pid `60645`.

## Risks

- Live groomer Schedule visual density depends on current backend booking data for the signed-in groomer.
- Pet name and customer display name are still unavailable in the booking contract. A future model/repository task should add explicit booking summary joins if exact card copy like `Mochi · Full Groom` and `Lian · Mobile` is required.

## Closeout

Status: completed

Validation:

- `./scripts/ios-build.sh`: passed on iPhone 17 Pro iOS 26.5.
- `git diff --check`: passed.

Simulator launch:

- Passed on iPhone 17 Pro iOS 26.5; app launched successfully for user inspection.

Next:

- Launch app on iPhone 17 Pro iOS 26.5 simulator for user inspection, then wait for feedback before adding booking summary joins or schedule conflict/availability enforcement.
