# Context Budget Optimization Task Plan

Date: 2026-07-09
Author: Claude (external reviewer)
Status: Review input only. Root-level external report per `AGENTS.md`. Archive to
`docs/09_frozen/external_agent_reports/` after all tasks complete.

## Background

Measured context cost per Standard task run (~258k window): active docs are only
~9% of the budget; the dominant costs are (1) unfiltered `xcodebuild` output from
`scripts/ios-build.sh` / `scripts/ios-test.sh` (~20–80k tokens per run) and
(2) reading/editing oversized Swift files (largest: 92KB test file ≈ 23k tokens
per read).

This plan contains 4 tasks. Execute them as **separate serial runs**, one task
per run, each under the next available `T-###` ID from
`docs/06_tasks/TASK_LEDGER.md`. Normal closeout, validation, and standing Git
approval rules from `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md` apply.

Verified facts the executor may rely on:

- `project.pbxproj` uses `fileSystemSynchronizedGroups` (Xcode 16). New `.swift`
  files under existing group folders are picked up automatically. **Never edit
  `project.pbxproj`.**
- No script parses the stdout of `ios-build.sh` / `ios-test.sh`
  (`scripts/testops.mjs` only references `ios-testops-e2e.sh` in a help string).
  Filtering their output has no downstream consumer impact.
- Test files use Swift Testing (`@Test` functions inside plain structs), not
  XCTest. `@Test` functions work in extensions of a suite struct across files.

---

## Task A — Filter xcodebuild output in build/test scripts

Mode: Quick. Highest priority; do this first.

### Objective

`scripts/ios-build.sh` and `scripts/ios-test.sh` currently stream full raw
`xcodebuild` output (thousands of lines). Change both so the full log goes to a
temp file and only a short, decision-relevant summary is printed.

### Scope

- Allowed: `scripts/ios-build.sh`, `scripts/ios-test.sh`
- Forbidden: any other script, `project.pbxproj`, workflow docs, Swift files.
  Do not change script names, arguments, env vars (`CODEX_IOS_*`), or exit-code
  semantics (0 = success, non-zero = failure).

### Implementation

In `ios-build.sh`, replace the final bare `xcodebuild ... build` invocation with:

```sh
log_file="$(mktemp -t ios-build)"
echo "Full log: $log_file"

if xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  build > "$log_file" 2>&1; then
  echo "BUILD SUCCEEDED"
  grep -E "warning:" "$log_file" | sort -u | head -n 15 || true
else
  echo "BUILD FAILED"
  grep -E "error:" "$log_file" | sort -u | head -n 40 || true
  tail -n 30 "$log_file"
  exit 1
fi
```

In `ios-test.sh`, replace the final bare `xcodebuild ... test` invocation with
the same pattern, but the failure branch must surface test failures:

```sh
log_file="$(mktemp -t ios-test)"
echo "Full log: $log_file"

if xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  test > "$log_file" 2>&1; then
  echo "TEST SUCCEEDED"
  grep -E "Test Suite|Executed .* tests" "$log_file" | tail -n 10 || true
else
  echo "TEST FAILED"
  grep -E "error:|✘|failed|FAILED" "$log_file" | sort -u | head -n 60 || true
  tail -n 40 "$log_file"
  exit 1
fi
```

Keep `set -euo pipefail`; the `if` wrapper already prevents `-e` from exiting
before the summary prints. Adjust grep patterns if the first real run shows
they miss the actual error lines — the acceptance bar is "an agent can act on
the summary without the full log".

### Validation

Run `./scripts/ios-build.sh` once. Confirm: exit 0, output under ~30 lines,
log path printed. If feasible, also verify the failure path once (e.g. by
temporarily introducing a syntax error in a scratch build, or by reasoning over
the branch logic if a deliberate broken build is not acceptable) — do not leave
any deliberate error in the tree.

### Done criteria

- Both scripts print bounded summaries; full logs land in temp files.
- Exit codes unchanged. No other files touched.
- Ledger/worklog closeout per workflow rules.

---

## Task B — Split CustomerRequestFeatureTests.swift

Mode: Standard. File: 92KB, the single most expensive read in the repo.

### Current structure (verified)

- Lines 5–~2300: one struct `CustomerRequestsStoreTests` containing 60 `@Test`
  functions.
- Lines 2302+: four `private final class` fakes
  (`CustomerRequestPetRepositoryFake`, `CustomerRequestAppointmentReminderSchedulerFake`,
  `CustomerRequestRepositoryFake`, `CustomerRequestBookingRepositoryFake`).

### Objective

Split into ~4–5 files of roughly ≤30KB each, with **zero behavior change**:
no test body edited, no assertion changed, no test renamed, pure code movement.

### Approach

1. Keep `CustomerRequestFeatureTests.swift` as the base file: the struct
   declaration, stored properties, init/shared helpers, and one thematic group
   of tests.
