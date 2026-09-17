# T-033 - Groomly Bookings UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-032.

## Goal

Apply Groomly styling to shared customer/groomer bookings list, booking detail, cancellation, completion, and review surfaces while preserving the existing booking Store and repository behavior.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`
4. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
5. `docs/08_design/design_tokens.json`
6. `docs/01_product/DESIGN_SYSTEM.md`
7. `docs/04_ios/SWIFTUI_STATE_RULES.md`
8. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
9. Groomly primitive files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`

## Scope

In scope:

- Restyle `BookingsView`, `BookingSummaryRow`, `BookingDetailView`, `BookingReviewDisplay`, `BookingReviewForm`, and `BookingsStatusView`.
- Use role-appropriate customer mint or groomer coral accent based on the existing role/context available to the view.
- Use Groomly background, cards, section headers, status chips, loading/empty/error, form fields, and primary/secondary buttons.
- Preserve list loading, booking selection, detail presentation, cancellation, groomer completion, customer review submission/display, notices, errors, busy states, and disabled states.

Out of scope:

- Booking backend/RPC changes, repository changes, model changes, request/offer screens, chat, account, debug, scripts, assets, role routing, or Supabase work.
- Rescheduling, calendar integration, payments, push notifications, review moderation/editing, or deferred prototype features.

## Implementation Rules

- Keep booking mutations in existing Store/repository paths.
- Do not change when cancellation, completion, or review actions are available.
- Preserve customer/groomer role behavior exactly.
- Do not add fake booking data or local success states.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Status:

- `./scripts/ios-build.sh` passed on 2026-06-22 after one local generic-type reference fix.
- Post-review `./scripts/ios-test.sh` passed on 2026-06-22.
- `git diff --check` passed on 2026-06-22.

## Acceptance

- Bookings list, booking detail, cancellation/completion controls, and review form/display use Groomly styling.
- Existing load, retry, selection, cancellation, completion, review submission/display, busy, disabled, notice, and error behavior is preserved.
- No Store, repository, model, backend, Supabase, script, asset, request, chat, account, debug, or tab-routing file is changed.
- Next planned task remains T-034.

Completion notes:

- `BookingsView`, booking summary rows, booking detail sections, lifecycle actions, review display/form, and bottom status feedback now use Groomly background, cards, section headers, status chips, feedback primitives, form styling, and role-appropriate accents.
- Existing `store.load()`, booking selection, `store.cancel(_:)`, groomer `store.complete(_:)`, customer review submission, notice/error, busy, and disabled flows remain owned by `BookingsStore`.
- No Store, repository, model, backend, Supabase, script, asset, request, chat, account, debug, tab-routing, or booking-status semantics were changed.

## Stop Conditions

Stop and report if the restyle requires changing booking status semantics, role permissions, completion/review RPC usage, cancellation rules, or backend contracts.
