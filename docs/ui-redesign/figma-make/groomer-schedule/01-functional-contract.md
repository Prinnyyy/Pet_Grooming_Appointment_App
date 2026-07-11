# Functional Contract

Only production-code-confirmed behavior belongs in a concept. Anything marked **待确认** must not be presented as implemented.

## Page objective and access

- Screen: `BookingsView(role: .groomer)`, Schedule tab root.
- User: authenticated Groomer with `groomerID` and a `BookingRepository` supplied by `GroomerTabView.destination(for:)`.
- Objective: choose a day, scan active appointments in chronological order, open an appointment, message its customer, and complete an eligible booking.
- Root navigation: `GroomerTab.bookings` in the five-tab `TabView` (`Home`, `Requests`, `Schedule`, `Messages`, `Account`).

## Displayed fields and sources

| UI field | Production source |
| --- | --- |
| Seven-day strip plus future booking dates | `GroomerScheduleDay.days(around:bookings:)` |
| Selected date | local `selectedScheduleDayKey` resolved by `GroomerSchedulePresentation` |
| Appointment count | `GroomerScheduleSummary.bookingCount` |
| Next start | first selected booking `scheduledStart` |
| Total booked duration | sum of each selected booking's `scheduledStart...scheduledEnd` |
| Start and end times | `Booking.scheduledStart`, `Booking.scheduledEnd` |
| Pet name | `requestPetSnapshot.name`, fallback `Pet details` |
| Pet detail | breed, else species, else `Pet`; plus `serviceType.title`, fallback `Service Details` |
| Customer | `Customer ref {8-character code}`; no customer display name is present in `Booking` |
| Location mode | `Mobile`, `Studio`, or fallback `Location` from `locationMode` |
| Status | `Booking.status` title and icon-bearing status chip |
| Reminder warning | `BookingsStore.appointmentReminderNotice` when notification permission is refused |

The Schedule row does not currently display a street address. Address fields exist on `Booking`, but are used in booking detail. Do not promote them into the list without product approval.

## Real appointment states

- `confirmed`
- `completed`
- `cancelled_by_customer`
- `cancelled_by_groomer`
- `unknown` (decode-tolerance fallback, not a normal product state)

Cancelled bookings are excluded from the day strip's active booking dates and from `selectedBookings`; therefore the current Schedule timeline normally shows confirmed or completed appointments. There are no `upcoming`, `checkedIn`, or `inProgress` production booking states.

## Actions and navigation

| Action | Availability | Result |
| --- | --- | --- |
| Select day | day chip | local filter only; not persisted |
| Pull to refresh / foreground refresh | Schedule root | `BookingsStore.load()` |
| Load more | repository has `nextPageRequest` | appends unique bookings |
| Tap appointment | every timeline row | `NavigationLink` to `BookingDetailView(bookingID:role:.groomer)` |
| Message | every shown Schedule row | `onOpenChat(booking)`; Groomer tab shell selects Messages and focuses the booking conversation |
| Complete | only `role == .groomer && status == .confirmed` | `BookingsStore.complete` → repository RPC → status completed; reminder cancelled |
| Cancel | only confirmed booking; current entry is in booking detail action bar | `BookingsStore.cancel` → repository RPC → cancelled status; reminder cancelled |

`Check In` and `Start Service` were not found in the production model, Store, repository, tests, or Schedule View. They must not appear. Cancel is not a permanent full-width Schedule-row action. The current production detail action invokes Cancel directly; a confirmation dialog is a design requirement from the approved handoff but is **not currently implemented** and must be labelled as such in exploration.

## Loading, empty, error, and disabled behavior

- Initial loading with no data: `Loading Schedule...` / `Fetching confirmed appointments for your day.`
- Empty selected day: day-specific `GroomerScheduleEmptyDayView`; no duplicate summary.
- Initial persistent error with no bookings: `We Could Not Load Schedule`, mapped message, `Try Again` calling `store.load()`.
- Load-more: button is present while `canLoadMore || isLoadingMore`.
- Complete/Cancel disabled while either completion or cancellation mutation is busy.
- Mutation errors surface through shared `BookingsStatusView`; repository errors include not allowed, not found, not cancellable/completable, network unavailable, and unavailable.

## Travel Buffer and filtering

- Date switching is implemented.
- Search, status filtering, location filtering, and calendar-view switching were not found.
- **Travel Buffer: 未发现实现.** No buffer field, model, repository value, View, Store logic, fixture, or test was found. Do not show a buffer as if it were production data. A concept may reserve a clearly annotated future gap treatment only if it is visually labelled `Not implemented — product decision required`.

## Forbidden inventions

- No Check In, Start Service, in-progress status, drag-to-reschedule, calendar sync, maps route, travel-time calculation, conflict detection, staff assignment, payments, customer avatar, customer full name, or address-in-list behavior.
- No permanent full-width Cancel/Delete action.
- Do not turn `unknown` into a normal operational state.
- Do not imply status transitions other than confirmed → completed or confirmed → cancelled.
