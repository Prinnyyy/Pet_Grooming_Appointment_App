# Debug Console and Structured Events

This is the first reference when diagnosing local app bugs, unexpected feedback prompts, load failures, or tab-switch timing issues.

## Scope

- Available only in DEBUG builds.
- Release builds use no-op debug recorder paths and do not show the Debug Console entry.
- The Debug Console extends the existing unified feedback system; it does not create a second toast or error-prompt system.
- No Supabase schema, RLS, RPC, Storage, auth, or production routing behavior depends on debug events.

## Where to Open It

In a DEBUG simulator build:

```text
Account -> Debug Console
```

The console shows runtime/Supabase context, current feedback, recent events, errors only, TestOps state, copy/export, and clear-log tools.

## Local Log File

DEBUG builds write JSONL events to the app data container:

```text
Application Support/BeckonDebug/debug-events.jsonl
```

Use the helper script:

```bash
./scripts/ios-debug-events.sh tail 100
./scripts/ios-debug-events.sh cat
./scripts/ios-debug-events.sh path
```

Release and DEBUG builds also write local-only operational evidence:

```text
Application Support/BeckonOperational/operational-events.jsonl
```

`AppOperationalEvent` rows capture sanitized launch, foreground/background, auth, role, profile-load failure, and suspected prior-run interruption evidence. They are not a feedback system and do not upload data. DEBUG builds mirror them into Recent Events.

## Event Shape

Each JSONL row is an `AppDebugEvent`:

```text
timestamp
level: debug/info/warning/error
category: feedback/store/repository/navigation/action/lifecycle/test
source
scope
message
underlyingErrorType
underlyingErrorCode
correlationID
durationMs
metadata
```

Use `source` for the precise code path, for example `CustomerRequestsStore.load`. Use `scope` for the surface, for example `customer.bookings`.

TestOps launch arguments add `category=test` events with `automationRunID`, `scenarioID`, `phase`, and `actorRole` metadata. Full TestOps usage lives in `docs/04_ios/testops/README.md`.

## Safety Rules

Events must stay support-safe:

- Do not record tokens, passwords, headers, raw request/response bodies, service-role keys, or signed URLs.
- Do not record full email addresses; record only email domain.
- Do not record full UUIDs; use 8-character support refs.
- Storage paths must be reduced to bucket plus safe object context.
- Repository wrappers may record table/RPC and operation names, but not full Supabase payloads.

The sanitizer lives in:

```text
ios/Beckon/Beckon/Core/Diagnostics/AppDebugEvent.swift
```

Operational event recording lives in:

```text
ios/Beckon/Beckon/Core/Diagnostics/AppOperationalEvent.swift
```

## How to Read a Local Repro

1. Reproduce the bug in the simulator.
2. Run:

   ```bash
   ./scripts/ios-debug-events.sh tail 200
   ```

3. Look for the relevant `scope`, `source`, and `message`.
4. For toasts, inspect `category=feedback`; for load failures, inspect Store then repository events.
6. Treat `message=cancelled` as cancellation unless a separate error event follows.

## Instrumentation Rules

When adding new async Store or repository work:

- Record Store `start`, `success`, `failure`, and `cancelled` events around user-visible loads and mutations.
- Record safe success counts such as `bookingCount`, `requestCount`, `petCount`, or `messageCount`.
- Use `.info` for normal success and cancellation, `.warning` only for recoverable degraded behavior, and `.error` for real failures.
- Handle `CancellationError`, `URLError.cancelled`, and `NSURLErrorDomain -999` as cancellation. Do not set Store `errorMessage` for cancellation.
- Keep repository diagnostics behind debug wrappers when possible; live Supabase repositories should remain production behavior owners.
- Route user-facing prompts through the unified `BeckonFeedbackCenter`; debug events should explain prompt provenance, not replace prompt routing.
- Use `AppOperationalEventRecorder` only for release-evidence lifecycle/funnel states. It must remain local-only and support-safe; do not turn it into network analytics.

## Validation

For debug event changes, run focused tests when possible and at minimum:

```bash
./scripts/ios-test.sh
./scripts/ios-build.sh
git diff --check
```

For UI-facing Debug Console changes, verify:

- Account shows `Debug Console` only in DEBUG.
- Recent Events renders at least one structured event after app load or tab navigation.
- `./scripts/ios-debug-events.sh tail 20` reads the same booted app container log.
