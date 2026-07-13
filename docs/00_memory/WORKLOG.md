# Worklog

```text
Date: 2026-07-13
Task: T-332 - Chat, modal, Booking, and residual input audit.
Files changed: Shared keyboard action classification; Booking review focus/minimum-reveal integration; Chat/Booking contract tests; keyboard design plan and Design System contract; task/current-state memory.
Checks: Complete tracked input inventory; TDD compile RED and focused GREEN; full iOS tests; iOS build; Simulator launch and layered log sample; forbidden keyboard-ownership/source audit; UI audit; diff/context/preflight.
Result: Every production TextField, SecureField, TextEditor, UITextField, and UITextView occurrence now has an explicit disposition. Chat Send remains the only intentional keyboard accessory. Booking review gains one semantic focus target and the shared minimum-reveal, Done, interactive-dismissal, and hardware-keyboard zero-overlap behavior; Submit Review remains in page flow.
Risks: Simulator launch recorded the expected previous-run warning after a forced process termination plus Apple Auth/network diagnostics, with no corresponding Beckon crash or T-332 fault. Runtime interaction remains user validation by direction. No Store, repository, backend, schema, dependency, or remote state changed.
Next: Use T-335 for the next user-directed task.
```

```text
Date: 2026-07-13
Task: T-334 - Shared grooming-location selector.
Files changed: Shared DesignSystem location selector; Customer Request and Groomer Profile adoption; focused presentation/selection contract test; four-entry UI debt baseline prune; task/current-state memory.
Checks: TDD compile and expectation RED then focused GREEN; iOS build; stale-component/source audit; UI baseline prune/check; diff/context/preflight.
Result: Service Location and Address Details replace the provisional Request labels. One icon-free selector now owns location-mode order, card layout, selection feedback, and role-aware copy: Customer sees My Home / Groomer's Place with single selection, while Groomer sees Customer's Home / My Place with multiple selection. Raw values and backend direction remain unchanged, and four resolved Feature-level UI debt entries are removed without adding exceptions.
Risks: Groomer wording is intentionally perspective-aware rather than copying My Home into the opposite role. Visual spacing remains user review by direction. No Store, repository, backend, schema, dependency, or remote state changed.
```

```text
Date: 2026-07-13
Task: T-333 - Customer Request Grooming Setup separation.
Files changed: Request Wizard location presentation; customer location-mode copy; focused presentation contract test; task/current-state memory.
Checks: TDD compile RED then focused GREEN; iOS build; diff/context/preflight.
Result: Request Step 3 now presents a description-free Grooming Setup group above Location. Its existing mode choices read At My Home and At the Groomer, while Location contains only address and travel-range inputs. Existing enum raw values, Store state, publication parameters, and matching behavior are unchanged.
Risks: Visual spacing remains user review by direction. No repository, backend, schema, dependency, or remote state changed.
```

```text
Date: 2026-07-12
Task: T-331 - Stationary page-action keyboard hiding correction.
Files changed: Shared stationary-action geometry/modifier; Request presentation contract test; keyboard design/plan/task/current-state memory.
Checks: TDD compile RED then focused GREEN; full iOS tests; XcodeBuildMCP build/run; Groomer Profile keyboard show/hide screenshots; sampled recent runtime/OS logs; repository UI audit; diff/context/preflight.
Result: A bottom-docked software keyboard now moves every shared stationary page action by keyboard overlap plus its measured height, placing the complete action below the screen. Keyboard dismissal animates it back from the bottom. Floating and hardware keyboards produce no offset, and Feature callers remain unchanged.
Risks: The first post-dismiss screenshot captured a transient black transition frame; a settled recapture was normal and sampled logs contained no relevant fault/error/warning. No Store, repository, backend, dependency, or remote state changed.
```

```text
Date: 2026-07-12
Task: T-330 - Layered Xcode runtime-log inspection rule.
Files changed: Tooling policy; iOS build/testing guidance; decision/task/current-state memory.
Checks: Targeted rule review; diff check; context hygiene; preflight.
Result: Any Standard/Deep validation that launches Beckon now samples recent Debug Area/process output and severity/task keywords, expands relevant messages and narrow time windows only when needed, and classifies app-owned versus Apple/Simulator diagnostics before code changes.
Risks: This is a diagnostic sampling requirement, not a promise that every system warning is actionable. Build-only, test-only, docs-only, and static validation remain exempt. No Swift, backend, dependency, or remote state changed.
Next: Superseded by the T-331 closeout above.
```

