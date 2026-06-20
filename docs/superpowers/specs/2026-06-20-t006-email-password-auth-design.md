# T-006 Email and Password Authentication Design

## Status

Approved in conversation on 2026-06-20; awaiting final written-spec review before implementation.

## Goal

Implement real Supabase email/password sign-up, sign-in, sign-out, and session restoration in the iOS app. Authentication state must drive the root UI without creating profiles or selecting a marketplace role.

## Scope

In scope:

- Email/password account creation.
- Supabase's default email-confirmation flow.
- Email/password sign-in.
- Current-device sign-out.
- Cached-session restoration and ongoing Auth event observation.
- Loading, validation, submission, confirmation-required, and safe error states.
- An explicit authenticated-but-onboarding-required destination with sign-out.
- Focused state tests and the existing launch UI smoke test.

Out of scope:

- Role selection or profile/role-profile creation.
- Queries against `profiles`, `customer_profiles`, or `groomer_profiles`.
- Customer or Groomer tab routing.
- Password reset, magic link, OTP, OAuth, passkeys, MFA, or account deletion.
- Custom Auth email templates or automatic confirmation deep-link handling.
- Runtime fixtures, demo credentials, service-role keys, or fake success.
- Any migration or remote Supabase configuration change.

## Architecture

Use one root-level `AuthenticationStore`, isolated to the main actor, as the source of truth for authentication UI state. SwiftUI views remain thin and call Store operations. The Store depends only on `AuthSessionRepository`; the Supabase adapter is the only type that calls `SupabaseClient.auth`.

Extend the repository boundary with:

- current session lookup;
- async session-state stream;
- email/password sign-up returning either a real session or confirmation-required outcome;
- email/password sign-in returning a session snapshot;
- current-device sign-out.

The token-free session snapshot may expose the authenticated user ID and normalized email needed by the onboarding-required UI. It must never expose access or refresh tokens.

## Root State

The Store owns one explicit root state:

- `loading` while bootstrap begins;
- `signedOut` when no valid session exists;
- `signedIn(AuthSessionSnapshot)` when Supabase supplies a real session;
- configuration failure remains owned by the existing composition/bootstrap boundary.

At launch, the Store reads the repository's current cached session and then observes Auth state changes. Stream events remain authoritative after bootstrap. A signed-in state always renders the onboarding-required destination in T-006; profile lookup and role routing belong to T-007.

## Authentication UI

The signed-out view provides Sign In and Create Account modes in one navigation surface.

Sign In fields:

- email;
- password.

Create Account fields:

- email;
- password;
- password confirmation.

Form requirements:

- trim surrounding email whitespace and normalize email casing before repository calls;
- require a plausibly formatted email;
- require at least eight password characters locally; stronger server configuration remains authoritative and its rejection is shown safely;
- require matching confirmation for account creation;
- preserve email and recoverable form state after failure;
- disable only the active submission while it is in flight;
- never log or display passwords.

Successful sign-up has two valid outcomes:

1. If Supabase returns no session because email confirmation is required, remain signed out, clear password fields, retain the email, and display a check-email notice.
2. If Supabase returns a real session, allow the authoritative session event/result to enter the onboarding-required destination.

No custom redirect URL is supplied in T-006. After confirming in the browser, the user returns to the app and signs in normally.

## Error Handling

Map infrastructure errors to short user-safe Auth messages. Invalid credentials and unconfirmed email should be actionable; rate limiting/network failure should suggest retrying; unknown errors should use a general message. Raw access tokens, refresh tokens, passwords, full backend payloads, and secret configuration must never enter UI state or logs.

Submission failure preserves form input and returns the form to an enabled state. Duplicate taps are ignored while submitting. A session-stream sign-out or expiry returns the root to the signed-out view.

## Validation

Add focused tests using a fake `AuthSessionRepository` for:

- restored session enters signed-in/onboarding-required state;
- absent session enters signed-out state;
- confirmation-required sign-up remains signed out and presents a notice;
- sign-in failure remains recoverable and visible;
- sign-out returns to signed-out state;
- duplicate submission protection and local validation where practical.

Update the existing UI smoke test so normal launch locates the authentication form and does not expose Customer or Groomer tabs.

Use one Xcode validation attempt: `./scripts/ios-test.sh`, which compiles the app and runs the focused unit/UI smoke tests. Do not create a real remote test account because the confirmed email flow requires an inbox and would leave remote Auth data. Afterward run lightweight diff/static checks only.

## Stop Condition

Stop when real Auth operations, session restoration, safe states, focused tests, and durable memory are complete. Do not implement T-007 role onboarding or profile routing.
