# TestOps

TestOps is the unified automation and test-operations module for Groomly local and remote validation.

Use this file as the index only. Open the smallest next document for the task:

| Need | Read |
|---|---|
| Run a test | `RUNBOOK.md` |
| Understand rules and safety limits | `RULES.md` |
| Choose or add a scenario | `SCENARIOS.md` |
| Review executable case sets | `TEST_CASES.md` |
| Connect failures to Debug Console JSONL | `DEBUG_INTEGRATION.md` |
| Write a test run record | `TEMPLATES.md` |
| See current module state | `TESTOPS_MEMORY.md` |
| Find saved run records | `RESULTS_INDEX.md` |

## Current Scope

- Backend-first lifecycle automation is implemented through the thin CLI `scripts/testops.mjs` and tested core module `scripts/testops-core.mjs`.
- TestOps unit coverage lives in `tests/testops/` and runs through `./scripts/testops-unit.sh`.
- The first authorized remote smoke catalog is `smoke5` in `TEST_CASES.md`.
- XCUITest launch wiring is implemented in `scripts/ios-testops-e2e.sh` and `TestOpsLaunchSmokeTests`.
- Pass/fail assertions must use API state, repository state, accessibility identifiers, and Debug JSONL events. Screenshots are failure artifacts only.
- Remote data writes require explicit operator approval outside the script plus `--execute` and `TESTOPS_REMOTE_WRITE_APPROVED=1`.
