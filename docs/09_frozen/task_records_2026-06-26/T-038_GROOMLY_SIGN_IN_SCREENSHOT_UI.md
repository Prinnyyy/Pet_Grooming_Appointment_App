# T-038 Groomly Sign-In Screenshot UI

Task ID: `T-038`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Use the uploaded prototype login page UI as the direction for the app login page. Ignore the bottom demo module. Re-layout modules rather than hard-copying the screenshot so the screen follows stronger visual hierarchy and spacing.

Screenshot/source reference:

- `/Users/liafenyua/Desktop/未命名文件夹/截屏2026-06-22 上午12.26.45.png`

## Primary Task

Rework only the signed-out sign-in form surface in `AuthenticationView`.

Target screen and role:

- Screen: `AuthenticationView` sign-in form after selecting existing account
- Role: `Shared`

## Screenshot Analysis

Ignore:

- Long oval Customer/Groomer toggle above the visible app screen frame. This is an external prototype/control annotation.
- Bottom `DEMO`, `Customer Demo`, and `Groomer Demo` module. This is not product login behavior and is explicitly out of scope.
- iOS device frame, status bar, Dynamic Island, and home indicator. These are system/prototype chrome.

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| `Welcome back` header | visual-only | yes | `AuthenticationView` form header | none | implement with left-aligned hierarchy |
| Sign-in subtitle | visual-only | yes | `AuthenticationView` form header | none | implement with app copy |
| Email label and input | existing-feature rewire | yes | `AuthenticationView` form | `AuthenticationStore.email` | preserve behavior, restyle layout |
| Password label and input | existing-feature rewire | yes | `AuthenticationView` form | `AuthenticationStore.password` | preserve behavior, add local Show/Hide visibility toggle |
| `Sign In` primary action | existing-feature rewire | yes | `AuthenticationView` form | `AuthenticationStore.mode = .signIn`, `submit()` | preserve behavior |
| `Create Account` secondary action | existing-feature rewire | yes | `AuthenticationView` form | `AuthenticationStore.mode = .signUp` | preserve behavior, switch to sign-up form |

## Scope

In scope:

- Redesign the sign-in form layout using the screenshot as direction.
- Remove the segmented auth mode picker from the form surface.
- Add a local Show/Hide password visibility toggle.
- Keep a secondary `Create Account` action that switches to the existing sign-up flow.
- Keep the existing `Get Started` landing CTA routing to sign-up.

Out of scope:

- Demo login behavior.
- Pre-auth Customer/Groomer role switching.
- Forgot-password/reset flow.
- Supabase Auth, repository, profile role persistence, RoleOnboarding, schema, RLS, Storage, backend, or authenticated navigation changes.

## Implementation Plan

1. Add local password visibility state to `AuthenticationView`.
2. Rebuild `authFormSurface` around a left-aligned header, labeled fields, and full-width primary/secondary actions.
3. Replace the segmented picker with explicit mode-switch buttons: `Sign In` submits, `Create Account` switches to sign-up; sign-up keeps the existing account creation fields and submit behavior.
4. Keep feedback banners and accessibility identifiers intact.
5. Run one standard validation attempt: `./scripts/ios-build.sh`, then `git diff --check`, then launch the app in Simulator and inspect the sign-in page.

## Validation

Default validation:

```sh
./scripts/ios-build.sh
git diff --check
```

Simulator launch:

- Required because this changes visible signed-out app UI.

## Acceptance

- The sign-in page follows the prototype hierarchy while using app-native SwiftUI and existing Groomly tokens.
- The bottom demo module is not implemented.
- The pre-auth Customer/Groomer toggle is not reintroduced.
- Existing sign-in/sign-up auth behavior and submit path remain unchanged.
- The password Show/Hide control is local UI state only.

## Closeout

Status: `completed`

Changed files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationView.swift`
- `docs/06_tasks/T-038_GROOMLY_SIGN_IN_SCREENSHOT_UI.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- `./scripts/ios-build.sh` passed.
- `git diff --check` passed.
- Residual scan confirmed no `Picker("Authentication mode")`, `GroomlyCard`-wrapped auth form, DEMO module, `LandingAudience`, or `auth.audience` code was introduced in `AuthenticationView.swift`.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Entered the sign-in page from `auth.already-have-account`.
- Runtime UI snapshot confirmed `Welcome back`, sign-in subtitle, `Email`, `Password`, `Show`, `Sign In`, and `Create Account`.
- Screenshot captured at `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_204d35be-2b26-438f-94ca-4cf930754e23.jpg`.

Notes:

- The login page now follows the prototype hierarchy while using one app-native Auth form surface.
- The bottom demo module was ignored and not implemented.
- The pre-auth Customer/Groomer toggle was not reintroduced.
- Password Show/Hide is local SwiftUI state only.
- Existing sign-in/sign-up behavior still routes through `AuthenticationStore.mode` and `AuthenticationStore.submit()`.
- No Supabase, Auth repository, profile role persistence, RoleOnboarding, backend, schema, RLS, Storage, or authenticated navigation behavior changed.
