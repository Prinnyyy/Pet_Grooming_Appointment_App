# T-005 — iOS Supabase Client and Session Boundary

## Status

Completed on 2026-06-20.

## Primary Task

Add the pinned Supabase Swift package, build-time non-secret environment configuration, client composition, and an injectable Auth session repository boundary.

## Dependency Exception

T-004 remains paused with a reviewed but unapplied migration. The user explicitly started T-005 on 2026-06-20. T-005 must not query profile tables or imply that the T-004 backend exists.

## In Scope

- Pin `supabase-swift` exactly to `2.46.0` and link the `Supabase` product to the app target.
- Load the authorized project URL and modern publishable key through an ignored local xcconfig.
- Keep a tracked empty xcconfig fallback so clean checkouts still build and show a visible configuration error.
- Compose `SupabaseClient` outside SwiftUI views.
- Add a token-free session snapshot, repository protocol, and Supabase Auth adapter.
- Keep production at the authentication bootstrap without sign-in or fake session success.

## Out of Scope

- T-004 migration application or any other remote Supabase write.
- Sign-up, sign-in, sign-out, session routing, or role onboarding.
- Profile, pet, request, offer, booking, Storage, or product data access.
- Service-role/secret keys, commit, or push.

## Validation

- `./scripts/ios-build.sh`: passed with `** BUILD SUCCEEDED **` after the user resumed an earlier manually interrupted build. A post-build check found that Xcode's generated Info.plist omitted custom keys; one targeted `AppInfo.plist` correction and rebuild also passed.
- Supabase `2.46.0` and its transitive packages resolved into the checked-in `Package.resolved`.
- Static review found no secret/service-role key or hard-coded actual API key in tracked files.
- Unit and UI tests were intentionally not run.

## Stop Condition

Stop after one successful app build and memory update, or after reporting the first real build error. Do not implement T-006 or resume T-004 automatically.
