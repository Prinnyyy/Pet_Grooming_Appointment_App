# Auth Email and Deep Link Design

Last verified: 2026-07-09. Source task: T-193/Q-06. This is a design contract only; no Supabase dashboard setting, Management API patch, DNS record, iOS entitlement, or remote write has been applied.

## Current State

- iOS sign-up uses `SupabaseAuthSessionRepository.signUp(email:password:)` without `redirectTo`.
- `AppInfo.plist` has Supabase URL/key entries but no `CFBundleURLTypes`.
- No associated-domains entitlement exists.
- Hosted Supabase Auth settings are the production configuration surface; this repo has no tracked local Auth config file.

## Provider

Use Resend as the default production SMTP provider for Supabase Auth because it supports standard SMTP, low setup overhead, and domain-based sender identity. Fallback providers are Postmark or AWS SES only if Resend domain verification, compliance, or deliverability blocks launch.

Required external inputs before Q-07 implementation:

- Verified sending domain owned by the app operator.
- From address: `no-reply@<verified-domain>`.
- Reply-to/support mailbox: `support@<verified-domain>`.
- SMTP host, port, username, and password.
- Optional Supabase Management API access token if applying Auth config by API instead of dashboard.

## Redirect URLs

Production should prefer HTTPS universal links so links remain meaningful when the app is not installed. Custom URL scheme is allowed only as a development/test fallback until the production domain and Apple associated-domain file exist.

Configure Supabase Auth URL settings as:

- Site URL: `https://<production-auth-domain>/auth/callback`.
- Additional Redirect URLs:
  - `https://<production-auth-domain>/auth/callback`
  - `https://<staging-auth-domain>/auth/callback`
  - `com.prinnyyy.petgroomermarketplace://auth/callback`

Do not use production wildcards. Wildcards are allowed only for explicitly named preview/staging environments.

## Templates

Authentication templates must cover confirm signup, reset password, magic link/OTP, invite, and email change. Security notification templates should stay enabled for password changed, email changed, and identity linked/removed notices.

Use `{{ .ConfirmationURL }}` for the first implementation unless Q-07 explicitly adds a custom token-hash verification endpoint. If a template manually constructs a token-hash link, it must use `{{ .RedirectTo }}` rather than `{{ .SiteURL }}` when `redirectTo` is passed. Disable email tracking in the SMTP provider so Auth links are not rewritten.

## iOS Behavior for Q-07

- Add `CFBundleURLTypes` for `com.prinnyyy.petgroomermarketplace`.
- After a production domain is chosen, add Associated Domains entitlement for `applinks:<production-auth-domain>`.
- Pass the selected redirect URL to sign-up, resend confirmation, password recovery, and future OTP/magic-link flows.
- Handle incoming URLs with SwiftUI `.onOpenURL`; route valid Auth callbacks through the Supabase Auth session exchange path and show a scoped auth error for `error` or `error_code` fragments.
- Never log full callback URLs because they can contain tokens or session fragments.

## Validation Gate for Q-07

- Supabase Auth URL allow list contains only the approved exact production/staging URLs plus the dev scheme.
- SMTP sends a confirmation email to a non-team test address.
- Email links open the installed app on iOS and fall back to the HTTPS page when not installed.
- App callback handling has unit coverage for success, expired token, denied redirect, and malformed URL.
- `git diff --check`, targeted auth tests, iOS build, and a manual simulator/device callback smoke pass.

Official references: [Supabase Auth SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls), [Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates), [Native Mobile Deep Linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking), [Swift signUp redirectTo](https://supabase.com/docs/reference/swift/auth-signup), and Apple Universal Links/custom URL scheme documentation.
