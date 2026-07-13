# Worklog

```text
Date: 2026-07-12
Task: T-324 - Unified sheet keyboard gesture arbitration.
Files changed: Shared keyboard presentation policy/modifier; Request/Edit Pet business-lock routing; policy tests; concise keyboard rules/governance/plan/task/current-state memory.
Checks: TDD compile RED/GREEN; full iOS tests; iOS build; repository UI audit; diff/context/preflight.
Result: Software-keyboard drags in a sheet now belong to content scrolling/keyboard dismissal and cannot dismiss the sheet. Once the keyboard is offscreen, normal sheet dismissal returns. Existing saving and critical-overlay locks use the same shared Boolean input rather than competing presentation modifiers.
Risks: Unsaved-change confirmation remains a separate feature/data-protection responsibility. Groomer/business and residual/modal inputs still require T-325/T-326 adoption inventory. No Store, repository, backend, dependency, or remote state changed.
Next: Execute T-325 for Groomer and business-editor inputs.
```

```text
Date: 2026-07-12
Task: T-323 - Native keyboard safe-area and scroll-range correction.
Files changed: Shared keyboard/stationary-action geometry; Request duplicate keyboard code removal; focused tests; UI009-UI011 audit enforcement/tests; complete keyboard rules/governance/plan/task/current-state memory.
Checks: Apple HIG/SwiftUI/UIKit source review; Swift and audit TDD RED/GREEN; full iOS tests; iOS build; repository UI audit; duplicate keyboard-policy search; diff/context/preflight.
Result: Forms now use the system keyboard-reduced viewport instead of keyboard-height content padding. Docked keyboards move only stationary page actions back to their original coordinate; floating/hardware keyboards add no offset. Request loses excessive blank overscroll, and Edit Pet can reach lower fields through the same shared behavior.
Risks: Runtime interaction remains user validation by direction. Groomer/business and residual/modal inputs still require T-324/T-325 adoption inventory. No Store, repository, backend, dependency, or remote state changed.
Next: Execute T-324 for Groomer and business-editor inputs.
```

```text
Date: 2026-07-12
Task: T-322 - Shared keyboard dismissal contract.
Files changed: DesignSystem keyboard modifier/contract test; keyboard design/governance/plan/task/current-state memory.
Checks: TDD compile RED/GREEN; full iOS tests; iOS build; repository UI audit; diff/context/preflight.
Result: Every scrolling form using the shared keyboard modifier now inherits interactive drag dismissal and an explicit Done input accessory. Edit Pet and UIKit/number-pad inputs no longer require leaving the page to close the keyboard; page Save/Back/Continue actions retain their original coordinates.
Risks: Groomer/business and residual/modal inputs still require T-323/T-324 adoption inventory. No Store, repository, backend, dependency, or remote state changed.
Next: Execute T-323 for Groomer and business-editor inputs.
```

```text
Date: 2026-07-12
Task: T-321 - Auth and Customer shared keyboard-rule adoption.
Files changed: Auth/Onboarding/Profile/Pet focus integration; shared stationary page-action primitive; Request shared action naming; focus contract tests; design/governance/plan/task/current-state memory.
Checks: TDD compile RED/GREEN; full iOS tests; iOS build; repository UI audit; feature keyboard-rule duplication search; diff/context/preflight.
Result: Authentication, Role Onboarding, Customer Profile, and Pet editing now call the same DesignSystem keyboard modifier and expose stable complete-field focus IDs. No feature owns keyboard geometry. Pet Save no longer relies on keyboard-following safe-area inset behavior and instead uses the shared stationary page-action layer.
Risks: T-322 and T-323 still need to adopt the same primitives across Groomer/business and residual/modal inputs. Chat Send remains pending explicit input-accessory classification. No business, Store, repository, backend, dependency, or remote state changed.
Next: Execute T-322 for Groomer and business-editor inputs.
```

```text
Date: 2026-07-12
Task: T-320 - Shared minimum keyboard avoidance and Request reference migration.
Files changed: DesignSystem visibility/viewport/focus-target primitives; shared Address Editor targets; Request reference consumer/tests; design/governance/plan/task/current-state memory.
Checks: TDD compile RED/GREEN; full iOS tests; iOS build/build-run; live address/ZIP/Notes keyboard inspection; strict Wizard and repository UI audits; fixed-anchor search; diff/context/preflight.
Result: One reusable DesignSystem modifier now measures the actual scroll viewport, keyboard, and complete semantic group. Visible groups do not move; obscured groups reveal only their nearest edge plus field spacing; oversized groups remain stable. Request supplies IDs only, and ZIP sits directly above the number pad while Back/Continue remain behind it.
Risks: T-321...T-323 still need to classify and adopt the shared modifier across remaining forms; Chat may remain an explicit input accessory. Existing Supabase auth/reminder/AppIntents warnings are unchanged. No business, Store, repository, backend, dependency, or remote state changed.
Next: Execute T-321 for Auth and remaining Customer inputs.
```

