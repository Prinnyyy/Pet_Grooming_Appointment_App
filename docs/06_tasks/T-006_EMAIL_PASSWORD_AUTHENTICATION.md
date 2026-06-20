# T-006 — Email and Password Authentication

## Status

Completed on 2026-06-20.

## Primary Task

Implement real Supabase email/password sign-up, sign-in, current-device sign-out, session restoration, and visible authentication states without creating profiles or selecting roles.

## Approved Design

- `docs/superpowers/specs/2026-06-20-t006-email-password-auth-design.md`
- Default Supabase email confirmation remains enabled.
- Confirmation returns the user to Sign In manually; automatic Auth deep links are out of scope.
- One root-level `AuthenticationStore` owns Auth UI state behind `AuthSessionRepository`.

## In Scope

- Token-free Auth repository inputs/results and safe domain errors.
- Supabase Swift sign-up, sign-in, local-scope sign-out, cached session, and Auth event adapter.
- Sign In/Create Account form with local validation and duplicate-submit protection.
- Confirmation-required notice, visible errors, loading state, and onboarding-required signed-in state.
- Focused store tests and updated launch smoke test.

## Out of Scope

- Profile queries or writes, role selection, Customer/Groomer routing, password reset, OTP, OAuth, MFA, migrations, remote configuration changes, real test accounts, commit, or push.

## Validation Results

1. The only Xcode attempt, `./scripts/ios-test.sh`, passed with `** TEST SUCCEEDED **`.
2. Ten Swift Testing tests passed: four existing entry/tab tests and six focused `AuthenticationStore` tests.
3. The XCTest launch smoke test passed and found the real authentication form without exposing Customer or Groomer tabs.
4. No real Auth account, migration, remote configuration change, profile query/write, commit, or push was performed during implementation.

## Stop Condition

Fulfilled. T-007 remains a separate task and was not started.
