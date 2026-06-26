# T-024 - Groomly Auth and Onboarding UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-023D2 Groomly feedback primitives.

## Goal

Apply the Groomly visual direction to the authentication and role onboarding screens only, while preserving the existing auth/session/profile routing behavior.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
4. `docs/08_design/design_tokens.json`
5. `docs/01_product/DESIGN_SYSTEM.md`
6. `docs/04_ios/SWIFTUI_STATE_RULES.md`
7. Auth SwiftUI files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/`
8. Groomly primitive files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`

## Scope

In scope:

- Restyle only:
  - `AuthenticationBootstrapView`
  - `AuthenticationGateView`
  - `AuthenticationView`
  - `AuthenticatedEntryView` loading and profile-load failure states
  - `RoleOnboardingView`
- Use existing `DesignTokens` and Groomly primitives.
- Add a small reusable form-field primitive under `DesignSystem` only if needed to avoid scattering field styling.
- Preserve existing visible auth/onboarding copy unless a minor wording alignment is needed for Groomly branding.
- Update `docs/01_product/DESIGN_SYSTEM.md`, `docs/00_memory/CURRENT_STATE.md`, `docs/00_memory/WORKLOG.md`, `docs/06_tasks/TASK_LEDGER.md`, and active-task entrypoint docs if they still point at completed T-023 work.

Out of scope:

- Customer, groomer, booking, chat, account, debug, request, or pet feature screens.
- Auth repository, session persistence, profile repository, Stores, models, backend, Supabase migrations, scripts, or assets.
- Social login, password reset, native email-confirmation deep links, demo data, or fake local success paths.
- Changing customer/groomer role semantics or routing.

## Implementation Rules

- Keep SwiftUI views thin; no repository, network, or Supabase calls in layout code.
- Preserve loading, error, disabled, and duplicate-submit states.
- Use customer mint as the auth/onboarding primary accent and groomer coral only for the groomer role option.
- Do not copy HTML/CSS/React from the prototype.
- Do not manually edit `project.pbxproj` unless the build proves it is necessary.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Run only one build attempt by default. If the build fails, fix only errors clearly caused by this task and stop after the allowed targeted repair attempts from project rules.

## Acceptance

- AuthGate loading and profile loading/error states use Groomly feedback primitives.
- Sign In and Sign Up retain existing submission behavior, disabled state, notice state, and error state.
- Role Onboarding retains immutable role selection behavior, submit behavior, sign-out action, and error state.
- Auth/onboarding visual styling uses centralized `DesignTokens` or Groomly primitives.
- No non-Auth feature screens are restyled or rewired.
- No backend, repository, model, Store, Supabase, script, or asset file is changed.
- `./scripts/ios-build.sh` passes or the first real build error is reported under stop rules.
- `git diff --check` passes.
- Current state and task ledger point to the next screen-specific Groomly task instead of auto-starting it.

## Stop Conditions

Stop and report if:

- The restyle requires auth/session/profile Store or repository behavior changes.
- The implementation would require backend or Supabase changes.
- The work begins to restyle non-Auth feature screens.
- Build fails for reasons unrelated to this task.
