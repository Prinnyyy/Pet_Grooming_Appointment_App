# Customer and Shared Booking UI Acceptance

<!-- task-artifact
task: T-403
status: completed
type: plan
-->

## Scope and Rules

User adopted targeted Customer/shared UI/UX and accessibility acceptance after T-402. Reuse unchanged T-401 request-wizard/deck and T-402 shared-layout/keyboard evidence. Inspect gaps rather than repeat marketplace business acceptance. Local Simulator only; no remote data writes, new capability, dependency, physical-device or release work. Preserve existing user edits.

Authority: [Design System](../../01_product/DESIGN_SYSTEM.md), [Accessibility](../../01_product/ACCESSIBILITY_RULES.md), [Forms](../../01_product/FORM_INTERACTION_RULES.md), [UI governance](../../04_ios/UI_CODE_GOVERNANCE.md).

## Surface Ownership

| Step | User job | Existing owner and review focus |
|---|---|---|
| 1. Offers | Compare provider, price, time, eligibility; deliberately confirm | Customer Requests Store and offer views; duplicate refresh, long metadata, exact terms and recovery. |
| 2. Booking handoff | Inspect agreed appointment and contact the provider | Customer shell owns chat navigation; shared Bookings Store/detail owns appointment. No inactive action placeholders. |
| 3. Fulfillment | Cancel before start, report/confirm an outcome, check uncertain results | Shared BookingFulfillmentSection; semantic actions, explicit confirmation, readable activity and accessible note entry. |
| 4. Reschedule | Review original/proposed time and consent without losing original reservation | Shared BookingRescheduleSection; distinguish read/retry/write, loading and terminal states. |
| 5. Review | Rate completed service and optionally report supported fit outcomes | BookingsStore/review context; labels, large text, keyboard, busy/error and persisted review. |
| 6. Shared regression | Return, read feedback, inspect long values on both roles | Existing primitives and role shells; no generic framework or unrelated debt cleanup. |

## Execution

- [x] Confirm governing rules, actual owners and evidence reuse boundary.
- [x] Capture focused baseline states using production views with local Fake repositories; record reproduced defects.
- [x] Add focused failing tests, make scoped fixes, verify positive/negative behavior.
- [x] Compact/large Simulator, normal/AX3 text and real software-keyboard interactions; semantic targets, a few inspected captures, no screenshot-per-click driving.
- [x] Integrated build/test/preflight and full document hygiene. Completion commit/push is recorded by Git, not a self-referencing document hash.

## Findings and Evidence

Confirmed on compact Simulator: AX3 offer names collapse into a column of letters (hosted row regression RED: 1,764pt height at 350pt width); lifecycle actions expose 20-21pt AX frames; review rating/fit selectors expose 31pt frames; review editor lacks a spoken label. The normal booking surface also repeats chat/status chips and offers duplicate refresh controls.

Source-confirmed routing: offer acceptance and both role notification destinations create booking details without a chat callback; the previous default silently did nothing. Repair uses an optional environment action owned by each existing role shell, with explicit local callbacks retaining precedence. No new navigation capability or global router.

Other scoped repairs: reuse the booking model's service-zone time summary; stack metadata at accessibility sizes; use existing button styles and keyboard policy; hide an empty terminal reschedule section while retaining proposals/errors/recovery; use approved text contrast. Cancellation confirmation copy now states the existing pre-service condition.

Investigated, not a confirmed defect: reopening with cached review context passed the fresh-versus-cached hosted regression. Keep the existing authoritative context reload and optional signals; do not change rating or matching policy.

## Acceptance

| Evidence | Result |
|---|---|
| Compact iPhone 17e and large iPhone 17 Pro Max, normal/AX3 | Long offer names, price/time, booking facts, review form and submitted outcomes remain readable; final review menu AX targets are 52pt and lifecycle buttons 53pt. |
| Offer handoff | Actual local offer selection, confirmation and acceptance reach booking details; inherited Open Chat action reaches its test destination. Empty/error offers retain one working refresh entry. |
| Shared booking operations | Cancel and proposal-withdrawal confirmation/dismissal, original/proposed times, in-service interruption and terminal-state presentation checked. No empty Time Changes section in service. Missing booking exposes Retry. |
| Review and keyboard | Rating/fit menus, optional text and submit dispatch checked. Missing review context disables submit and exposes Retry Service Details. Review and required interruption note stay usable with the software keyboard; shared Done dismisses it without losing input. Empty required note blocks confirmation. |
| Focused regression | Long-name layout RED reproduced, then GREEN; cached context remains consistent. Final three hosted/Store regression tests pass, including authoritative review readback in the local fixture. |
| Full regression | `./scripts/ios-test.sh` on the large Simulator: Passed, 773 tests passed, 45 skipped, 0 failed (818 distinct tests; 902 passing executions including parameterized cases). Opt-in/manual and credentialed TestOps skips are explicit; local UI host was run separately. |
| Build and static gates | `./scripts/ios-build.sh` and `./scripts/preflight.sh` pass. UI ratchet has 142 findings/113 baseline entries with no new errors or stale entries; only two resolved baseline entries removed. Full document hygiene and diff whitespace checks pass. Build's AppIntents metadata warning is unchanged, not an app failure. |

The local harness uses existing Fake repositories and opt-in XCTest execution, not an app route or production test toggle. A failed fixture compile and a stale post-review Fake response were repaired in test code only; neither is counted as an app defect. One full-test attempt accidentally inherited the opt-in manual host and waited on private XCTest clones; it was stopped, excluded from acceptance and replaced by the clean full run above. Interactive runs explicitly disable parallel testing. No production change followed final runtime acceptance.

Local evidence: ignored `artifacts/testops/T403-ui/` contains selected before/after captures, final AX trees, focused/manual logs, `full-regression-summary.json` and `build-final.log`. Full result: `Test-Beckon-2026.10.04_20-26-05--0700.xcresult` in the existing DerivedData test logs. Runtime accessibility-tree/labels/targets and reused shared announcement evidence do not claim audible VoiceOver/rotor certification. Local repository tests do not prove remote persistence or repeat prior end-to-end marketplace acceptance. Existing unrelated UI debt and user changes remain outside this task.
