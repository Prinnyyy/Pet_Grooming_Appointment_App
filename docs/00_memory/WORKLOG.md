# Worklog

```text
Date: 2026-07-13
Task: T-341 - Customer Home request Hero visual restoration and role action colors (checkpoint).
Files changed: Customer Home Hero presentation/layout; shared customer/groomer action foreground tokens and button styles; color contract; focused tests; design spec/plan; task/current-state memory.
Checks: TDD compile RED confirmed missing role tokens, then missing Hero copy, then missing Hero contrast token. The first focused GREEN command stopped after test-bundle signing without a result or residual xcodebuild process. A subsequent full iOS suite failed only four existing Feedback Center timing tests under parallel load; xcresult showed queued prompts remained nil or visible past expected timer boundaries, while T-341 tests were not listed as failures. After that result, the user explicitly paused tests and requested screenshot-faithful color/graphics instead of the darker contrast treatment. Static diff whitespace checks only after visual revisions; no iOS test/build rerun. The first context-hygiene pass rejected nonstandard `next unallocated task ID` wording; the durable files now use the required extractable forms. A later temporary Swift pixel-sampling command used invalid comma-separated imports and failed before execution; the corrected read established that the PNG is Display P3 and returned its raw pixels. The next context check rejected a 753-character T-341 Ledger row; the row was compressed below its 700-character structural limit.
Result: In-progress local checkpoint was resumed through human-review iterations. The Hero preserves raw Display P3 reference background and decoration colors while all copy and active action text now use shared `textPrimary #232323`; measured contrast ranges from 8.78:1 on the darkest mint to 15.72:1 on white. Its typography follows the shared Beckon semantic hierarchy: `sectionTitle`, `supporting`, and `action`; the previous Hero-only fixed-size Rounded fonts were removed. The copy width is 232pt, the action remains content-sized, the circle is 110pt, and paws retain the lower-right diagonal placement. Disabled action styling remains owned by the shared button component. No Store, navigation, repository, backend, dependency, or remote state changed.
Risks: The current visual revision is intentionally unbuilt and untested pending human in-app review. The full-suite Feedback Center timing failures remain recorded and are outside T-341 scope unless separately authorized. No completion commit or push is allowed until validation resumes and succeeds.
Next: User manually reviews the local T-341 Hero; then resume focused/full validation or revise the same task.
```

```text
Date: 2026-07-13
Task: T-339 - Periodic documentation-governance meta-review.
Files changed: Current/task/worklog/feature routing only.
Checks: Clean/synced branch; task/roadmap/index facts; root Markdown ignore/frozen routing; zero active conflict markers; tracked/local migrations 67/67; current backend markers; 26/26 context/rotation governance tests; diff/context/preflight. The first consolidated shell audit used zsh's special `path` variable as a loop name, which removed command lookup for the remaining checks and produced invalid empty counts; those results were discarded, the variable was renamed, and the complete audit reran successfully.
Result: Active governance is consistent after correcting the stale Feature Index statement that assigned the completed residual/modal/chat audit to T-329 instead of T-332. T-340 is the next planned task and T-341 remains unallocated.
Risks: T-340 still owns the two app compiler warnings recorded by T-337/T-338; AppIntents metadata extraction remains classified as toolchain information. T-157 and Q-104 remain blocked/deferred. No product, Swift, backend, dependency, remote state, or workflow rule changed.
```

```text
Date: 2026-07-13
Task: T-338 - Supabase initial-session compatibility and expiry-safe restore.
Files changed: Supabase client Auth options; Auth session snapshot/repository mapping; Authentication Store restore policy; focused auth tests; task/current-state memory.
Checks: Supabase Swift 2.46 source and official PR #822 review; TDD compile RED and focused GREEN; full iOS tests; iOS build; legacy initial-session warning scan; diff/context/preflight. The first GREEN compile exposed a missing Supabase test import and MainActor isolation on the options assertion; both test declarations were corrected and the rerun passed. Context hygiene also rejected two ambiguous Ledger phrasings while T-339 was being reserved; the machine-readable wording now identifies T-339 as the next task and keeps T-341 only as the next unallocated ID.
Result: Beckon opts into local-session-first initial emission, carries `Session.isExpired` through its repository boundary, and never authorizes an expired cached session. The root remains loading until the SDK emits a valid refreshed session or signed-out state, eliminating the ghost-session startup path and its compatibility warning.
Risks: A transient refresh failure for which the SDK emits neither token-refreshed nor signed-out leaves the app loading under the SDK's documented contract; no custom timeout or competing refresh loop was added. The build reconfirmed the redundant-await warning now tracked as T-340 and the no-AppIntents metadata message classified as toolchain information. No schema, backend, dependency, or remote state changed.
```

```text
Date: 2026-07-13
Task: T-337 - Shared Liquid Glass keyboard dismissal control.
Files changed: Shared keyboard accessory presentation/visibility; DesignSystem contract test and contract documentation; design spec/plan; task/current-state memory.
Checks: Root-cause/source audit; TDD compile RED and focused GREEN; complete SwiftUI/UIKit input-owner coverage audit; no-native-keyboard-toolbar scan; full iOS tests; iOS build; UI consistency audit; diff/context/preflight. The first GREEN compile exposed main-actor token access from a nonisolated policy; the policy now owns its immutable dimensions and the rerun passed.
Result: The system-styled floating Done text button is replaced by one 52-point trailing circular dismissal control with a mint checkmark, 12-point keyboard gap, and 20-point screen inset. iOS 26 uses interactive native Liquid Glass; earlier supported systems use an ultra-thin material circle. Existing shared call sites cover all audited input owners.
Risks: Manual in-app UI/UX review was not performed by Codex per user direction and remains the user's acceptance step. The control only resigns the current first responder; form, Store, repository, backend, and persistence behavior are unchanged. The build also exposed two pre-existing app-owned warnings now tracked by T-339; the AppIntents metadata-skipped message is recorded there as toolchain information. The earlier Supabase startup warning is tracked by T-338.
```

```text
Date: 2026-07-13
Task: T-336 - Customer form actions and shared keyboard Done.
Files changed: Pet Store/form navigation action; Request header/progress and TestOps dismissal routing; shared location descriptions; shared Done accessory and input-owner coverage; resolved UI004 baseline prune; focused tests; design spec/plan/system contract; task/current-state memory.
Checks: TDD compile RED and focused GREEN; complete input-owner source inventory; stale Pet/header source scan; full iOS tests; iOS build; UI consistency audit; diff/context/preflight.
Result: Add Pet uses Create and Edit Pet uses Save in the navigation bar, disabled until the valid form differs from its baseline; the former bottom Save Pet action is removed. Request has one bottom Back path and full-width progress. Location choices show shared role-aware descriptions. Every Feature input owner and DEBUG catalog receives the same Done accessory with equal trailing/bottom inset.
Risks: Manual in-app UI/UX review was not performed by Codex per user direction and remains the user's acceptance step. Existing savePet repository behavior, grooming-location raw values, persistence, matching, and backend contracts are unchanged. No schema, dependency, or remote state changed.
```

```text
Date: 2026-07-13
Task: T-335 - Shared service-location detail copy cleanup.
Files changed: Shared grooming-location presentation; Customer/Groomer Request and Booking detail copy; Booking model legacy title removal; presentation tests; Design System and task/current-state memory.
Checks: Root-cause/source inventory; TDD compile RED and focused GREEN; full iOS tests; iOS build; Simulator launch and error/fault log sample; stale-copy source audit; UI audit; diff/context/preflight.
Result: Service Location selectors and all identified read-only detail surfaces now use one role-aware copy source. Customer details show My Home or Groomer's Place, Groomer details show Customer's Home or My Place, and duplicate Service Mode/Groomer travels/Customer can visit mappings are removed. Raw values, persistence, and matching semantics are unchanged.
Risks: Visual review remains user-owned by direction. A missing-location Booking retains the neutral Location Details fallback. No Store, repository, backend, schema, dependency, or remote state changed.
Next: Superseded by the T-336 closeout above.
```

```text
Date: 2026-07-13
Task: T-332 - Chat, modal, Booking, and residual input audit.
Files changed: Shared keyboard action classification; Booking review focus/minimum-reveal integration; Chat/Booking contract tests; keyboard design plan and Design System contract; task/current-state memory.
Checks: Complete tracked input inventory; TDD compile RED and focused GREEN; full iOS tests; iOS build; Simulator launch and layered log sample; forbidden keyboard-ownership/source audit; UI audit; diff/context/preflight.
Result: Every production TextField, SecureField, TextEditor, UITextField, and UITextView occurrence now has an explicit disposition. Chat Send remains the only intentional keyboard accessory. Booking review gains one semantic focus target and the shared minimum-reveal, Done, interactive-dismissal, and hardware-keyboard zero-overlap behavior; Submit Review remains in page flow.
Risks: Simulator launch recorded the expected previous-run warning after a forced process termination plus Apple Auth/network diagnostics, with no corresponding Beckon crash or T-332 fault. Runtime interaction remains user validation by direction. No Store, repository, backend, schema, dependency, or remote state changed.
Next: Superseded by the T-335 closeout above.
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

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.
