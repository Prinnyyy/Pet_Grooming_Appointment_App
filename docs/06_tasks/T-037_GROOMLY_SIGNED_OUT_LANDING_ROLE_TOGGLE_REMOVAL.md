# T-037 Groomly Signed-Out Landing Role Toggle Removal

Task ID: `T-037`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Remove the Customer/Groomer toggle from the signed-out new-user home screen because it was an incorrect feature. Remove the derivative pages/states caused by that button. Make the floating bubble animation more noticeable, and re-layout the dog logo module, title text, and buttons with stronger visual balance.

## Primary Task

Rework only the signed-out `AuthenticationView` landing surface and its immediate entry into the existing sign-up/sign-in form.

Target screen and role:

- Screen: `AuthenticationView` signed-out landing
- Role: `Shared`

## Screenshot / Existing UI Analysis

| Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Top Customer/Groomer toggle inside the app | incorrect visual/function state | local-only state | `AuthenticationView` | none | remove completely |
| Customer/Groomer derivative landing variants | incorrect derivative local state | local-only state | `AuthenticationView` | none | remove completely |
| Existing sign-up/sign-in form entry | existing-feature rewire | yes | `AuthenticationView` | `AuthenticationStore.mode`, `AuthenticationStore.submit()` | preserve |
| Dog logo circular hero | visual-only | yes | `AuthenticationView` | none | keep, improve spacing |
| Floating bubbles | visual-only | yes | `AuthenticationView` | none | increase motion and visibility |
| Landing title/subtitle/buttons | visual-only + existing actions | yes | `AuthenticationView` | sign-up/sign-in actions only | re-layout |

## Scope

In scope:

- Remove the pre-auth Customer/Groomer selector and all `LandingAudience`-driven local UI branches.
- Keep a single dog/Groomly landing treatment for all signed-out users.
- Preserve existing `Get Started` -> sign-up form and `I already have an account` -> sign-in form behavior.
- Make bubble motion more visible while still respecting Reduce Motion.
- Rebalance logo/title/copy/button vertical spacing.

Out of scope:

- Supabase Auth, profile role persistence, role onboarding, repositories, schema, RLS, Storage, backend, or navigation changes.
- New role selection behavior before authentication.
- Authenticated app tab changes.

## Implementation Plan

1. Remove `LandingAudience`, `selectedAudience`, the audience selector view, and helper functions.
2. Replace audience-driven color/icon/copy/button styling with one fixed Groomly dog landing identity.
3. Rebuild the landing vertical rhythm so the hero/title group sits in the upper-middle and the CTA group sits in the lower third.
4. Increase floating bubble travel, opacity, and varied drift.
5. Run one standard validation attempt: `./scripts/ios-build.sh`, then `git diff --check`, then launch the app in Simulator.

## Validation

Default validation:

```sh
./scripts/ios-build.sh
git diff --check
```

Simulator launch:

- Required because this changes visible signed-out app UI.

## Acceptance

- No Customer/Groomer toggle is visible on the signed-out landing.
- No Customer/Groomer derivative landing/form state remains in `AuthenticationView`.
- Existing sign-up/sign-in form behavior and auth submission path are unchanged.
- Bubble motion is visibly more active unless Reduce Motion is enabled.
- Logo, title, subtitle, and buttons have a cleaner vertical hierarchy.

## Closeout

Status: `completed`

Changed files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationView.swift`
- `docs/06_tasks/T-037_GROOMLY_SIGNED_OUT_LANDING_ROLE_TOGGLE_REMOVAL.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- `./scripts/ios-build.sh` passed.
- `git diff --check` passed.
- Residual scan passed for removed app code symbols: no `LandingAudience`, `selectedAudience`, `audienceSelector`, or `auth.audience` references remain in `AuthenticationView.swift`.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- `auth.landing` was visible in the runtime UI snapshot.
- Screenshot captured at `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_b60a48e6-2c72-4917-8b1c-a9e74198032b.jpg`.

Notes:

- The signed-out landing now has one shared dog/Groomly entry treatment.
- The incorrect pre-auth Customer/Groomer toggle and its `LandingAudience`-driven derivative landing/form variants were removed, not hidden.
- `Get Started` still routes to the existing sign-up form, and `I already have an account` still routes to the existing sign-in form through `AuthenticationStore.mode`.
- No Supabase, Auth repository, profile role persistence, RoleOnboarding, backend, schema, RLS, Storage, or authenticated navigation behavior changed.
