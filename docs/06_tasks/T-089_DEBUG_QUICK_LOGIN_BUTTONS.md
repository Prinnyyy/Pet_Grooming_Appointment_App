# T-089 Debug Quick Login Buttons

Mode: Standard

Date: 2026-06-26

## User Request

Add customer and groomer quick-login buttons on the login page for debug use, using the two user-approved test accounts.

## Primary Task

Provide a fast DEBUG-only login path for the customer and groomer test accounts without changing production authentication behavior.

## Scope

Included:

- Add DEBUG-only quick-login account definitions.
- Add an `AuthenticationStore` helper that signs in with a selected debug account.
- Render customer and groomer quick-login buttons on the signed-out landing and sign-in surfaces.
- Add focused tests for the debug account definitions and Store sign-in behavior.

Out of scope:

- Release-build quick login.
- Backend/auth schema changes.
- Additional debug account management UI.

## Implementation Notes

- The quick-login account definitions and buttons are wrapped in `#if DEBUG`.
- The view only renders buttons and delegates sign-in to `AuthenticationStore`.
- The Store switches to sign-in mode, applies the selected debug account credentials, and reuses the existing `submit()` path.

## Validation

- Red check failed first because the debug quick-login account type and Store API did not exist:
  - `xcodebuild -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' -only-testing:PetGroomerMarketplaceTests/AuthenticationStoreTests/debugQuickLoginAccountsUseApprovedCredentials -only-testing:PetGroomerMarketplaceTests/AuthenticationStoreTests/debugQuickLoginSignsInWithEmbeddedAccount test`
- Green check passed for the same targeted tests after implementation.
- Final targeted test passed for the same two AuthenticationStore debug quick-login tests.
- `./scripts/ios-build.sh` passed.
- `git diff --check` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17 Pro` simulator (`45D452E8-DC6C-4CD4-A747-4D21671E68A6`) with no diagnostics errors.
- Simulator UI verification signed out from an existing groomer session, confirmed the login landing page exposes `auth.debug-login.customer` and `auth.debug-login.groomer`, then tapped Customer Quick Login and reached the customer Home screen.
- Credential scan found the approved debug credentials only in the DEBUG implementation and focused auth tests, not in task or memory docs.

## Closeout

Status: completed

Changed files:

- `docs/06_tasks/T-089_DEBUG_QUICK_LOGIN_BUTTONS.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/AppEntryModelsTests.swift`

Risks:

- This intentionally embeds the approved debug test account credentials in DEBUG builds. Keep the quick-login definitions and UI under `#if DEBUG`.
- During simulator verification, Customer Quick Login reached customer Home but the app still displayed a request-loading toast. That request-loading behavior is outside T-089 and should be handled as a separate follow-up if it persists.
