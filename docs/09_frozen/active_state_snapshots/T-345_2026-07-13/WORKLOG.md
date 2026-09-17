# Worklog

```text
Date: 2026-07-13
Task: T-344 - Direct Customer Request Offers entry and action hierarchy.
Files changed: Customer Request card action presentation/layout; dedicated Offers destination; Request Detail Offer ownership removal; focused Customer Request contracts; design spec/implementation plan; task/current-state memory.
Checks: TDD compile RED confirmed the status-backed action presentation did not exist. The first two focused GREEN attempts reached build/signing but stalled before the Simulator test runner because the selected device was shutdown and the deferred execution channel lost process ownership; both Codex-started processes were terminated. After explicitly booting the selected iPhone 17 Pro and retaining a PTY, the focused CustomerRequestsStoreTests completed with TEST SUCCEEDED and both new contracts passed. The standard iOS build passed. Source ownership, diff, and context audits passed. Manual UI/UX review was intentionally not run because visual acceptance is user-owned.
Result: Active Customer Request cards now place equal Detail and Offers actions on the first row and a full-width red/white Cancel Request action on the second row. Offers is gray/disabled for `.open` and Customer green/enabled only for authoritative `.hasOffers`. The dedicated Offers screen owns loading, refresh, pagination, pending/history groups, Offer detail, and acceptance; Request Details no longer renders or loads Offers. Booking handoff and closed-request behavior are unchanged.
Risks: Offer-button availability intentionally trusts the Request status machine instead of issuing eager per-card Offer queries. The existing CustomerRequestsStore reminder-result warning remains assigned to T-340; AppIntents metadata extraction remains toolchain information. No Store, repository, backend, persistence, dependency, or remote state changed.
Next: No automatic follow-up. Use T-345 for the next new task; T-340 remains separately planned.
```

```text
Date: 2026-07-13
Task: T-343 - Shared Customer/Groomer Account architecture and Groomer subtree restyle.
Files changed: Shared Account/layout/settings primitives; Auth and Customer Account adoption; Groomer workspace compatibility layer; Groomer Account, Profile Settings, Services, Portfolio, Availability, Fit Signals, and Evidence presentation; DesignSystem contract test; UI debt baseline/inventory; task/current-state memory.
Checks: TDD compile RED confirmed the Account layout policy did not exist, followed by focused DesignSystem GREEN. Two standard iOS builds and the complete iOS suite passed. The UI audit initially reported 18 stale entries resolved by the shared migration and no new errors; guarded baseline prune then passed at 203 current findings/195 baselined. Shared-usage, removed-private-component, business-boundary, diff, and context audits passed. Manual Simulator/UI review was intentionally not run because visual acceptance is user-owned.
Result: Customer and Groomer now share Account identity, settings navigation, release links, page sections, grouped surfaces, dividers, page insets, and profile-photo editor presentation. Groomer Account no longer owns parallel menu/header/support implementations; its Profile, Services, Portfolio, Availability, Fit Signals, and Evidence pages compose the same shared hierarchy. Legacy Groomer workspace primitives delegate to the shared implementation so remaining Groomer surfaces inherit future shared style changes. Store, repository, Supabase, matching, persistence, and role colors are unchanged.
Risks: Groomer-specific controls and destructive sign-out behavior remain feature-owned where semantics differ, but they compose shared typography/layout tokens. Q-104 Dynamic Type/Accessibility remains deferred. The two app-owned compiler warnings remain assigned to T-340; AppIntents metadata extraction remains toolchain information.
```

```text
Date: 2026-07-13
Task: T-342 - Groomer Profile save RPC null-parameter correction.
Files changed: Shared Customer/Groomer Profile address RPC payload encoder; Profile address integration contract; Feedback auto-dismiss test synchronization; task/current-state memory.
Checks: Structured Debug Console trace isolated `GroomerProfileRepository.updateProfileWithAddress` and `save_groomer_profile_address_v2`; the migration signature, shared encoder, and official Swift RPC reference were compared. The Supabase changelog Markdown URL was rejected by the Web tool as an internal/safety error and was not retried. TDD RED confirmed a missing Place ID was omitted instead of encoded as null, and focused Profile address GREEN passed after the fix. The first full suite then exposed the existing Feedback auto-dismiss fixed-sleep race under MainActor load; its focused compile first caught a missing actor annotation, then passed after correction. The final full iOS suite and iOS build passed. Two initial focused xcodebuild commands were accidentally left running by deferred tool sessions and were terminated before a single controlled RED run.
Result: A nil Apple Place ID is now sent as explicit JSON null, preserving the RPC parameter set required by PostgREST and allowing Groomer Profile saves for confirmed/seeded addresses without a Place ID. Customer Profile receives the same shared correction. The Feedback test now polls the expected state within a bounded deadline without changing production toast duration or behavior.
Risks: No authenticated remote save was performed because non-Git Supabase writes were not authorized; local payload, Store, repository, migration-signature, full-test, and build evidence cover the defect. The AppIntents metadata-skipped warning remains assigned to T-340. No migration, schema, dependency, or remote state changed.
Next: No automatic follow-up. Use T-343 for the next new task; T-340 remains separately planned.
```

```text
Date: 2026-07-13
Task: T-341 - Customer Home request Hero visual restoration and role action colors (checkpoint).
Files changed: Customer Home Hero presentation/layout; shared customer/groomer action foreground tokens and button styles; color contract; focused tests; design spec/plan; task/current-state memory.
Checks: TDD compile RED confirmed missing role tokens, Hero copy, Hero contrast, and finally the four approved global Customer palette roles. Focused palette/DesignSystem tests then passed, followed by the complete iOS suite and iOS build; both complete commands passed again after user visual approval. The earlier full-suite run had failed four Feedback Center timing tests under parallel load, but both final standard runs passed them without code changes in that subsystem. Static source audit found no Feature/primitive use of legacy Customer color names. Final role audit found Groomer Notifications had inherited Customer mint for unread state; it now uses Groomer coral roles and its focused tests pass. The first bulk rename used a zsh scalar containing newline-separated paths, so Perl received one invalid long filename and changed nothing; the rerun used NUL-delimited `rg -0 | xargs -0` and completed safely. Contrast audit found `#333333` on the unchanged full error fill is only 4.01:1; actual StatusChip code already uses `errorText` over a translucent error surface, so the obsolete UI-rule pair was removed without changing status behavior. Earlier command/path errors remain recorded: invalid Swift imports, two unescaped Markdown searches, an over-broad stale-color search, two stale plugin-cache paths, and one overlong Ledger row; each corrected check passed.
Result: The Hero preserves the approved Display P3 treatment, `#333333` copy/action text, shared feature typography, and action-driven copy width. Its palette is now the global Customer contract: `#333333` primary text plus Display P3 accent `#93CEC2`, soft `#B0D8D9`, subtle `#B5DCD9`, and strong `#518B7F`. Shared primitives and Customer/Auth/Booking/Chat call sites use the semantic roles; compatibility aliases remain only in DesignTokens. Groomer, status, surface, and warm-background semantics are unchanged. No Store, navigation, repository, backend, dependency, or remote state changed.
Risks: The existing AppIntents metadata-skipped warning remains assigned to T-340. Q-104 Dynamic Type/Accessibility remains user-deferred.
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

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.
