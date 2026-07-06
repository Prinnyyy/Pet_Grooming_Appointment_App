# T-036 Groomly Signed-Out Landing Screenshot UI

Task ID: `T-036`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Rework the new-user signed-out app home screen from the uploaded screenshot. The circular hero module should drop in from the top, and soft bubbles should float near the center. Use the screenshot as direction but improve the current UI rather than hard-copying it.

Screenshot/source reference:

- `/Users/liafenyua/Desktop/未命名文件夹/截屏2026-06-22 上午12.26.36.png`

## Primary Task

Rework only the signed-out authentication landing screen represented by the screenshot.

Target screen and role:

- Screen: `AuthenticationView` signed-out entry surface
- Role: `Shared`

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. targeted `docs/00_memory/CURRENT_STATE.md` sections when current state or risks matter
4. `docs/01_product/SCREEN_INVENTORY.md`
5. `docs/01_product/DESIGN_SYSTEM.md`
6. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationView.swift`
7. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationStore.swift`
8. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationGateView.swift`
9. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/RoleOnboardingView.swift`
10. relevant launch smoke test if the root accessibility identifier changes

## Screenshot Analysis

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Warm full-screen signed-out background | visual-only | yes | `AuthenticationView` | none | implement |
| Top Customer/Groomer pill switcher | visual-only | partial | `AuthenticationView` local UI state | true persisted role remains `RoleOnboardingView` -> `AuthenticatedEntryStore` -> `create_my_profile` | implement as non-persistent visual audience selector only |
| iOS status bar / device frame | visual-only | system-owned | none | none | do not implement |
| Dropping circular pet hero module | visual-only | yes | `AuthenticationView` | none | implement with SwiftUI local animation and Reduce Motion handling |
| Floating center bubbles | visual-only | yes | `AuthenticationView` | none | implement with lightweight local animation and Reduce Motion handling |
| Groomly title and short value copy | visual-only | yes | `AuthenticationView` | none | implement |
| `Get Started` action | existing-feature rewire | yes | `AuthenticationView` | `AuthenticationStore.mode = .signUp`, existing `submit()` flow | implement as entry to existing create-account form |
| `I already have an account` action | existing-feature rewire | yes | `AuthenticationView` | `AuthenticationStore.mode = .signIn`, existing `submit()` flow | implement as entry to existing sign-in form |
| Existing email/password form | existing-feature rewire | yes | `AuthenticationView` | `AuthenticationStore` and `AuthSessionRepository` | preserve behavior, present after landing action |

## Scope

In scope:

- Replace the immediate signed-out form with a polished landing state.
- Preserve existing sign-in and create-account form behavior after the landing CTA.
- Use existing Groomly tokens/primitives where practical.
- Add only local SwiftUI state for landing audience choice and animation.
- Keep accessibility identifiers current for launch smoke coverage.

Out of scope:

- Persisting the pre-auth Customer/Groomer choice.
- Preselecting or creating a user role before authenticated profile onboarding.
- Auth repository, Supabase Auth, profile RPC, schema, RLS, Storage, or backend changes.
- Redesigning `RoleOnboardingView` or authenticated app tabs.

## Implementation Plan

1. Add local landing/form display state to `AuthenticationView`.
2. Build a signed-out landing surface with a visual-only audience switcher, animated hero circle, floating bubble layer, title, subtitle, and two actions.
3. Reuse the existing form fields and `AuthenticationStore.submit()` path after `Get Started` or account sign-in is selected.
4. Update the launch smoke test to accept the new signed-out landing accessibility identifier.
5. Run one standard validation attempt: `./scripts/ios-build.sh`, then `git diff --check`.

## Validation

Default validation:

```sh
./scripts/ios-build.sh
git diff --check
```

## Acceptance

- Screenshot modules are implemented only within visual-only or existing-feature classifications.
- Existing Supabase Auth and role onboarding behavior are unchanged.
- The signed-out landing has the requested circle drop-in and floating bubble motion with Reduce Motion handling.
- No backend, schema, repository, profile role, or authenticated-tab changes are introduced.

## Closeout

Status: `completed`

Changed files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceUITests/AppLaunchSmokeTests.swift`
- `docs/06_tasks/T-036_GROOMLY_SIGNED_OUT_LANDING_SCREENSHOT_UI.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- `./scripts/ios-build.sh` passed.
- `git diff --check` passed.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- `auth.landing` was visible in the runtime UI snapshot.

Notes:

- The Customer/Groomer selector on the signed-out landing is visual-only local UI state.
- The authoritative role remains created only after authentication in `RoleOnboardingView`.
- No Supabase, repository, schema, RLS, Storage, or product-flow changes were made.
