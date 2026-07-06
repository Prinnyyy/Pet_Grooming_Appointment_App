# T-021 — Booking Completion and Customer Review

- State: completed.
- Mode: Deep.
- Depends on: T-018, T-019, T-020.
- Scope: completion/review backend contract plus Bookings-tab UI for groomer completion and customer review.

## Goal

Implement the completed-booking lifecycle:

- The booked groomer can mark a confirmed booking completed through `complete_booking`.
- The booked customer can create one review for a completed booking through `create_review`.
- `reviews` are readable by booking participants.
- Groomer rating summary is updated by the backend when a review is created.

## Boundaries

In scope:

- `reviews` table, grants, RLS, indexes, and constraints.
- `bookings.completed_at` / `bookings.completed_by` audit fields.
- `complete_booking` and `create_review` RPCs.
- iOS Booking model/repository/store/UI support for completion and review.
- Focused BookingStore tests.

Out of scope:

- Disputes, refunds, moderation tools, no-show states, review editing/deletion, public marketplace review browsing, notifications, realtime, payments, and rebooking.

## Implemented Work

- Primary migration mirror: `supabase/migrations/20260621065954_t021_completion_reviews.sql`.
- Corrective migration mirror: `supabase/migrations/20260621070826_t021_fix_create_review_returning_ambiguity.sql`.
- iOS changes are implemented under the existing `BookingRepository` boundary.
- Bookings detail now has UI for:
  - groomer completion on confirmed bookings,
  - customer review form on completed bookings without an existing review,
  - participant review display after submission.

## Validation Checkpoint

First command run:

```sh
./scripts/ios-test.sh
```

Result: failed during build before tests executed.

First real error:

```text
ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Booking.swift:52:61:
main actor-isolated conformance of 'BookingReview' to 'Equatable' cannot be used in nonisolated context
```

Root cause:

- The project builds with default MainActor isolation.
- `Booking.canReview(for:)` is `nonisolated`.
- `review == nil` invokes `Optional<BookingReview>` equality, which requires `BookingReview`'s synthesized `Equatable` conformance from a nonisolated context.

Minimal targeted fix:

- Replace the `review == nil` comparison with a nil pattern check that does not invoke `Equatable`.

Follow-up approved fix:

- `Booking.canReview(for:)` now uses a nil pattern check instead of `review == nil`.

Second command run:

```sh
./scripts/ios-test.sh
```

Result: failed during build before tests executed.

Current first real error:

```text
ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift:303:65:
type 'DesignTokens' has no member 'Radius'
```

Root cause:

- `BookingsView` references `DesignTokens.Radius.small`.
- The actual design token namespace is `DesignTokens.CornerRadius`.

Follow-up approved fix:

- `BookingsView` now uses the existing `DesignTokens.CornerRadius.card` token.

Third command run:

```sh
./scripts/ios-test.sh
```

Result: passed.

Evidence:

```text
** TEST SUCCEEDED **
```

Observed coverage:

- Swift Testing suite passed; the script reporter showed 65 Swift Testing tests, while line-count based log greps may differ by one because of reporter formatting.
- 1 XCTest UI smoke test passed.

## Remote Migration Checkpoint

Approved MCP migration applies:

- Project: `lqmasbuqzvcvtawonjlb`.
- Applied primary migration: `20260621065954_t021_completion_reviews`.
- Applied corrective migration: `20260621070826_t021_fix_create_review_returning_ambiguity`.

MCP metadata verification passed:

- `bookings.completed_at` and `bookings.completed_by` exist.
- `public.reviews` exists with RLS enabled.
- `reviews_select_booking_participants` is the only `reviews` SELECT policy.
- `authenticated` has `SELECT` on `reviews`; no `anon` table grant was observed.
- `complete_booking` and `create_review` are `SECURITY DEFINER` functions with empty `search_path`.
- `complete_booking` and `create_review` have `EXECUTE` only for `authenticated` and `service_role` among checked public API roles.

Advisor checkpoint:

- Security advisor reports 8 expected `SECURITY DEFINER` WARNs: 6 prior controlled RPCs plus T-021 `complete_booking` and `create_review`.
- Performance advisor reports existing non-blocking INFOs plus expected unused-index INFOs for new `reviews` indexes before production traffic.

Rollback-only behavior validation:

- First behavior batch exposed a test-harness issue after an expected error subtransaction reset the simulated JWT context.
- Corrected behavior batch exposed a real function bug:

```text
ERROR: 42702: column reference "created_at" is ambiguous
CONTEXT: PL/pgSQL function public.create_review(uuid,integer,text)
```

Root cause:

- `create_review` returns an OUT column named `created_at`.
- Its `insert into public.reviews ... returning id, created_at` references `created_at` without qualifying the inserted table alias.
- PostgreSQL cannot distinguish the table column from the function OUT column.

Corrective migration applied:

- `20260621070826_t021_fix_create_review_returning_ambiguity.sql`
- Replaces `create_review` with the same signature and behavior but uses `insert into public.reviews as review ... returning review.id, review.created_at`.

Final rollback-only behavior validation passed:

- booked groomer completes a confirmed booking;
- `complete_booking` is idempotent for an already completed booking;
- customer cannot complete a booking;
- booked customer can create one completed-booking review;
- review content is server-trimmed;
- duplicate reviews are rejected with `review_already_exists`;
- incomplete bookings cannot be reviewed;
- customer and groomer participants can select the review through RLS;
- non-participants cannot select the review;
- direct authenticated review insert is denied.

Final residue check:

- Rollback validation left zero T-021 validation auth users, reviews, and bookings.

Final advisor checkpoint:

- Security advisor reports 8 expected `SECURITY DEFINER` WARNs: 6 prior controlled RPCs plus T-021 `complete_booking` and `create_review`.
- Performance advisor reports existing non-blocking INFOs plus expected unused-index INFOs for new `reviews` indexes before production traffic.

Local static checks:

- `./scripts/supabase-check.sh` passed.
- `git diff --check` passed.

## Post-review Local Follow-up

The post-review UI-only follow-up reduced the booking screen's dependence on reference-code-first presentation:

- Booking rows now lead with the appointment status, scheduled time, price, and participant support summary.
- Booking details now separate stable appointment facts from support references.
- Rich participant names and pet/request summaries remain deferred because the current backend/RLS contract does not yet provide a stable cross-role presentation summary for both participants.

The following review notes require a separate approved SQL corrective task if they are promoted from MVP follow-up to backend contract changes:

- recompute groomer rating averages from authoritative `reviews` rows or maintain a precise rating sum to eliminate possible incremental rounding drift;
- add authoritative scheduled-time gating to `complete_booking` if completing before service time must be rejected by the backend, not only discouraged in UI copy.

## Closeout

T-021 is complete.

Next recommended task: T-022 — MVP hardening, empty/error/loading state pass, Debug Panel, RLS negative tests, conflict boundary tests, and core E2E acceptance.
