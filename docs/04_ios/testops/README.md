# TestOps

TestOps is the unified automation and test-operations module for Beckon local and remote validation.

Use this file as the index only. Open the smallest next document for the task:

| Need | Read |
|---|---|
| Run a test | `RUNBOOK.md` |
| Understand rules and safety limits | `RULES.md` |
| Choose or add a scenario | `SCENARIOS.md` |
| Review executable case sets | `TEST_CASES.md` |
| Connect failures to Debug Console JSONL | `DEBUG_INTEGRATION.md` |
| Write a test run record | `TEMPLATES.md` |
| See capability and limits | This index; `RUNBOOK.md` for execution |
| Find saved run records | `RESULTS_INDEX.md` |

## Current Scope

- Backend-first lifecycle automation is implemented through the thin CLI `scripts/testops.mjs` and tested core module `scripts/testops-core.mjs`.
- TestOps unit coverage lives in `tests/testops/` and runs through `./scripts/testops-unit.sh`, including parser, plan, safety-gate, cleanup, redaction, report, and edge-case tests.
- The first authorized remote smoke catalog is `smoke5` in `TEST_CASES.md`.
- Matching evaluation is implemented as `request_matching_eval` with the `matching_baseline` matrix. It checks target groomer inclusion/exclusion, match reason fragments, and local hard-filter projection for service, mode, and request-day availability.
- XCUITest launch/navigation wiring is implemented in `scripts/ios-testops-e2e.sh`, `TestOpsLaunchSmokeTests`, and `TestOpsUIFlowDriver` with stable selectors and no screenshot assertions.
- Authorized full UI lifecycle execution uses `scripts/ios-testops-lifecycle.sh`; it drives both roles, verifies Debug JSONL and Supabase final state, and always performs run-tag cleanup.
- Pass/fail assertions must use API state, repository state, accessibility identifiers, and Debug JSONL events. Screenshots are failure artifacts only.
- Remote data writes require explicit operator approval outside the script plus `--execute` and `TESTOPS_REMOTE_WRITE_APPROVED=1`.

## Preserved Capability Limits

- `smoke5` is backend-only. Full UI lifecycle uses the fixed BTC-001/BTG-001 pair; a UI matrix is not implemented.
- `matching_baseline` evaluates requests and matches only, not offers/bookings/chat/reviews or image/Storage writes.
- The launch harness always exercises clear-session smoke; seeded navigation requires environment-supplied role credentials. Stable selectors belong to `TestOpsUIFlowDriver`, not screenshots.
- Generated runs live in ignored `artifacts/testops/`; entity identifiers in console and report output use eight-character support references. Credentials are never report content.
- Doctor recognizes modern secret and legacy service-role credentials. Execution, `apikey` handling and cleanup gates are owned by [Runbook](RUNBOOK.md); seed writers retain their separate JWT-only restriction.
- TestOps uses the existing T-129 account pool and does not create accounts; start from [test resource index](../../02_architecture/test_resources/README.md), not broad profile-table reads. [Rules](RULES.md) and [Scenarios](SCENARIOS.md) retain detailed boundaries. This consolidation grants no new account or remote permissions.
