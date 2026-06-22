# T-029 - Groomly Groomer Requests Feed and Detail UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-028.

## Goal

Apply Groomly styling to the groomer matched-request feed and request detail shell while preserving matched-request loading, dismiss, selection, and existing offer entry behavior.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`
4. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
5. `docs/08_design/design_tokens.json`
6. `docs/01_product/DESIGN_SYSTEM.md`
7. `docs/04_ios/SWIFTUI_STATE_RULES.md`
8. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Requests/GroomerRequestsView.swift`
9. Groomly primitive files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`

## Scope

In scope:

- Restyle only `GroomerRequestsView`, `GroomerRequestSummaryRow`, `GroomerRequestDetailView` metadata/detail shell, and `GroomerRequestsStatusView`.
- Use groomer coral accent for primary groomer actions.
- Use Groomly background, cards, section headers, status chips, loading, empty, error, and secondary action styling.
- Preserve request load, refresh, empty/error retry, selection, dismiss, and navigation behavior.
- Keep the existing offer section mounted, but reserve offer form/status body restyling for T-030.

Out of scope:

- Groomer offer form/status restyle, customer request/offer screens, groomer profile/portfolio, bookings, chat, account, debug, backend, Store, repository, model, scripts, assets, or routing changes.
- New matching rules, availability, scheduling, maps, payments, or deferred prototype features.

## Implementation Rules

- Keep state ownership in `GroomerRequestsStore`.
- Do not change matched-request filtering, dismissal semantics, offer eligibility, or repository calls.
- Do not move mutation logic into UI helpers.
- Do not copy HTML/CSS/React from the prototype.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

## Acceptance

- Groomer request feed/detail shell uses Groomly background, cards, headers, status chips, feedback, and groomer-accent actions.
- Existing load, retry, selection, dismiss, and offer entry behavior is preserved.
- No Store, repository, model, backend, Supabase, script, asset, customer, booking, chat, account, debug, or tab-routing file is changed.
- Next planned task remains T-030.

## Stop Conditions

Stop and report if the restyle requires changing matching, dismissal, offer eligibility, backend contracts, or the offer form behavior reserved for T-030.
