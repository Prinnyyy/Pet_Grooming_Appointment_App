<!-- task-artifact
task: T-429
status: completed
type: plan
-->

# Handoff 4 P1 — foundations and shared kit

Scope: P1 only, requested 2026-11-01. Read order: handoff section 0, section 6; P1 reads section 3 items 1, 13, 14, 15, 17; section 4 D1/D9; appendix A P1, D, E. Section 10 owns the report. Source is the user-owned `CLAUDE_sandbox/CLAUDE_CODEX_HANDOFF_4.md`; do not edit it or `FlowSandbox/Prototype/**`.

- [x] Diff twins, retain production plumbing, adopt named P1 primitives/tokens.
- [x] Add role trait/carrier and presentation wrappers; enforce presentations carrying role.
- [x] Integrate failed Load more at the two customer call sites and shared needs-card strip/action height.
- [x] Update decisions/spec/audit, add focused role/layout/behaviour evidence, validate at package end.
- [x] Complete section-10 report below and scoped Git delivery.

D1: choose bridged UIKit trait with presented-controller carrier. D9: semantic tokens and documented shared kit additions; no broad baseline exemption. D2/D3 remain unanswered and unchanged. P2–P8 and T-428 are not executed in this session. The caller's one-package boundary and package-end validation override the skill's broader task loop; existing Current State and this report replace extra ledgers/workspaces. Subagents disabled; perform final self-review.

## Section 10 — package report

### Ported, file by file

Source root: `ios/Beckon/Beckon/FlowSandbox/Prototype/`; destination root: `ios/Beckon/Beckon/`. Prototype files remain unedited. Names below omit `.swift`.

| Production file | Prototype twin / adopted change |
|---|---|
| `DesignSystem/BeckonRole` (new) | `DesignSystem/PrototypeBeckonRole`: trait/environment bridge, presented-controller carrier, sheet/cover wrappers; add optional onDismiss to preserve production callbacks; omit swatches/previews |
| `DesignSystem/DesignTokens` ⚑ | `DesignSystem/PrototypeDesignTokens`: dynamic accents, coral hero/scene, named metrics, Ledge.room; retain all production launch/layout/type tokens |
| `DesignSystem/BeckonLedge` | `DesignSystem/PrototypeBeckonLedge`: highlight surface and constant button room |
| `DesignSystem/BeckonFootNote` (new) | `DesignSystem/PrototypeBeckonFootNote`: warm/calm footer with accessibility reflow |
| `DesignSystem/BeckonFeedbackPrimitives` | `DesignSystem/PrototypeBeckonFeedbackPrimitives`: only StateStrip and ErrorBanner; retain production feedback center and error/retry contracts |
| `DesignSystem/BeckonActionPrimitives` | `DesignSystem/PrototypeBeckonActionPrimitives`: failed Load more; reserve both labels' layout footprint so AX3 retry does not grow the control |
| `DesignSystem/BeckonExpressiveComponents` | `DesignSystem/PrototypeBeckonExpressiveComponents`: heading detail and muted date; keep countdown primitive |
| `DesignSystem/BeckonExpressiveIllustration` | `DesignSystem/PrototypeBeckonExpressiveIllustration`: showsPup; retain production task cancellation, scene/ancestor visibility and landing reset |
| `DesignSystem/BeckonWhen` | `DesignSystem/PrototypeBeckonWhen`: day/start only; retain required service timezone |
| `DesignSystem/BeckonJourney` | `DesignSystem/PrototypeBeckonJourney`: groomer paths, status/attention/waiting bubbles, shared dots; keep production motion gating |
| `DesignSystem/BeckonTabIcons` ⚑ | `DesignSystem/PrototypeBeckonTabIcons`: Requests/Schedule path art only; retain UIKit bitmap renderer |
| `DesignSystem/BeckonTabBarOwner` (new) | `DesignSystem/PrototypeBeckonTabBarOwner`: owner and page hider; no demo, tab reset or shell integration (P2) |
| `DesignSystem/DesignDialog` | `DesignSystem/PrototypeDesignDialog`: role carrier only; keep sequencing and cancellation; no D2 wording changes |
| `DesignSystem/DesignKit` ⚑ | `DesignSystem/PrototypeDesignKit`: FactRow tone only; retain lazy/action-capable navigation tiles and DesignBlockHeader |
| `Features/Customer/Notifications/CustomerNotificationsView` ⚑ | corresponding `PrototypeCustomerNotificationsView`: failed Load more with existing id; preserve typed notification routing |
| `Features/Customer/Requests/CustomerRequestOffersView` ⚑ | corresponding `PrototypeCustomerRequestOffersView`: failed Load more; retain sorting, current proposal validity, first-load errors; retain distinct refresh failure and refresh stale cursor on retry |
| `Features/Customer/Requests/CustomerRequestPetAndService` | corresponding prototype pet/service choices: remove two obsolete selected-only padding compensations after adopting constant Ledge.room; existing long-pet geometry test caught the duplication |
| `Features/Customer/Grooming/GroomingDetailParts` | corresponding `PrototypeGroomingDetailParts`: StateStrip in NeedsCard and equal booking action heights only |
| `Features/Customer/Discovery/CustomerGroomerDiscoveryView` ⚑ | corresponding `PrototypeCustomerGroomerDiscoveryView`: sheet wrapper only |
| `Features/Customer/Discovery/GroomerProfileView` | corresponding `PrototypeGroomerProfileView`: cover wrapper only |
| `Features/Customer/Favorites/CustomerFavoriteGroomersView` | corresponding `PrototypeCustomerFavoriteGroomersView`: sheet wrapper only |
| `Features/Customer/Grooming/CustomerGroomingView` ⚑ | corresponding `PrototypeCustomerGroomingView`: two sheet wrappers only |
| `SharedFeatures/Address/BeckonAddressEditor` | corresponding `PrototypeBeckonAddressEditor`: item sheet wrapper only |

