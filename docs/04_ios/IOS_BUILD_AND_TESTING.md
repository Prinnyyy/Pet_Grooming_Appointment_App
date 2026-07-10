# iOS Build and Testing

## Defaults

- Project: `ios/Beckon/Beckon.xcodeproj`
- Shared scheme: `Beckon`
- Build destination: `generic/platform=iOS Simulator`
- Test destination: auto-discovered concrete iPhone simulator from the current Xcode installation
- Minimum deployment target: iOS 18.0
- Swift language mode: Swift 6

The scripts address the project directly. They do not discover or prefer the internal `project.xcworkspace` inside the `.xcodeproj` bundle.
CI jobs that require a fixed simulator image should set `CODEX_IOS_DESTINATION` explicitly.

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

Repository static backend tests are part of preflight, not the iOS test script:

```bash
./scripts/preflight.sh
```

Preflight runs `tests/migrations/*.test.mjs` and `tests/functions/*.test.mjs` when present. These tests are local/static only; they do not replace authorized Supabase remote validation for Deep backend tasks.

## TestOps

Unified lifecycle automation and run templates live under `docs/04_ios/testops/README.md`.

Useful entrypoints:

```bash
./scripts/testops-unit.sh
node scripts/testops.mjs doctor --dry-run
node scripts/testops.mjs run backend --scenario marketplace_full_lifecycle
node scripts/testops.mjs run backend --scenario marketplace_full_lifecycle --matrix smoke5
node scripts/testops.mjs run matching --scenario request_matching_eval --matrix matching_baseline
./scripts/ios-testops-e2e.sh marketplace_full_lifecycle
```

Remote backend execution and cleanup require explicit operator approval, `--execute`, and `TESTOPS_REMOTE_WRITE_APPROVED=1`.

## Debug Event Logs

For local app repros, DEBUG builds expose `Account -> Debug Console` and write structured JSONL events to the booted simulator app container. Use:

```bash
./scripts/ios-debug-events.sh tail 100
./scripts/ios-debug-events.sh path
```

The full usage and instrumentation rules live in `docs/04_ios/DEBUG_CONSOLE.md`.

## Environment Overrides

All defaults can be overridden explicitly:

```bash
CODEX_IOS_PROJECT=/path/to/App.xcodeproj \
CODEX_IOS_SCHEME=App \
CODEX_IOS_DESTINATION='platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro' \
./scripts/ios-build.sh
```

The same variables are supported by `./scripts/ios-test.sh`.

## Supabase Environment

The tracked `ios/Beckon/Config/Supabase.xcconfig` contains empty defaults and optionally includes `Supabase.local.xcconfig`. The local file is Git-ignored and populated from the authorized Supabase project. The tracked `AppInfo.plist` expands these build settings into the runtime bundle.

Required local values:

```text
SUPABASE_URL = https:/$()/your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_...
```

Do not use a secret or service-role key. If the local file is absent or invalid, the app still builds and the authentication bootstrap displays a configuration error.

## Rules

- Keep the shared scheme checked into `xcshareddata/xcschemes`.
- Use the scripts for repository build and test checks.
- Add or update local Node tests for new migrations and Edge Function helpers before remote validation.
- If a task needs a different simulator or project, use an environment override instead of changing the safe defaults.
- Stop after two focused repair attempts for task-related build failures.
