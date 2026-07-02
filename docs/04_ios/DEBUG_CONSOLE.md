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

The console shows:

- Runtime: build configuration, bundle ID, role, support user ref, email domain.
- Supabase: URL scheme, host, publishable-key configured/missing status.
- Current Feedback: active prompt and queued prompt count from the global feedback center.
- Recent Events: latest structured events across feedback, Store, repository, navigation, action, and lifecycle categories.
- Errors Only: error-level events and cancellation events.
- TestOps: active run ref, scenario, phase, actor role, and latest `category=test` event when the app launched with TestOps arguments.
- Tools: copy the last 5 minutes of JSONL events or clear local debug logs.

## Local Log File

DEBUG builds write JSONL events to the app data container:

```text
Application Support/GroomlyDebug/debug-events.jsonl
```

Use the helper script instead of manually locating the simulator container:

```bash
./scripts/ios-debug-events.sh tail 100
./scripts/ios-debug-events.sh cat
./scripts/ios-debug-events.sh path
```

The script targets the booted simulator and `com.prinnyyy.PetGroomerMarketplace`.

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

Use `source` for the precise code path, for example `CustomerRequestsStore.load` or `GroomlyFeedbackCenter.enqueue`. Use `scope` for the user-facing surface, for example `customer.home`, `customer.requests`, `customer.bookings`, `groomer.profile`, or `messages.thread`.

TestOps launch arguments add `category=test` events with `automationRunID`, `scenarioID`, `phase`, and `actorRole` metadata. Full TestOps usage lives in `docs/04_ios/testops/README.md`.

## Safety Rules

Debug events must stay support-safe:

- Do not record tokens, passwords, authorization headers, raw request/response bodies, service-role keys, or signed URLs.
- Do not record full email addresses; record only email domain.
- Do not record full UUIDs; use 8-character support refs.
- Storage paths must be reduced to bucket plus safe object context.
- Repository wrappers may record table/RPC names and operation names, but not headers, bodies, bearer tokens, or full Supabase payloads.

The sanitizer lives in:

```text
ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Diagnostics/AppDebugEvent.swift
```

## How to Read a Local Repro

1. Reproduce the bug in the simulator.
2. Run:

   ```bash
   ./scripts/ios-debug-events.sh tail 200
   ```

3. Look for the relevant `scope`, `source`, and `message`.
4. If a toast appeared, inspect `category=feedback` events for enqueue, presented, dismissed, suppressed duplicate/stale, and cleared-by-scope events.
5. If a load failed, inspect the Store event first, then the repository event with the same operation or nearby timestamp.
6. Treat `message=cancelled` as cancellation unless a separate error event follows.

## Instrumentation Rules

When adding new async Store or repository work:

- Record Store `start`, `success`, `failure`, and `cancelled` events around user-visible loads and mutations.
- Record safe success counts, such as `bookingCount`, `requestCount`, `petCount`, or `messageCount`.
- Use `.info` for normal success and cancellation, `.warning` only for recoverable degraded behavior, and `.error` for real failures.
- Handle `CancellationError`, `URLError.cancelled`, and `NSURLErrorDomain -999` as cancellation. Do not set Store `errorMessage` for cancellation.
- Keep repository diagnostics behind debug wrappers when possible; live Supabase repositories should remain production behavior owners.
- Route user-facing prompts through the unified `GroomlyFeedbackCenter`; debug events should explain prompt provenance, not replace prompt routing.

## Validation

For debug event changes, run the focused tests when possible and at minimum run:

```bash
./scripts/ios-test.sh
./scripts/ios-build.sh
git diff --check
```

For UI-facing Debug Console changes, launch the simulator and verify:

- Account shows `Debug Console` only in DEBUG.
- Recent Events renders at least one structured event after app load or tab navigation.
- `./scripts/ios-debug-events.sh tail 20` reads the same booted app container log.
