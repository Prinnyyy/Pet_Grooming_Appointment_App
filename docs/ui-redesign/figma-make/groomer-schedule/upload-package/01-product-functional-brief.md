# Groomer Schedule — Product and Functional Brief

## Product contract

Design the authenticated Groomer's Schedule tab as a daily agenda. The user chooses a date, scans active appointments chronologically, opens booking details, messages the customer, and completes an eligible booking. The native five-tab structure is Home, Requests, Schedule, Messages, and Account, with Schedule selected.

### Real list content

- Date strip and selected date.
- Appointment count, next start time, and total booked duration.
- Start and end time.
- Pet name.
- Breed or species plus service name.
- Customer reference code. A customer display name and avatar are unavailable.
- Location mode: `Mobile`, `Studio`, or fallback `Location`.
- Text-and-icon booking status.
- Optional notification-permission reminder.

Street address exists on a booking but currently belongs in Booking Detail, not the Schedule row.

### Real states

- `Confirmed`
- `Completed`
- `Cancelled by customer`
- `Cancelled by groomer`
- `Unknown` decode fallback, not a normal operational state

Cancelled bookings are filtered out of the active daily timeline. There are no production `Upcoming`, `Checked In`, `In Progress`, or `Start Service` states.

### Real actions and navigation

- Select a day: changes a local, non-persisted day filter.
- Pull/foreground refresh: reloads bookings.
- Load More: appears when another repository page exists.
- Tap a row: pushes Booking Detail.
- Message: opens the booking conversation in Messages.
- Complete: Groomer-only and only for a Confirmed booking; updates it to Completed.
- Cancel: only for a Confirmed booking and belongs in Booking Detail. Do not show a permanent full-width Cancel/Delete action in Schedule. The future design requires confirmation, although the current production detail action does not yet implement that dialog.

Initial Loading, selected-day Empty, persistent Error with Try Again, load-more, and mutation-disabled states must be covered. Search, status/location filters, calendar-view switching, drag-to-reschedule, conflict handling, staff assignment, maps routing, payments, and calendar sync are not implemented.

### Location and Travel Buffer rules

- `Mobile` means the groomer comes to the customer.
- `Studio` means the customer comes to the groomer.
- `Travel Buffer` has no production model, repository field, Store logic, UI, or test. Do not render it as real agenda data. It may appear only as an external annotation: `Not implemented — product decision required`.

## Information hierarchy

1. **Primary:** start time, pet name, status.
2. **Secondary:** end time, breed/species and service, Mobile/Studio.
3. **Tertiary:** customer reference, day summary, reminder, disclosure, Message, and eligible Complete.

Keep chronological order and align time as the main scan anchor. Pet name, service, status, selected date, feedback, and action labels must never truncate. Customer reference and location may wrap or move below service. Full address, price, IDs, audit metadata, and review may remain in detail.

At Accessibility XL, retain the order time → pet → status → service. Move the badge to a new row and stack actions when needed rather than shrinking content.

## Required concepts

All concepts use exactly the fixtures in `03-content-fixtures.md` and include a 393pt Default frame plus an Accessibility XL frame.

1. **Balanced Operations:** balanced date summary, chronological appointment objects, and restrained real actions; closest to the approved normalized reference.
2. **Agenda First:** time becomes a continuous dominant scan rail while remaining a native scrolling iPhone agenda, not a desktop calendar grid.
3. **Compact Schedule:** highest useful Groomer density with readable status, pet/service priority, content-driven height, and valid touch targets.

Every concept must include native top navigation, selected Schedule tab, date switching, day summary, three fixture appointments, detail navigation, correct Message/Complete behavior, bottom-safe scrolling, and Loading/Empty/Error coverage. Do not invent business fields, actions, or state transitions.
