# T-039 Groomly Sign-In Two-Field Spacing

Task ID: `T-039`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Make a light layout correction to the sign-in page. With two input fields on the existing-account page, the input module should not feel vertically centered with too much empty space above and below. Keep the input module top spacing consistent with the three-field create-account state. Do not perform screenshot validation.

## Primary Task

Adjust only the signed-out `AuthenticationView` form spacing for the two-field sign-in state.

## Scope

In scope:

- Preserve the current top anchor from title/subtitle to the input fields.
- Tighten only the spacing between the two-field sign-in input group and the action buttons.
- Leave the three-field create-account spacing unchanged.

Out of scope:

- Screenshot validation.
- Auth logic, Supabase, repositories, RoleOnboarding, backend, schema, RLS, Storage, navigation, or product-flow changes.

## Implementation Plan

1. Add a small computed spacing value for fields-to-actions spacing.
2. Use tighter spacing only when `AuthenticationStore.mode == .signIn`.
3. Run basic validation without screenshot verification.

## Validation

Default validation:

```sh
./scripts/ios-build.sh
git diff --check
```

Simulator launch:

- Launch app for inspection only.
- Do not capture a screenshot for validation.

## Closeout

Status: `completed`

Changed files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationView.swift`
- `docs/06_tasks/T-039_GROOMLY_SIGN_IN_TWO_FIELD_SPACING.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- `./scripts/ios-build.sh` passed.
- `git diff --check` passed.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Entered the sign-in page from `auth.already-have-account`.
- Runtime UI snapshot confirmed the sign-in form was reachable.
- Screenshot validation was skipped per user request.

Notes:

- The header-to-fields spacing remains unchanged.
- The fields-to-actions spacing is tightened only for the two-field sign-in state.
- The three-field create-account state keeps the previous fields-to-actions spacing.
- No Auth, Supabase, repository, profile role persistence, RoleOnboarding, backend, schema, RLS, Storage, navigation, or product-flow behavior changed.
