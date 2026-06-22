# T-031 - Groomly Groomer Profile and Services UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-030.

## Goal

Apply Groomly styling to groomer profile and services management while preserving existing profile load/save, service create/edit/delete, validation, and repository behavior.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`
4. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
5. `docs/08_design/design_tokens.json`
6. `docs/01_product/DESIGN_SYSTEM.md`
7. `docs/04_ios/SWIFTUI_STATE_RULES.md`
8. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`
9. Groomly primitive files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`

## Scope

In scope:

- Restyle `GroomerProfileManagementView`, `GroomerProfileFormSection`, `GroomerServicesSection`, `GroomerServiceRow`, `GroomerServiceFormView`, and `GroomerProfileStatusView`.
- Use Groomly background, cards, section headers, form fields, status chips, loading/empty/error, and groomer-accent buttons.
- Preserve profile load/save, service list, service create/edit/delete, sheet navigation, disabled states, validation, notices, and errors.
- Keep the existing portfolio section mounted, but reserve portfolio body restyling for T-032.

Out of scope:

- `GroomerPortfolioSection` body restyling except compile-safe integration needed to keep the screen working.
- Groomer request/offer screens, customer screens, bookings, chat, account sign-out, debug, backend, Store, repository, model, scripts, assets, or routing changes.
- Availability, payouts, reviews, signed images, service marketplace search, or deferred prototype features.

## Implementation Rules

- Keep state ownership in `GroomerProfileStore`.
- Do not change profile completeness rules, service validation, repository calls, or Storage behavior.
- Do not turn UI helpers into profile/service business logic.
- Use groomer coral accent for primary groomer profile actions.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Status:

- `./scripts/ios-build.sh` passed on 2026-06-22 after one local string-format correction.
- Post-review `./scripts/ios-test.sh` passed on 2026-06-22.
- `git diff --check` passed on 2026-06-22.

## Acceptance

- Groomer profile and services management use Groomly form, card, status, feedback, and action styling.
- Existing profile/service load, save, create, edit, delete, validation, notices, errors, and disabled states are preserved.
- No Store, repository, model, backend, Supabase, script, asset, request, booking, chat, debug, or tab-routing file is changed.
- Next planned task remains T-032.

## Stop Conditions

Stop and report if the restyle requires changing service data contracts, profile validation, repository calls, Storage behavior, or portfolio functionality reserved for T-032.
