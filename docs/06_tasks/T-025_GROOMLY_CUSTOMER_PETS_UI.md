# T-025 - Groomly Customer Pets/Home UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-024 Groomly Auth and Onboarding UI.

## Goal

Apply the Groomly visual direction to the customer Home/Pets screen only, while preserving the existing customer pet Store, repository, photo metadata, and Storage behavior.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
4. `docs/08_design/design_tokens.json`
5. `docs/01_product/DESIGN_SYSTEM.md`
6. `docs/04_ios/SWIFTUI_STATE_RULES.md`
7. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
8. Groomly primitive files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`

## Scope

In scope:

- Restyle only the customer Home/Pets UI currently implemented in `CustomerPetsView`.
- Use existing `DesignTokens` and Groomly primitives for background, cards, buttons, loading, empty, error, status, and form-field styling.
- Replace the default pet `List` presentation with a Groomly `ScrollView`/stack/card composition.
- Preserve the existing add/edit pet sheet, save/cancel toolbar actions, disabled states, and `interactiveDismissDisabled` behavior.
- Preserve pet photo metadata display, photo upload action, photo delete action, loading state, notice state, error state, and accessibility identifiers.
- Update active project docs so T-025 is completed and the remaining Groomly UI work can continue from T-026.

Out of scope:

- Customer request, offer, booking, chat, account, debug, groomer, or auth screen changes.
- `CustomerPetsStore`, repositories, models, Supabase schema, RLS, RPCs, Storage policies, scripts, assets, or tab routing.
- Remote image rendering, signed URLs, photo thumbnails, request creation shortcuts, favorites, payments, maps, push notifications, or other deferred prototype features.
- New product behavior, fake demo data, or local success paths.

## Implementation Rules

- Keep SwiftUI views thin; no repository, network, or Supabase calls in layout code.
- Do not move validation, duplicate-submit guards, upload limits, or repository error mapping out of `CustomerPetsStore`.
- Use customer mint as the screen accent.
- Do not copy HTML/CSS/React from the prototype.
- Do not add public APIs or dependencies.
- Do not manually edit `project.pbxproj` unless the build proves it is necessary.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Run only one build attempt by default. If the build fails, fix only errors clearly caused by this task and stop after the allowed targeted repair attempts from project rules.

## Acceptance

- Customer Pets/Home uses Groomly background, card, button, loading, empty, error, notice, and form styling.
- Existing pet load, create, edit, soft-delete, upload-photo, delete-photo, notice, error, busy, and disabled behavior is preserved.
- Existing accessibility identifiers for loading, empty, list, add, and form error states remain available.
- No non-Pets feature screen is restyled or rewired.
- No Store, repository, model, backend, Supabase, script, or asset file is changed.
- `./scripts/ios-build.sh` passes or the first real build error is reported under stop rules.
- `git diff --check` passes.
- Current state and task ledger point to the next authorized Groomly UI task instead of auto-starting unrelated work.

## Stop Conditions

Stop and report if:

- The restyle requires `CustomerPetsStore`, repository, model, backend, or Storage behavior changes.
- The implementation would require remote image rendering, signed URLs, or new asset licensing decisions.
- The work begins to restyle Customer Requests, Bookings, Chat, Account, Debug, Groomer, or Auth screens.
- Build fails for reasons unrelated to this task.
