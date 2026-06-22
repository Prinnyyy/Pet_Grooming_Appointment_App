# T-027 - Groomly Customer Request Wizard UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-026.

## Goal

Apply Groomly styling to the customer request creation wizard while preserving the existing publish-request fields, validation, disabled states, Store calls, and RPC contract.

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

- Restyle only `CustomerRequestWizardView` and directly required local sub-layout inside `CustomerRequestsView.swift`.
- Use Groomly cards, form fields, buttons, section headers, error banners, and status copy where appropriate.
- Preserve `NavigationStack`, Cancel/Save or publish actions, disabled states, duplicate-submit protection, and interactive dismissal behavior already owned by the view/store.
- Preserve existing pet selection, service details, schedule, location, notes, price input, validation, and submit behavior.

Out of scope:

- Customer request list/status shell already covered by T-026.
- Customer request detail, offer review, offer acceptance, groomer screens, bookings, chat, account, debug, backend, Store, repository, model, routing, or tab changes.
- New request types, cancellation, maps, calendars, price quoting changes, pet-photo rendering, or other deferred prototype features.

## Implementation Rules

- Keep validation and mutation behavior in existing Store/view state paths.
- Use `.groomlyFormField()` for compatible text fields.
- Do not introduce business logic in layout-only helpers.
- Do not add dependencies or public APIs.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

## Acceptance

- Request wizard form uses Groomly cards, form fields, buttons, error/notice styling, and tokenized spacing.
- Existing publish-request behavior, field validation, disabled states, and sheet/navigation behavior are preserved.
- No Store, repository, model, backend, Supabase, script, asset, or non-wizard screen is changed.
- Next planned task remains T-028.

## Stop Conditions

Stop and report if the wizard restyle requires changing request RPC inputs, validation rules, pet data loading, matching behavior, or any backend contract.
