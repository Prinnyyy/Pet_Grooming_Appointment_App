# Auth Email and Deep Link Design

Last verified: 2026-07-09. Source tasks: T-193/Q-06 design, T-217/Q-29 local iOS callback implementation, T-242/Q-92 production sender and hosted Auth configuration.

## Current State

- iOS sign-up passes `redirectTo: com.prinnyyy.petgroomermarketplace://auth/callback`.
- `AppInfo.plist` registers that scheme. SwiftUI `.onOpenURL` routes callbacks through `AuthenticationStore`, which handles error fragments before Supabase session exchange.
- Supabase Site URL and the exact redirect allow-list entry both use `com.prinnyyy.petgroomermarketplace://auth/callback`; the old localhost Site URL is removed.
- Supabase Custom SMTP is enabled through Resend at `smtp.resend.com:465` with sender `Groomly <no-reply@hellobeckon.com>`.
- Resend has verified `hellobeckon.com`; Cloudflare hosts its DKIM, return-path/SPF, and monitoring-only DMARC record (`p=none`). Existing iCloud MX and SPF records remain intact.
- A direct Resend delivery smoke to `fengyuan@hellobeckon.com` was accepted on 2026-07-09. A Supabase-generated Auth email remains a release-device smoke requirement.
- No Associated Domains entitlement or tracked local Auth configuration exists; hosted Supabase settings are authoritative.
- Supabase leaked-password protection remains unavailable on the organization Free Plan; enabling it requires a Pro-or-higher plan decision and fresh authorization.

## Provider

Resend is the production SMTP provider. Credentials stay only in ignored, mode-`600` local files and must never enter tracked Markdown, shell history, build settings, logs, or TestOps artifacts. Add a dedicated support mailbox or alias before release if support should not use `fengyuan@hellobeckon.com`.

## Redirect URLs

The implemented hosted callback is:

- Site URL: `com.prinnyyy.petgroomermarketplace://auth/callback`
- Additional Redirect URLs: `com.prinnyyy.petgroomermarketplace://auth/callback`

The scheme works only with the app installed. A later HTTPS Universal Link migration requires a callback host, Apple Team ID, `apple-app-site-association`, Associated Domains entitlement, and device validation. Then use exact production/staging HTTPS callback entries while retaining the scheme for development; never use production wildcards.

## Templates

Templates must cover signup confirmation, password reset, magic link/OTP, invite, and email change. Keep password/email/identity security notices enabled.

Use `{{ .ConfirmationURL }}` unless a task adds a custom token-hash endpoint. Manually constructed links must use `{{ .RedirectTo }}` when `redirectTo` is passed. Disable provider link tracking so Auth links are not rewritten.

## iOS Behavior

- Confirmation, recovery, and future OTP/magic-link flows must use the selected callback.
- Route valid URLs through Supabase Auth session exchange and show a scoped error for `error` or `error_code` fragments.
- Never log full callback URLs because they can contain tokens or session fragments.

## Validation Gate for Q-07

- Keep only approved exact URLs in the Auth allow list.
- Before release, send a Supabase-generated confirmation or recovery email to a non-team address and inspect sender, delivery, and device callback behavior.
- App callback handling has unit coverage for success, remote error fragment, and malformed URL.
- Run targeted Auth tests, iOS build, `git diff --check`, and a device callback smoke.

## Credential and DNS Operations

- Local credential sources are `CloudFlare API.md` and `Resend API.md`; both are ignored and mode `600`.
- The current Cloudflare API token verifies as active but cannot enumerate the `hellobeckon.com` zone. Future CLI/API automation needs a replacement token scoped to this zone with `Zone:Read` and `DNS:Edit`; dashboard access was used for T-242.
- Do not replace the root SPF record with Resend SPF. iCloud owns the root sender policy, while Resend uses its verified `send` subdomain and DKIM record.
- Keep DMARC at `p=none` while monitoring initial traffic. Moving to `quarantine` or `reject` is a separate deliverability decision based on aggregate reports.

Official references: [Supabase Auth SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls), [Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates), [Native Mobile Deep Linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking), [Swift signUp redirectTo](https://supabase.com/docs/reference/swift/auth-signup), and Apple Universal Links/custom URL scheme documentation.
