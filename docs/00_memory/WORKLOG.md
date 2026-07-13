# Worklog

```text
Date: 2026-07-12
Task: T-318 - Reusable keyboard-aware form contract and shared geometry.
Files changed: DesignSystem keyboard geometry; Request consumer/test rename; design/governance contract; feature/task/current-state routing.
Checks: Focused Request tests; iOS build; repository UI audit; diff/context/preflight.
Result: The project now defines one keyboard-aware form contract: focus the label-plus-complete-control group, approach a 55% lower anchor with natural clamping, use measured overlap as content clearance, and keep page actions at their original coordinate. Request consumes the shared geometry without behavior change.
Risks: Remaining inputs use multiple page, sheet, and accessory containers, so T-319...T-321 migrate them in bounded, Simulator-verified groups. Chat send controls are reviewed as input accessories rather than automatically treated as page actions. No business, repository, backend, or remote state changed.
Next: Execute T-319 Auth and Customer input migration.
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

```text
Date: 2026-07-12
Task: T-313 - Customer Request address and publish flow fixes.
Files changed: Shared address editor state/overlay; Request Wizard validation, confirmation, and feedback routing; v2 Request RPC payload encoding; focused tests and memory closeout.
Checks: TDD compile RED then GREEN; full iOS tests; Simulator build/run; live empty-State, autocomplete overlay, candidate prefill, Continue-confirm, and post-confirm advance inspection; repository/strict UI audit; diff/context/preflight.
Result: State remains neutral until validation; suggestions form one top overlay; candidate selection no longer opens review; Continue owns format confirmation; accepted addresses advance automatically; publish failure stays in the active Wizard's global bottom feedback. Missing Apple place IDs are sent as explicit RPC null values so PostgREST can match the existing v2 function.
Risks: Final publish was not exercised manually because it would create remote data without authorization; the exact payload shape and successful repository path are covered by focused/full tests. No schema, RPC signature, Supabase policy, dependency, or remote state changed.
Next: Use T-314 for explicitly selected work; Q-104 remains deferred.
```

```text
Date: 2026-07-12
Task: T-312 - Q-120 UI consistency first-slice integration gate.
Files changed: Published the remaining UI debt inventory; marked Customer Home/Requests/Wizard/Account as the semantic reference slice; closed R-041 in design, screen, roadmap, queue, feature, baseline, task, and memory sources.
Checks: Repository and strict JSON audits; audit/preflight script tests 13/13; full iOS tests; iOS build; preflight; compact/large default and Accessibility 3 screenshots plus semantic snapshots; Reduce Motion launch/navigation check; diff/context hygiene.
Result: Four Customer reference surfaces have zero strict errors. The repository ratchet reports 218 baselined findings plus four reviewed warnings, no new errors, and no stale entries. The remaining 222 candidates are explicit and prioritized without treating baseline entries as approval.
Risks: Audit warnings still require human interpretation, and default/AX3 rendering is final anomaly evidence rather than a substitute for code rules. Q-104 Groomer Dynamic Type/Accessibility remains user-deferred; no backend, dependency, navigation, or business behavior changed.
Next: Use T-313 for explicitly selected work; no package is automatically dependency-satisfied while Q-104 remains deferred.
```

```text
Date: 2026-07-12
Task: T-311 - Q-119 Customer Account migration.
Files changed: Extracted Customer Account ownership; shared semantic Account/Auth sections, settings rows, and release links; UI audit baseline; roadmap/task/memory closeout.
Checks: strict RED then GREEN for Customer Account and authenticated Account; baseline prune 16; full iOS tests; iOS build/build-run; default and AX3 Account screenshots/scroll; Profile full-row navigation and semantic selectors; content size reset; audit/diff/context/preflight.
Result: Customer Account is separate from Profile editing and composes shared page, section, grouped-surface, settings-row, and danger-action contracts. Identity, Profile, Privacy/Support, DEBUG, and Account Access retain behavior and expose complete row labels/taps without AX3 clipping.
Risks: AuthenticatedAccountView remains a role-fallback surface as before; its release rows now share presentation with Customer Account, while Customer-specific Profile Store ownership remains only in CustomerAccountView. No backend/auth mutation was exercised during visual QA.
Next: Use T-312 for Q-120 first-slice integration gate.
```

```text
Date: 2026-07-12
Task: T-310 - Q-118 Customer Request Wizard migration.
Files changed: Wizard semantic/adaptive presentation, Accessibility 3 layout contract tests, UI audit baseline, and roadmap/task/memory closeout.
Checks: strict RED with 24 errors then GREEN; test-interface RED then GREEN; baseline prune 27; full iOS tests; iOS build/build-run; default and AX3 Pet/Service/Time screenshots, navigation/selectors, date/time/location controls; content size reset; audit/diff/context/preflight.
Result: Wizard uses semantic page/field/action/selection contracts and shared ButtonStyles, with no local ButtonStyle, low scale factor, direct platform font, local shadow, or negative page compensation. Header, service cards, Time Window, Review rows, and bottom actions reflow without horizontal clipping at AX3; behavior and data paths remain intact.
Risks: The seeded Customer Profile address was not currently confirmed, so live traversal correctly stopped at Time & Location rather than bypassing validation or writing remote data. Details/Review remain covered by existing full tests plus strict-clean adaptive code, but were not reached in this Simulator run.
```

```text
Date: 2026-07-12
Task: T-309 - Q-117 Customer Requests migration.
Files changed: Shared semantic page title; Requests page/card/section/action adaptive migration; Bookings title caller; UI audit baseline; roadmap/task/memory closeout.
Checks: strict RED then GREEN for both Requests files; baseline prune 7; repository UI audit; full iOS tests; iOS build and build-run; default and Accessibility 3 active/cancelled Simulator snapshots and selector checks; content size reset; diff/context/preflight.
Result: Requests now uses semantic page insets, title/type/section/action contracts and one canonical card elevation. Header/chip, card copy, actions, and closed rows reflow at Accessibility 3 without low scaling or truncation while Store calls, cancellation, detail, paging, handoff, republish, and selectors remain unchanged.
Risks: Seed data exposed active and cancelled states only; empty and booking-handoff branches retain their existing tested behavior but were not visually manufactured through backend writes. Two reviewed Home UI101 fixed-width warnings remain outside this strict-clean Requests surface.
```

```text
Date: 2026-07-12
Task: T-308 - Q-116 Customer Home migration.
Files changed: Customer Home semantic migration; mechanically extracted Pet Form; UTF-16 scanner and guarded partial-relocate fix/tests; baseline, audit governance, roadmap/task/memory closeout.
Checks: strict RED with 22 errors then strict GREEN; mechanical relocate 4 and prune 26; audit tests 12/12; iOS build/tests; default and Accessibility 3 Simulator snapshots/scroll; content size reset; UI audit; diff/context/preflight.
Result: Home uses semantic insets/sections/type/action contrast, bounded decorative overlays, and width-constrained but height-flexible Pet Cards. Header/Hero/Pets/empty Next Booking reflow without overlap at AX3; Stores, repositories, routes, selectors, image behavior, and copy remain intact.
Risks: Q-117 subsequently resolved the Active Request Accessibility 3 truncation. Two reviewed UI101 warnings remain for the intentional 172pt horizontal card column width.
```

```text
Date: 2026-07-12
Task: T-307 - Q-115 shared semantic components and catalog.
Files changed: New layout, selection, and DEBUG catalog primitives; action/form/feedback compatibility updates; contract/audit tests; design, roadmap, task, and memory closeout.
Checks: Forced compile RED for missing action availability; audit fixture 10/10; full iOS tests; iOS build; Xcode Canvas default and Accessibility 3 rendering at 100%; UI consistency audit; diff/context/preflight.
Result: DesignSystem now owns focused page, section, grouped, selection, settings, field, and action presentation contracts. Primary actions can render unavailable while preserving feature-owned tap handling; old APIs remain source-compatible.
Risks: Components are presentation-only and gain production usage in Q-116...Q-119. The catalog is DEBUG-only with static content and no repository/navigation route.
```















































This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.
