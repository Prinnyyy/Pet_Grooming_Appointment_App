# Booking Rescheduling Contract

T-378 / original WP-07 accepted under G-07/D-046. Migration `20260908224104` is applied and immutable. See [acceptance evidence](../06_tasks/sql_reviews/T-378_RESCHEDULING_ACCEPTANCE.md).

## Consent And Deadline

- Either current participant may propose a different start time only while the booking is confirmed, scheduled and before its original start. Duration, price, pet, participants, service, address, service timezone and agreed buffers remain unchanged. Other changes require a new request/agreement, not a hidden reschedule.
- One live proposal per booking. Its author consents to the exact proposed interval; only the other participant can accept or reject. The author may withdraw. A competing proposal requires resolving or withdrawing the existing proposal first.
- Expiry is the earliest of 24 hours after creation, original scheduled start, and five minutes before proposed start. Acceptance also revalidates the current advance-notice rule. The old appointment remains binding while a proposal is pending; the proposed slot is not reserved.
- A fulfillment/base-revision change invalidates the proposal. Cancellation, start, completion and expiry cannot be bypassed by a pending proposal. Elapsed/in-service/terminal bookings cannot start a new change.

## Atomic Acceptance

- Reuse request -> booking -> groomer admission locking and validate time after lock waits. Exclude only this booking's own old allocation from pet/groomer conflicts and the target day's count; all other reservations and their effective releases still count.
- Verify complete current weekly hours/time-off/notice/daily quota and finite instants. Preserve original duration and agreed preparation/cleanup/travel buffers. Existing unsupported historical timing/agreement data requires verification or a new request; never invent provenance.
- Replace current booking time/occupancy and agreement snapshot in one transaction after both consents. Keep previous/new snapshots in the accepted proposal record. Original request and quote remain unchanged; the booking's new agreement carries the change lineage.
- On conflict, rejection or expiry the original booking remains intact. Never cancel/reinsert the booking, create a second booking, or temporarily remove the old reservation.

## Recovery And Presentation

- Owned proposal/mutation operations use persistent operation IDs and exact intent replay. Return original receipts plus current proposal/booking state; read-only lookup reconciles a lost response without another write.
- Show original and proposed time in the agreed service timezone, unchanged terms, deadline and author. Present only role/state-legal actions. Accepted changes update the same booking and emit transactional Chat activity and the reminder change input for WP-11.
- Verify own-overlap, changing dates at capacity, competing slot occupation, expiry at original service start, cancellation/acceptance races, replay, both-role consent and one resulting calendar allocation. WP-08/13/11 retain complete-list, general stale-response and global reminder ownership.
