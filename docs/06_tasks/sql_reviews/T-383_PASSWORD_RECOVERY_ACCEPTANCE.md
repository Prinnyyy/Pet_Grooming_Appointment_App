# T-383 Password Recovery Acceptance

Original WP-12/F-07 accepted on 2026-09-09 under D-051. No schema or role change.

## Contract

Recovery uses a separate PKCE Supabase client and secure storage key `beckon.password-recovery.v1`. Only its user can receive the password update; its session never becomes the marketplace session. The exact `/auth/recovery` callback was appended to the hosted allow list; the existing callback, Site URL and SMTP configuration were preserved. Legacy recovery-tagged callbacks cannot enter normal login.

Request/resend copy does not disclose account existence. Invalid, expired and used links offer a new request; interrupted exchange offers retry. Valid recovery can resume from its secure session. Password confirmation/strength failures retain a usable form. A successful password update is not repeated if cleanup needs retry. Full-screen presentation preserves the underlying account or login form; close cleans up recovery first.

## Evidence

- Initial account-isolation RED: `/tmp/beckon-t383-auth-red.log`. Entry-cleanup RED: `/tmp/beckon-t383-entry-red.log`; the error previously existed outside the visible recovery surface. Focused recovery tests cover request/resend, invalid/expired/used/interrupted callback, restored session, another active account, password validation and partial cleanup.
- `/tmp/beckon-t383-delivery-verified.log`: real hosted Swift SDK test passes. Two newly created, tagged disposable accounts were used, not existing user passwords. Supabase generated the recovery email; connected Resend confirmed delivery and the exact PKCE redirect. SDK exchange, recovery-only password update, unchanged normal account, repeated-code rejection and new-password sign-in all passed. Both accounts were signed out, deleted under exact ID/email/run ownership checks, and absence verified (`cleanupVerified: true`, two accounts). No callback tokens, passwords or full recipient identifiers are retained here.
- The bounded opt-in `scripts/test-t383-password-recovery.mjs` bridge requires an authorized `T383_RECOVERY_MAILBOX`, keeps fixtures in memory on loopback, accepts privately supplied delivered-message content, and performs scoped cleanup. It is not an app dependency. Default regression skips its remote test when the bridge is absent; the separate real run above did not skip it.
- `/tmp/beckon-t383-final-regression.log`: 587 Swift tests in 59 suites pass, plus XCTest rendering; default UI four executed/six authorized-fixture skips. The first integration run exposed a test tap during the sign-in slide transition (event x=348 versus settled button x=20...179); the test now waits for a stable hittable frame. Final UI entry/close assertions pass. This is not a relaxed assertion or a retried password mutation.
- `/tmp/beckon-t383-final-images/0317B80C-38B2-406C-A372-0EE2F3CE34CC.png` inspected; the actual reset page fits the device and returns to sign-in. `/tmp/beckon-t383-final-build.log` and `/tmp/beckon-t383-preflight-final.log` pass. Initial preflight caught four semantic typography/color violations; corrected to existing DesignTokens.
- Hosted exact callback verification: `/tmp/beckon-t383-callback-config.log`; current configuration re-read confirmed recovery allowlisting. No migration, RLS, provider, template or dependency change. Existing 82-migration/security evidence is unchanged.

Physical-device email-app handoff, original two-device lifecycle and compatible-build distribution remain WP-14. An expired PKCE verifier or a link opened on another device requires a new request on that device. This does not claim perfect offline behavior or resolve Q-93 paid leaked-password protection.

Strict context checks retain the existing meta-review cadence failure under the user's explicit continuous original-plan execution exception. No review date or functional/security gate was altered; unified closeout is not claimed green.
