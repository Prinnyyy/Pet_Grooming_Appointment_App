# iOS Build and Testing

For isolated interactive Preview work, [Sandbox Workflow](../05_workflow/SWIFTUI_FLOW_SANDBOX_WORKFLOW.md) determines required checks. The commands below are available tools, not a mandatory sandbox checklist.

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

## Customer Home Preview

Open `ios/Beckon/Beckon/Features/Customer/Pets/CustomerHomeFlowSandbox.swift` and resume `Customer Home - all modules` in Canvas. It uses the complete production Home View: greeting/notifications, request entry, pets, active request, next booking and conditional recovery components. The existing pet sandbox session supplies editing, feedback and isolated storage; Reload and Reset affect only this session.

The footer switches the fixture request between Posted, Offers and Booked, and Reload replays the entrance. The complete customer index in `FlowSandbox/Customer/CustomerFlowSandbox.swift` now hosts adopted production views, with screen/state fixtures for the six-step wizard, selectable groomer list, offers, bookings, messages and account. The frozen `FlowSandbox/Prototype/` snapshots remain a design reference; they are not the host's runtime UI.

Local session repositories support publication, invitations, pool state, bookings and messages without real accounts or services. Request creation preserves the entered draft, assigns a new request ID and scopes invitations/pool state per request; replay of the same operation remains idempotent. Missing form values are supplied only through the DEBUG sandbox advance hook. The normal App retains required-field validation and real repositories. The wizard's Done action opens Requests, as in the adopted App. Preferences stay in memory, temporary pending-publication files remain session-scoped, and reminders/address lookup cannot call real services.

Current adoption evidence and its limits are recorded in the [T-420 plan](../superpowers/plans/2026-10-25-customer-ui-adoption.md). T-418 Original/Playful and T-419 Home-only evidence are historical and do not certify the later all-customer adoption. For opt-in local UI acceptance, use `CustomerUIAdoptionAcceptanceTests/testLocalCustomerJourney` with the existing `--beckon-ui-test-signed-out-auth` test-host argument and `BECKON_UI_ADOPTION=1`; the test replaces the window root with the isolated host and restores it afterward. Do not set `XCODE_RUNNING_FOR_PREVIEWS` for hosted Simulator tests: that Canvas-specific flag prevents this interactive host from rendering.

## Pet Flow Preview

Open `ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetsFlowSandbox.swift` in Xcode,
enable Editor > Canvas, select an iPhone and resume the interactive preview.

- `Pet flow - edit and save`: open a pet card, edit, save, and verify the updated card and existing success toast. Reload reads the same in-memory data; Reset starts a new isolated session.
- `Pet flow - unconfirmed save`: the first save simulates a network failure without applying the edit. The production form preserves edits and requires explicit reload/confirmation before retrying; later saves succeed.
- The sandbox reuses the production pet section, form, Store, validation and feedback components. Cancel does not save. The existing Add/Remove/photo actions also use sandbox data.
- No login or live repository is used. Pet/photo data lives in memory; existing photo-cache and pending-creation code receives a unique directory under `temporaryDirectory/BeckonPetFlowSandbox/`. Reset invalidates old operations and removes that session's files; deinitialization also cleans up. A terminated preview process may leave disposable files in its temporary container.
- In DEBUG, Xcode's `XCODE_RUNNING_FOR_PREVIEWS=1` flag prevents the app entry from constructing live services. Normal launches and Release builds retain the normal composition. No sandbox route, scheme, signing change or new dependency is needed.

Focused behavior coverage: `PetFlowSandboxTests` and `CustomerPetsStoreTests`.
Preview is for local UX iteration, not evidence of backend authorization, real persistence, or device integration.

T-417 historical acceptance (2026-10-20), not a required checklist for later sandbox iterations: the two initial regression tests failed on missing revisions and non-persistent preview edits, then the 54-test focused run passed. Xcode Canvas Live Mode verified card-to-editor navigation, editing, cancel, save/return with the production success toast, reload, reset and default/AX3 list layout. The failure preview retained edits and disabled saving; automated tests verified its reload/retry path. No fresh spoken VoiceOver or comprehensive keyboard/device review was performed.

The integrated run passed 835 tests and skipped 46 opt-in tests, with one existing four-second feedback-dismissal timeout. All eight unchanged `BeckonFeedbackCenterTests` passed in an isolated retest using the same built products; other passing results were reused. XcodeBuildMCP result bundles end in `19-08-36-588Z_pid73300_2cc27364.xcresult` (full) and `19-16-49-558Z_pid73300_33fd36d1.xcresult` (retest). The full-run tool timed out at 300 seconds; its original process was allowed to finish and the completed result bundle was read directly, without starting a duplicate run. Debug/Release builds, preflight and context hygiene passed.

Inherited UX observation, not changed by this sandbox: the production Store resets editing identity before sheet dismissal finishes, so the editor title can briefly change to "Add pet" while closing.

## Debug Event Logs

For local app repros, DEBUG builds expose `Account -> Debug Console` and write structured JSONL events to the booted simulator app container. Use:

```bash
./scripts/ios-debug-events.sh tail 100
./scripts/ios-debug-events.sh path
```

The full usage and instrumentation rules live in `docs/04_ios/DEBUG_CONSOLE.md`.

When runtime behavior is inspected in Xcode or Simulator, sample only the recent Debug Area/process output for launch and the exercised path. Review faults, errors, warnings, and task-relevant keywords first. Open the full message and a narrow surrounding time window only when a relevant diagnostic appears; broaden the search only if that evidence cannot identify source or ordering. Distinguish Beckon diagnostics from Apple/Simulator keyboard, haptic, rendering, and service noise before changing code.

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
- Diagnose task-related failures using the [Development Guide](../05_workflow/DEVELOPMENT_GUIDE.md#decisions-and-stops); retries require new evidence or a relevant correction, not a fixed attempt count.
