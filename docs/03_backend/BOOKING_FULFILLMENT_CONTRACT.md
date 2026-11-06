# Booking Fulfillment Contract

## T-466 adopted replacement

The user-approved Grooming flow is deployed by T-466 and supersedes the historical action semantics below. Six migrations were applied after transactional rollback validation; the adoption plan records the remaining delivery evidence.

- A confirmed appointment displays **In service** at its scheduled start. This is a clock projection, not a fabricated `start` operation or actual-start timestamp.
- After scheduled start, either participant may mark it **Finished** through the existing versioned `complete` operation. No counterpart confirmation is required. Scheduled end alone never finishes a booking or makes it reviewable; the completion action remains available later.
- Pre-start cancellation remains participant-owned. New interruption, no-show, unfulfilled and retrospective-confirmation actions are retired. Existing historical rows and receipts remain readable. Legacy clients cannot create retired actions through the authoritative writer.
- Customer review requires explicit completion. This replaces T-421's elapsed-but-unverified review eligibility for new submissions. Existing reviews are preserved.
- Completion preserves existing actual timestamps when present; it does not invent missing ones. Early release is clamped to the agreed service interval. No buffers are reintroduced.
- The same actor/operation ID, exact-intent replay, revision checks, request/booking/admission lock order, one chat card and participant permissions remain. Only `completed_by` expands from groomer-only to either participant.
- Reschedule state includes immutable operation history with actor and recorded time. Only a proposal Activity entry repeats previous/proposed service intervals; responses record their action/time. Automatic start creates no Activity event.

Validation/deployment status belongs to [T-466](../superpowers/plans/2026-11-05-groomer-grooming-adoption.md), not the historical acceptance link below.

## Historical deployed contract (before T-466)

T-377 / WP-06. Adopted under delegated judgment, deployed and [accepted](../06_tasks/sql_reviews/T-377_FULFILLMENT_ACCEPTANCE.md). Extends Booking, not a general workflow engine.

## Timing And Release

- Groomer Start uses server time, no earlier than scheduled start and before scheduled end; no backdating. Normal completion requires a recorded Start and at least one elapsed minute.
- Early completion records actual end. Pet occupancy ends then; groomer occupancy retains agreed cleanup/outbound travel. Neither resource silently extends beyond its planned allocation.
- Either participant may cancel before scheduled start if service has not started. Later exceptions use outcome reports, not immediate cancellation.
- Unilateral interruption/no-show reports do not release occupancy. The other participant may confirm the stop; after scheduled end either participant may close unresolved service without assigning fault. Buffered release stays inside the original allocation.
- No-show reports require no recorded Start and a 15-minute wait after scheduled start. They record an observation, not proven fault.
- Daily limits count reserved appointments that started or ended unfulfilled; pre-start cancellations do not count. This conservative quota differs from available time-slot capacity.

## Actions

| Action | Actor / Preconditions | Result |
|---|---|---|
| start | Groomer; scheduled; allowed window | In service; actual start |
| complete | Groomer; in service; one elapsed minute | Completed; actual end; buffered release |
| cancel | Either; before start; not in service | Cancelled; release |
| report_interruption | Either; at/after scheduled start; unresolved | Awaiting confirmation; no release |
| report_no_show | Either; no actual start; wait elapsed | Awaiting confirmation; no release |
| confirm_stop | Other participant; interruption/no-show report | Unfulfilled; buffered release |
| withdraw_report | Report author | Previous phase; audit retained |
| close_elapsed | Either; scheduled end passed; unresolved | Unfulfilled without blame |
| report_completion | Either; scheduled end passed; missed tracking or prior unfulfilled outcome | Bilateral retrospective confirmation pending |
| confirm_completion | Other participant; completion report | Completed; unknown actual times stay unknown |
| record_objection | Either; terminal outcome | Observation only; no automatic state/review reversal |

Public status adds unfulfilled; fulfillment phase separates scheduled, in-service, outcome-report and terminal states. Retrospective confirmation is an explicit bilateral correction, not fabricated timestamps. Existing completed bookings retain legacy provenance. Start cannot be undone or moved earlier; mistakes use outcome/objection records.

## Wire And Ownership

- `mutate_booking_fulfillment(booking_id, expected_revision, operation_id, action, note)` is participant-owned/non-anonymous. Required notes are trimmed and bounded to 500 characters.
- One transaction follows existing request/booking/admission locking, validates revision/action, updates outcome/release and appends an immutable participant-readable event/receipt and required Chat event.
- Owned read-only receipt lookup reconciles uncertainty. Same operation/intent returns the original receipt and current Booking, never a second event or stale success projection. Different intent cannot reuse an operation ID.
- Old unversioned completion/cancellation requires a compatible client; direct table/event writes remain denied.
- Planned agreement/timing stays immutable. Explicit effective pet/groomer release timestamps feed constraints, admission, matching, quote evaluation and coverage checks.
- Repository/Store own mutations/recovery. SwiftUI presents valid actions. Verified completion permits one customer review with its frozen service evidence. T-421 also permits an elapsed confirmed booking to receive a rating with an empty, unverified context; unresolved outcome reports remain excluded. The [current eligibility contract](SUPABASE_CONTRACT.md) governs this customer journey projection without changing fulfillment state.

## Recovery And Acceptance

Elapsed unresolved bookings remain actionable. Customer recovery uses Chat, the existing support route without promised adjudication, and an explicit new-request template after unfulfilled closure. Original request/offers stay closed.

Verify future/early/elapsed boundaries, all actions/corrections, release buffers/quota/matching, replay and terminal races, foreign/direct writer denial, lost responses, both-role runtime and package regression/deployment. WP-07 owns rescheduling, WP-11 global reminders, WP-14 physical-device/distribution qualification. No penalties, arbitration staffing or account-timezone settings.