2. Move the remaining `@Test` functions into `extension CustomerRequestsStoreTests`
   blocks in new files alongside the original, grouped by existing MARK sections
   or by feature theme (e.g. `CustomerRequestFeatureTests+Wizard.swift`,
   `...+Offers.swift`, `...+Reminders.swift`). Executor chooses the grouping
   that matches the file's actual MARK structure.
3. Move the four fakes into one new file
   (`CustomerRequestFeatureTestFakes.swift`). Their `private` must become
   `internal` (drop the keyword) — this is confined to the test target and is
   the only permitted visibility change.
4. Shared helper methods/properties used by tests in multiple files must also
   drop `private` (file-scoped) so extensions in other files can reach them.
   Widen visibility only where compilation requires it.

### Scope

- Allowed: `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
  plus new sibling files in the same directory.
- Forbidden: app-target Swift files, `project.pbxproj`, any test logic change,
  deleting/skipping/weakening any test.

### Validation

- `./scripts/ios-test.sh` once (full suite). All tests pass.
- Test-count invariant: `grep -c "@Test"` summed across the new files must
  equal 60 (the pre-split count). Report both numbers in closeout.

### Done criteria

- No resulting file materially exceeds ~30KB.
- Test count and results identical to pre-split. Diff is pure movement plus
  minimal visibility widening.

---

## Task C — Split GroomerProfileFeatureTests.swift

Mode: Standard. File: 70KB. Same recipe as Task B; run only after Task B is
closed out (its diff pattern is the template).

### Current structure (verified)

- Lines 6–124: four small suites (`GroomerPortfolioPhotoPathTests`,
  `GroomerProfileStorageBucketTests`, `GroomerAvatarImageEncoderTests`,
  `GroomlyModuleImageLayoutTests`) — small, may stay together in one file.
- Lines 125–1451: `GroomerProfileStoreTests`, 45 `@Test` functions — the bulk;
  split via extensions as in Task B.
- Lines 1452+: fakes (`GroomerProfileRepositoryFake`, `ProfileSnapshotCacheFake`)
  — move to `GroomerProfileFeatureTestFakes.swift`, `private` → internal.

### Scope / Validation / Done criteria

Same as Task B, with the invariant count 45 for `GroomerProfileStoreTests`
(plus the unchanged small suites). `./scripts/ios-test.sh` once, all pass.

---

## Task D — Split GroomerProfileStore.swift

Mode: Standard, but the most delicate of the four — app-target code. Run last.

### Current structure (verified)

- Lines 6–~1657: `final class GroomerProfileStore` (single class, ~1650 lines).
- Lines 1658+: `private extension CustomerPetSizeCode`, `private struct
  GroomerProfileFormError` and related helpers.

### Objective

Split into a base file plus 3–4 `extension GroomerProfileStore` files grouped
by responsibility (suggested, subject to actual MARK structure: form editing /
services & availability / portfolio & photos / persistence & snapshot). Zero
behavior change.

### Hard rules

- All stored properties and the initializer stay in the base file
  (`GroomerProfileStore.swift`) — Swift requires this.
- Methods moved to extensions in other files that touch `private` members:
  widen those members to `internal` (drop `private`) only as compilation
  requires. Do not restructure logic, do not rename members, do not change
  access from outside the class.
- File-scoped helpers (`CustomerPetSizeCode` extension, `GroomerProfileFormError`)
  move together with their sole consumers, or into one
  `GroomerProfileStoreSupport.swift`; keep them `private`/internal exactly as
  narrow as compilation allows.
- No SwiftUI view, repository, or model file changes.

### Scope

- Allowed: `ios/.../Features/Groomer/Profile/GroomerProfileStore.swift` plus
  new sibling files in the same directory.
- Forbidden: everything else. Especially no behavior, signature, or
  `@Observable`/property-wrapper changes.

### Validation

- `./scripts/ios-build.sh` once, then `./scripts/ios-test.sh` once
  (GroomerProfileStoreTests covers this class; all must pass).

### Done criteria

- Base file plus extensions each ≤ ~25KB.
- Build and full test suite green. Diff is pure movement plus minimal
  visibility widening inside the class's own file set.

---

## Explicit non-goals for all four tasks

- No logic refactoring, no dead-code removal, no renaming, no formatting sweeps.
- No changes to workflow docs, `AGENTS.md`, `CLAUDE.md`, or the docs system.
- No changes to `project.pbxproj`.
- If any task cannot be completed without breaking a rule above, stop and
  report the conflict and options instead of working around it.

## Future candidates (not in this batch — do not start)

If the pattern proves out, the next largest files are
`CustomerRequestWizardView.swift` (70KB), `BookingsView.swift` (64KB),
`CustomerRequestsStore.swift` (53KB), `CustomerPetsView.swift` (56KB).
Queue them as separate roadmap items only on explicit user request.
