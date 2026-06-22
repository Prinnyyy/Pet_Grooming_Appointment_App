# T-030 - Groomly Groomer Offer Form and Status UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-029.

## Goal

Apply Groomly styling to groomer offer creation, pending offer status, withdrawal, and offer-related feedback while preserving the existing create/withdraw offer behavior.

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

- Restyle only offer-related UI inside `GroomerRequestDetailView`, including make-offer form fields, pending/withdrawn/accepted status blocks, error/notice feedback, and submit/withdraw actions.
- Use `.groomlyFormField()`, Groomly cards, section headers, status chips, error banners, and groomer-accent button styles.
- Preserve price/date/message input behavior, disabled state, busy state, validation, create-offer action, withdraw action, and duplicate-submit protection.

Out of scope:

- Groomer request feed/detail shell already covered by T-029.
- Customer offer review/acceptance, bookings, chat, profile, portfolio, account, debug, backend, Store, repository, model, scripts, assets, or routing changes.
- Offer negotiation, counteroffers, payouts, payments, availability, or deferred prototype features.

## Implementation Rules

- Keep create/withdraw offer semantics unchanged.
- Keep validation and repository calls in existing Store/view paths.
- Do not introduce fake success states or local-only offer records.
- Use groomer coral accent consistently for primary groomer offer actions.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Status:

- `./scripts/ios-build.sh` passed on 2026-06-22.
- Post-review `./scripts/ios-test.sh` passed on 2026-06-22.
- `git diff --check` passed on 2026-06-22.

## Acceptance

- Groomer offer form and status blocks use Groomly form, card, status, feedback, and action styling.
- Existing create, withdraw, disabled, busy, validation, and error behavior is preserved.
- No Store, repository, model, backend, Supabase, script, asset, customer, booking, chat, profile, account, debug, or tab-routing file is changed.
- Next planned task remains T-031.

## Stop Conditions

Stop and report if the restyle requires changing create/withdraw RPC usage, offer status semantics, validation rules, or backend contracts.