Production presentations moved/expanded after the prototype snapshot: also replace native sheets in `Features/Customer/Home/CustomerHomeView` ⚑, `Features/Customer/Grooming/GroomingNavigation`, `Features/Auth/AuthenticatedEntryView`, `Features/Bookings/BookingsView`, `Features/Groomer/Profile/GroomerProfileManagementView`, `Features/Groomer/Profile/GroomerAvailabilityEditorView`, and the owned `Features/Customer/Pets/CustomerPetsFlowSandbox`. These are wrapper-only substitutions preserving contents, bindings, callbacks, validation and routing. No groomer page redesign or timing-buffer code change.

### Production retained and decisions

D-068 records handoff items 1/13/14/15/17 and D1/D9. Named ⚑ twins were diffed before edits: TabIcons keeps T-423's UIKit rendering; DesignTokens keeps startup/layout additions; DesignKit keeps production destination/action plumbing; discovery/Grooming/notifications/offers keep current navigation and Store behaviour. Home's only change is its presentation method. CustomerNavigation and ChatView are untouched, preserving T-423 and T-426/T-427. No prototype fixture, preview helper, tab-generation reset or thread skeleton is ported.

Customer-visible effects are documented in LIVELY_UI_SPEC: error strip card, in-place pagination retry, fixed 6pt button room, 58pt quiet booking/request action, shared Grooming needs strip. A full refresh failure with existing offers remains visible rather than disappearing with the retired pagination error box. New raw geometry uses semantic tokens; no new baseline exemption.

### Tests and checks

Added `RoleKitTests`: all 15 dynamic tokens under both roles; actual presented groomer sheet trait/environment and no presenter role leak; preserved onDismiss; action/chip/pagination heights at default and AX3 for both roles; When day/start and invalid/missing service timezone. Extended `DesignTokenAccessibilityTests` for coral hero/scene contrast. Extended audit tests for bare presentation rejection without matching comments/strings/wrappers.

Package-end evidence:

- `./scripts/ios-build.sh`: passed (Simulator Debug, both architectures). Existing prototype/pet-form concurrency warnings were observed; those sources are preserved.
- `./scripts/ios-test.sh`: 957 total, 907 passed, 47 opt-in skipped, 3 initially failed. The failures were the old selected-only spacing, an incorrect decorative-lip contrast assertion, and the new role test sampling its environment only at onAppear. The latter now observes initial and subsequent role changes, retaining its actual presented-controller, presenter-isolation and onDismiss assertions.
- After those corrections, one targeted Xcode run of `RoleKitTests`, `CustomerRequestWizardLayoutTests`, `DesignTokenAccessibilityTests`, `ExpressiveTokenTests`: **18/18 passed**, zero skips. Reuse all unaffected integrated results; do not rerun the full suite. Evidence bundles: `Test-Beckon-2026.11.01_20-46-39--0800.xcresult` in the standard DerivedData Logs/Test directory, and `/tmp/beckon-t429/focused.xcresult`.
- `./scripts/preflight.sh`: passed. New audit initially broke explicit-file relocate in its fixture; fixed shared discovery to run only for normal repository scans. `node --test tests/scripts/ui-consistency-audit.test.mjs`: **20/20 passed**. `node scripts/ui-consistency-audit.mjs check`: passed, no new baseline exemption; UI018 bare presentation count is zero.
- `node --test tests/ios/*.test.mjs`: **26/26 passed**. Final document hygiene and diff whitespace check run at closeout.

No additional manual screenshot campaign, spoken VoiceOver walkthrough or visual approval claimed; existing integrated tests supply runtime evidence and user performs visual inspection. No remaining technical blocker for P1. A self-review checked named twin diffs, preservation of current navigation/launch/chat, scope boundaries, error-source handling, retired id, unchanged private/backend access and absence of prototype fixture imports.

### D1–D10 disposition / limits

| Question | P1 disposition |
|---|---|
| D1 | Choose trait bridge + carrier and wrapper audit; supported by [Apple's UIKit trait/environment bridge](https://developer.apple.com/documentation/uikit/uitraitbridgedenvironmentkey). Groomer shell role selection belongs to P2 |
| D2 | Not answered; no timing-buffer removal, SQL, Availability module removal or related dialog wording begun. Ask explicitly before dependent P4/P6/P7 work, including the Auto-ready question |
| D3 | Not answered; no manual-tab policy change, generation identity reset or path reset begun. Ask explicitly before P2 |
| D4 | Booking snapshot fields/permission: not decided or implemented; P4 |
| D5 | Coming-up source and paused route: not decided or implemented; P2 |
| D6 | Match/offer stage semantics: not implemented; P3 |
| D7 | Only P1 adopted now. T-428 remains planned and unexecuted; decide order before P2's overlapping groomer work |
| D8 | Retain T-426/T-427; no chat loading changes in P1 |
| D9 | Adopt shared primitives and semantic metrics under D-068, update spec and UI018; no blanket baseline additions |
| D10 | Role wording: unchanged; P6 |

P2–P8 remain outside this session. `beckonCustomerDesign` remains until P8. No real device, signing, remote database operation or credential access was required. Final review is self-review because repository instructions disable subagents. User-owned governance/signing and both prototype trees are preserved.
