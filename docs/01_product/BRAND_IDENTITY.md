# Beckon Brand Identity

Last verified: 2026-07-13.

This is the active identity contract. Migration sequencing and retired-name evidence belong in frozen history.

## Canonical Identity

| Surface | Value |
|---|---|
| Brand | `Beckon` |
| Domain | `hellobeckon.com` |
| App Store name | `Beckon: Pet Grooming` |
| Tagline | `Pet groomers at your beck and call.` |
| Xcode project, app target, module | `Beckon` |
| Test targets | `BeckonTests`, `BeckonUITests` |
| iOS root | `ios/Beckon/` |
| Bundle ID and URL scheme | `com.hellobeckon.beckon` |
| Auth callback | `com.hellobeckon.beckon://auth/callback` |

## Active-Tree Rules

- Product UI, release metadata, Swift symbols, filenames, DesignSystem primitives, diagnostics, caches, launch arguments, accessibility identifiers, scripts, tests, TestOps, seed resources, and active documentation use the canonical identity.
- Authentication surfaces use the canonical App Store name and exact tagline.
- Test users use `beckon.customer001@example.com` through `050` and `beckon.groomer001@example.com` through `050`; support IDs use `BTC-###` and `BTG-###`.
- iOS client configuration contains only publishable project configuration. Server credentials never enter the application bundle.
- A new identity change requires an explicit product decision and separate local, workflow, and remote execution scopes.

## Historical Boundary

Applied migrations, frozen records, and Git history are immutable. Retired identity strings may remain only in those paths or in explicitly audited rollback/test fixtures that must recognize historical state. Active exceptions are owned by `scripts/beckon-identity-check.mjs`; do not add exclusions merely to make the audit pass.

Changing the Bundle ID creates a new app identity and local container. Existing sessions and caches are not migrated implicitly.

## Validation

- Run `node scripts/beckon-identity-check.mjs` after identity-adjacent changes.
- Run `node --test tests/brand/beckon-identity-check.test.mjs` when the checker or its exclusions change.
- Runtime identity acceptance verifies the app name and exact tagline without loading frozen history.
