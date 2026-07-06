# T-028 - Groomly Customer Request Detail and Offers UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-027.

## Goal

Apply Groomly styling to customer-owned request detail, offer review, offer detail, and offer acceptance entry points while preserving the current request -> offer -> booking behavior.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`
4. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
5. `docs/08_design/design_tokens.json`
6. `docs/01_product/DESIGN_SYSTEM.md`
7. `docs/04_ios/SWIFTUI_STATE_RULES.md`
8. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
9. Groomly primitive files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`

## Scope

In scope:

- Restyle only `CustomerRequestDetailView`, `CustomerOfferReviewSection`, `CustomerOfferSummaryRow`, and `CustomerOfferDetailView`.
- Use Groomly cards, section headers, status chips, primary/secondary buttons, error banners, and tokenized metadata rows.
- Preserve pending/history offer grouping, offer selection, offer detail presentation, acceptance action, busy state, error state, and navigation back to bookings after acceptance if present.
- Preserve existing customer-only ownership assumptions and Store/repository boundaries.

Out of scope:

- Customer Requests list shell and wizard already covered by T-026 and T-027.
- Groomer offer creation, groomer request feed, booking list/detail restyle, chat, account, debug, backend, repository, Store, model, routing, scripts, assets, or Supabase changes.
- Offer negotiation, cancellation, rescheduling, payments, signed images, or any unsupported prototype behavior.

## Implementation Rules

- Product correctness takes priority over prototype visual matching.
- Keep the accepted contract: matched groomers make offers, customer accepts one offer, booking/chat are created.
- Do not change acceptance semantics, duplicate-submit guards, repository calls, or booking creation side effects.
- Do not introduce fake offer data or local success paths.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

## Acceptance

- Customer request detail and offer review surfaces use Groomly card/status/action styling.
- Pending offers, offer history, offer detail, acceptance busy/error states, and existing navigation behavior remain intact.
- No backend, Store, repository, model, groomer, booking, chat, account, debug, script, asset, or tab-routing file is changed.
- Next planned task remains T-029.

## Stop Conditions

Stop and report if visual matching requires changing offer acceptance, booking creation, request statuses, customer ownership rules, or any unsupported prototype feature.
