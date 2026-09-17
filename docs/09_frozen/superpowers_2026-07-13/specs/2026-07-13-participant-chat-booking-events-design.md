<!-- task-artifact
task: T-351
status: completed
type: spec
-->

# Participant Chat And Booking Events Design

Approved by the user on 2026-07-13 for T-351.

## Goal

Keep exactly one durable conversation for each Customer/Groomer pair. Accepting or cancelling a booking appends two ordered messages to that conversation: first a live booking card, then a friendly plain-text message sent by the user who performed the action.

## Data Contract

- `conversations` is unique by `(customer_id, groomer_id)` and no longer owns one `booking_id` or `request_id`.
- Existing duplicate conversations are merged into the earliest conversation for the pair. Existing messages retain sender, body, creation time, and chronological order.
- `messages.kind` is either `text` or `booking_card`.
- A `booking_card` message has `booking_id` and no text body. A `text` message has a trimmed body and no booking ID.
- Booking cards resolve the current participant-authorized booking record, so status and details remain live.
- Existing history is not backfilled with synthetic booking cards.

## Transaction Contract

`app_private.accept_groomer_offer` reuses or creates the pair conversation, then inserts the accepted booking card followed by the friendly text. `app_private.cancel_booking` updates the booking, then inserts the current booking card followed by the cancellation text. Both inserts occur inside the owning RPC transaction and use deterministic timestamps plus IDs to preserve card-before-text order.

Acceptance text:

> Hi! I've accepted your offer and confirmed this booking. Looking forward to working with you!

Cancellation text for either role:

> Hi, I'm sorry, but I've had to cancel this booking. Thank you for understanding.

An RPC retry that does not perform a new state transition must not append duplicate automatic messages.

## Authorization

- Existing conversation and booking participant RLS remains the read boundary.
- Direct authenticated inserts remain text-only and must reject caller-supplied booking cards.
- The privileged lifecycle helpers create booking-card rows only after verifying the actor and valid state transition.
- Public RPC wrappers remain security invoker; privileged implementations remain under `app_private` with empty search paths and explicit schema qualification.

## iOS Contract

- Conversation list identity is the participant pair, not a booking.
- Opening Chat from any booking resolves the pair conversation.
- Text rows retain the current bubble presentation.
- Booking-card rows render a compact live summary and open the same role-specific booking detail destination used from Bookings.
- Pagination, Realtime, unread state, and message ordering remain conversation-scoped.
- No attachment support, custom automatic copy, new dependency, or unrelated chat redesign is included.

## Migration And Verification

The migration must preserve historical messages while merging pair duplicates, update message-notification lookups to use `messages.booking_id` when present, and add static SQL tests for constraints, RPC ordering, grants, RLS, merge logic, and notification compatibility. Remote application is authorized only for Beckon project `lqmasbuqzvcvtawonjlb`, followed by linked history, metadata, positive/negative authorization, dry-run, and advisor verification.
