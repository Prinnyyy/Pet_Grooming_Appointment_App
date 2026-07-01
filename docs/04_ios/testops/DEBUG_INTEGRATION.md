# TestOps Debug Integration

TestOps uses the existing DEBUG-only `AppDebugEventRecorder`.

## Launch Metadata

Supported app launch arguments:

```text
--groomly-testops-run-id <id>
--groomly-testops-scenario <id>
--groomly-testops-clear-session
--groomly-testops-disable-animations
```

The app records `category=test` events with:

```text
automationRunID
scenarioID
phase
actorRole
```

`automationRunID` is stored as a support ref in app events. Full run ids live in local operator artifacts only.

## Debug Console

In DEBUG builds:

```text
Account -> Debug Console -> TestOps
```

The section shows current run ref, scenario, active phase, actor role, and latest TestOps event.

## JSONL

Use:

```bash
./scripts/ios-debug-events.sh tail 300
```

Correlate `category=test` with nearby:

- `category=navigation`
- `category=store`
- `category=repository`
- `category=feedback`

For a toast bug, find the `feedback` enqueue/presented event, then inspect Store/repository events immediately before it.

