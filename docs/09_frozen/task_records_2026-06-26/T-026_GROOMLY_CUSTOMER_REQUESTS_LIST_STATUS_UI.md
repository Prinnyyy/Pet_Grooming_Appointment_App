# T-026 - Groomly Customer Requests List/Status UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-025 and planned UI completion sequence `T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`.

## Goal

Apply Groomly styling to the customer Requests tab shell, request list, summary rows, and loading/empty/error states while preserving the existing customer request Store, repository, navigation, request publishing entry point, and offer behavior.

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

- Restyle only `CustomerRequestsView`, `CustomerRequestSummaryRow`, and `CustomerRequestsStatusView`.
- Replace default list/status visuals with Groomly background, `ScrollView`/stack/card composition, section header, status chips, loading, empty, and error primitives.
- Preserve navigation to existing request detail and request wizard surfaces.
- Preserve existing loading, refresh, empty, error, retry, and accessibility behavior.
- Keep the "new request" entry point available, but do not restyle the wizard body beyond what is needed for the tab shell.

Out of scope:

- `CustomerRequestWizardView`, `CustomerRequestDetailView`, `CustomerOfferReviewSection`, `CustomerOfferSummaryRow`, and `CustomerOfferDetailView` body restyling beyond compile-safe integration points.
- Customer request Store, repositories, models, Supabase schema, RLS, RPCs, matching, offer acceptance, bookings, chat, tabs, account, debug, groomer screens, or backend work.
- Request cancellation, favorites, images, maps, payments, calendars, or other deferred prototype features.

## Implementation Rules

- Keep customer mint as the screen accent.
- Keep state ownership in `CustomerRequestsStore`.
- Do not move validation, retry, navigation, or mutation logic into layout helpers.
- Use existing Groomly primitives before adding any new DesignSystem helper.
- Do not copy HTML/CSS/React from the prototype.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

## Acceptance

- Customer Requests tab list/status shell uses Groomly background, cards, section header, status chips, loading, empty, and error styling.
- Existing request load, refresh, retry, selection, and navigation behavior is preserved.
- The request wizard and request detail still open through the existing paths.
- No Store, repository, model, backend, Supabase, script, asset, groomer, booking, chat, account, debug, or tab-routing file is changed.
- Next planned task remains T-027, not an automatic implementation.

## Stop Conditions

Stop and report if the restyle requires request creation, offer acceptance, repository, backend, or model changes, or if the work begins to restyle the wizard/detail/offer bodies reserved for T-027 and T-028.