```text
Date: 2026-07-12
Task: T-329 - Shared keyboard geometry feedback-loop correction.
Files changed: Shared keyboard focus/viewport geometry reporting; DesignSystem policy test; keyboard design/plan/task/current-state memory.
Checks: TDD compile RED then focused GREEN; full iOS tests; iOS build; repository UI audit; removed-preference/API source scan; Edit Pet Simulator input/drag and runtime-log inspection; diff/context/preflight.
Result: Only the currently focused valid target reports geometry through `onGeometryChange`; viewport changes use the same non-preference path. This removes the SwiftUI `BeckonKeyboardFocusTargetBoundsKey` multiple-updates-per-frame feedback loop while preserving every Feature call site and shared keyboard behavior.
Risks: RTI session and keyboard haptic-library messages are Simulator system diagnostics, not app-owned APIs, and require no product patch unless a physical device reproduces a visible input or haptic failure. The residual input audit was subsequently moved to T-332 by T-330/T-331; no Store, repository, backend, dependency, or remote state changed.
Next: Superseded by the T-330 closeout above.
```

```text
Date: 2026-07-12
Task: T-328 - Periodic documentation-governance meta-review.
Files changed: Current/task/worklog/feature routing; automatic Worklog archive rotation; rotation whitespace normalization and isolated regression test.
Checks: Clean/synced branch; task/roadmap/index facts; root-ignore/frozen-report audit; zero active conflict markers; tracked/local migrations 67/67; backend markers; rotation TDD RED/GREEN; governance tests 15/15; diff/context/preflight.
Result: Active structure is consistent after correcting stale T-314/T-328 routes and removing historical Next instructions. Worklog rotation restores six task slots and now preserves its footer without accumulating blank lines; T-329 is the sole next planned implementation task, while T-157 remains blocked and Q-104 remains user-deferred.
Risks: Active word telemetry remains informational. No product, Swift, backend, dependency, remote state, or workflow rule changed.
Next: Compact at this mandatory boundary, then execute T-329.
```

```text
Date: 2026-07-12
Task: T-327 - Groomer and business-editor shared keyboard-rule adoption.
Files changed: Groomer Profile/Service/Time Off/Offer form wiring; semantic action-content clearance token; focus contract tests; plan/task/current-state memory.
Checks: TDD compile RED then focused GREEN; full iOS tests; iOS build; repository UI audit; Groomer input/policy inventory; diff/context/preflight.
Result: Every Groomer production text input is now covered by Profile, Service, Time Off, or Offer form integration with the existing shared minimum-reveal, dismissal, and sheet-arbitration modifier. Save/Submit actions retain page coordinates through the shared stationary layer, and repeated bottom clearance is one semantic token.
Risks: Runtime keyboard feel remains user validation by direction. Chat, Booking, modal, and residual inputs still require T-329 classification; true composer actions may remain keyboard accessories. No Store, repository, backend, dependency, or remote state changed.
```

```text
Date: 2026-07-12
Task: T-326 - Shared keyboard interaction stabilization.
Files changed: Shared reveal/presentation policy; DesignSystem policy tests; keyboard design/governance/plan/task/current-state memory.
Checks: TDD compile RED then focused GREEN; full iOS tests; iOS build; repository UI audit; diff/context/preflight.
Result: One-shot field reveal no longer leaves a running animation that can oppose a user's drag. Sheet dismissal stays disabled for the complete interactive keyboard-dismissal gesture and releases only when scrolling returns to idle, preventing one drag from switching gesture owners.
Risks: Runtime feel remains user validation by direction. Groomer/business and residual/modal inputs still require T-327/T-328 adoption inventory. No Feature, Store, repository, backend, dependency, or remote state changed.
```

