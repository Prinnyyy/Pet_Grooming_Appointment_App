# iOS Build and Testing

## Defaults

- Project: `ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj`
- Shared scheme: `PetGroomerMarketplace`
- Destination: `platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro`
- Minimum deployment target: iOS 18.0
- Swift language mode: Swift 6

The scripts address the project directly. They do not discover or prefer the internal `project.xcworkspace` inside the `.xcodeproj` bundle.

## Build

Run:

```bash
./scripts/ios-build.sh
```

## Test

Run both the Swift Testing unit target and XCTest UI target:

```bash
./scripts/ios-test.sh
```

## Environment Overrides

All defaults can be overridden explicitly:

```bash
CODEX_IOS_PROJECT=/path/to/App.xcodeproj \
CODEX_IOS_SCHEME=App \
CODEX_IOS_DESTINATION='platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' \
./scripts/ios-build.sh
```

The same variables are supported by `./scripts/ios-test.sh`.

## Supabase Environment

The tracked `ios/PetGroomerMarketplace/Config/Supabase.xcconfig` contains empty defaults and optionally includes `Supabase.local.xcconfig`. The local file is Git-ignored and populated from the authorized Supabase project. The tracked `AppInfo.plist` expands these build settings into the runtime bundle.

Required local values:

```text
SUPABASE_URL = https:/$()/your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_...
```

Do not use a secret or service-role key. If the local file is absent or invalid, the app still builds and the authentication bootstrap displays a configuration error.

## Rules

- Keep the shared scheme checked into `xcshareddata/xcschemes`.
- Use the scripts for repository build and test checks.
- If a task needs a different simulator or project, use an environment override instead of changing the safe defaults.
- Stop after two focused repair attempts for task-related build failures.