```text
Date: 2026-07-12
Task: T-319 - Minimum keyboard-avoidance redesign plan.
Files changed: Formal T-320...T-323 implementation plan plus current/task/worklog routing.
Checks: Apple HIG/developer-source reconciliation; current shared geometry, Request orchestration, tests, and production input inventory review; diff/context/preflight.
Result: The rollout now corrects T-318's fixed 55% anchor before touching other forms. The approved direction uses measured semantic-group bounds, no movement when visible, nearest-edge minimum reveal when obscured, natural clamping, fixed page-action coordinates, and explicit input-accessory exceptions.
Risks: SwiftUI marker geometry and keyboard-frame interaction must prove stable in T-320 Simulator testing before reuse. No Swift, business, repository, backend, dependency, or remote state changed.
Next: Execute T-320 minimum-reveal algorithm and Request reference migration.
```

```text
Date: 2026-07-12
Task: T-318 - Reusable keyboard-aware form contract and shared geometry.
Files changed: DesignSystem keyboard geometry; Request consumer/test rename; design/governance contract; feature/task/current-state routing.
Checks: Focused Request tests; iOS build; repository UI audit; diff/context/preflight.
Result: The project now defines one keyboard-aware form contract: focus the label-plus-complete-control group, approach a 55% lower anchor with natural clamping, use measured overlap as content clearance, and keep page actions at their original coordinate. Request consumes the shared geometry without behavior change.
Risks: Remaining inputs use multiple page, sheet, and accessory containers, so T-319...T-321 migrate them in bounded, Simulator-verified groups. Chat send controls are reviewed as input accessories rather than automatically treated as page actions. No business, repository, backend, or remote state changed.
```

```text
Date: 2026-07-12
Task: T-317 - Periodic meta-review.
Files changed: Current State, Task Ledger, and Worklog closeout only.
Checks: Clean/synced branch after T-316; task/roadmap/index facts; intentional root Markdown ignore behavior; zero active conflict markers; tracked/local migrations 67/67; governance tests 13/13; context hygiene; preflight; diff.
Result: Active structure is consistent. T-307 through T-316 satisfy the ten-task cadence; Q-104 remains deferred, T-157 remains blocked, and no package is automatically selectable. Worklog/Ledger retain four/three task slots, so no rotation is due.
Risks: One reviewed UI102 warning from T-316 is the explicit UIKit keyboard-frame boundary; strict Customer Request Wizard audit has zero errors. No product, app, backend, dependency, remote state, or workflow rule changed.
```

```text
Date: 2026-07-12
Task: T-316 - Customer Request keyboard-aware form positioning.
Files changed: Shared address field focus targets; Wizard keyboard overlap/scroll/action layout; focused layout test; memory closeout.
Checks: Focused TDD RED then GREEN; full iOS tests; Simulator build/run and ZIP/Notes keyboard inspection; iOS build; strict/repository UI audit; diff/context/preflight.
Result: Focusing an address or Notes input keeps its title and full control visible near the keyboard, using a lower ideal anchor that naturally clamps at content bounds. Keyboard overlap becomes scroll clearance only; Back/Continue retain their original bottom position behind the keyboard instead of floating above it.
Risks: UIKit is imported only for keyboard frame notifications and creates one reviewed UI102 warning; no UIKit business control was added. Existing unrelated reminder/AppIntents build warnings remain. No business, Store, repository, backend, persistence, or remote state changed.
Next: T-317 is reserved for the immediately due periodic meta-review.
```

```text
Date: 2026-07-12
Task: T-315 - Customer Request address verification interaction fixes.
Files changed: Shared address preparation outcomes/equivalence/review sizing; Request Wizard continuation coordination; validation semantics; focused tests and memory closeout.
Checks: Focused TDD RED then GREEN; full iOS tests; Simulator build/run; live Profile autofill, equivalent candidate direct advance, and corrected-address compact review; iOS build; UI audit/diff/context/preflight.
Result: Complete required Time/Location fields make Continue visually actionable. Continue automatically accepts a unique equivalent Apple Maps result and advances without review; corrected or ambiguous results retain review. Profile autofill and dismissed/failed review clear stale continuation intent, including the post-await race, and confirmation review starts at 330pt with large available for accessibility.
Risks: A zero-result Apple Maps lookup still remains on the form with the existing recoverable inline error because there is no truthful suggested address to present. No provider algorithm, repository, backend, persistence, publication, or remote state changed.
Next: Use T-316 for explicitly selected work; Q-104 remains deferred.
```

```text
Date: 2026-07-12
Task: T-314 - Customer Request confirmation entered-address snapshot fix.
Files changed: Shared address editor confirmation preparation; focused regression test; task/memory closeout.
Checks: Focused TDD RED then GREEN; full iOS tests; Simulator build/run and live `770` autocomplete selection/Continue confirmation; iOS build; diff/context/preflight.
Result: Selecting an Apple Maps candidate still prefills without presenting review. Continue now rebuilds the confirmation presentation from the current full form input while preserving the resolved candidate metadata, so Entered Address shows the complete selected address instead of the original search fragment.
Risks: Live evidence used the first Apple Maps result and did not accept/publish it, avoiding remote state. No provider, repository, backend, persistence, or publication behavior changed.
Next: Use T-315 for explicitly selected work; Q-104 remains deferred.
```






















































This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.