```text
Date: 2026-07-12
Task: T-325 - Shared keyboard drag handoff correction.
Files changed: Shared reveal/presentation policy; DesignSystem policy tests; keyboard design/governance/plan/task/current-state memory.
Checks: Apple SwiftUI/UIKit source review; TDD compile RED then focused GREEN; full iOS tests; iOS build; repository UI audit; diff/context/preflight.
Result: Automatic minimum reveal now runs once for new focus or keyboard appearance, then cancels when user-driven scrolling starts. Geometry and interactive keyboard-frame updates cannot restart `scrollTo`, so the continued downward drag is handled by native interactive keyboard dismissal across every shared-rule consumer.
Risks: Runtime feel remains user validation by direction. Groomer/business and residual/modal inputs still require T-326/T-327 adoption inventory. No feature, Store, repository, backend, dependency, or remote state changed.
```

```text
Date: 2026-07-12
Task: T-324 - Unified sheet keyboard gesture arbitration.
Files changed: Shared keyboard presentation policy/modifier; Request/Edit Pet business-lock routing; policy tests; concise keyboard rules/governance/plan/task/current-state memory.
Checks: TDD compile RED/GREEN; full iOS tests; iOS build; repository UI audit; diff/context/preflight.
Result: Software-keyboard drags in a sheet now belong to content scrolling/keyboard dismissal and cannot dismiss the sheet. Once the keyboard is offscreen, normal sheet dismissal returns. Existing saving and critical-overlay locks use the same shared Boolean input rather than competing presentation modifiers.
Risks: Unsaved-change confirmation remains a separate feature/data-protection responsibility. Groomer/business and residual/modal inputs still require T-325/T-326 adoption inventory. No Store, repository, backend, dependency, or remote state changed.
```

```text
Date: 2026-07-12
Task: T-323 - Native keyboard safe-area and scroll-range correction.
Files changed: Shared keyboard/stationary-action geometry; Request duplicate keyboard code removal; focused tests; UI009-UI011 audit enforcement/tests; complete keyboard rules/governance/plan/task/current-state memory.
Checks: Apple HIG/SwiftUI/UIKit source review; Swift and audit TDD RED/GREEN; full iOS tests; iOS build; repository UI audit; duplicate keyboard-policy search; diff/context/preflight.
Result: Forms now use the system keyboard-reduced viewport instead of keyboard-height content padding. Docked keyboards move only stationary page actions back to their original coordinate; floating/hardware keyboards add no offset. Request loses excessive blank overscroll, and Edit Pet can reach lower fields through the same shared behavior.
Risks: Runtime interaction remains user validation by direction. Groomer/business and residual/modal inputs still require T-324/T-325 adoption inventory. No Store, repository, backend, dependency, or remote state changed.
```

```text
Date: 2026-07-12
Task: T-322 - Shared keyboard dismissal contract.
Files changed: DesignSystem keyboard modifier/contract test; keyboard design/governance/plan/task/current-state memory.
Checks: TDD compile RED/GREEN; full iOS tests; iOS build; repository UI audit; diff/context/preflight.
Result: Every scrolling form using the shared keyboard modifier now inherits interactive drag dismissal and an explicit Done input accessory. Edit Pet and UIKit/number-pad inputs no longer require leaving the page to close the keyboard; page Save/Back/Continue actions retain their original coordinates.
Risks: Groomer/business and residual/modal inputs still require T-323/T-324 adoption inventory. No Store, repository, backend, dependency, or remote state changed.
```

```text
Date: 2026-07-12
Task: T-321 - Auth and Customer shared keyboard-rule adoption.
Files changed: Auth/Onboarding/Profile/Pet focus integration; shared stationary page-action primitive; Request shared action naming; focus contract tests; design/governance/plan/task/current-state memory.
Checks: TDD compile RED/GREEN; full iOS tests; iOS build; repository UI audit; feature keyboard-rule duplication search; diff/context/preflight.
Result: Authentication, Role Onboarding, Customer Profile, and Pet editing now call the same DesignSystem keyboard modifier and expose stable complete-field focus IDs. No feature owns keyboard geometry. Pet Save no longer relies on keyboard-following safe-area inset behavior and instead uses the shared stationary page-action layer.
Risks: T-322 and T-323 still need to adopt the same primitives across Groomer/business and residual/modal inputs. Chat Send remains pending explicit input-accessory classification. No business, Store, repository, backend, dependency, or remote state changed.
```

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.
