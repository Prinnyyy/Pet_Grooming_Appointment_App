# UI Design Rules Proposal — Reference Deconstruction + Accessibility Groundwork

- Status: non-canonical external review input (Claude). Review/analysis only; no project files were changed.
- Date: 2026-07-10. Baseline: branch `codex/pet-fit-structure-cleanup`, after T-257; `T-258` is reserved for Q-104.
- Consumption convention (T-150/T-151 pattern): add `UI_DESIGN_RULES_PROPOSAL.md` to `.gitignore` and `.rgignore`, archive under `docs/09_frozen/external_agent_reports/` when consumed.
- This report does not reset branch, task ID, validation, or product status. Task numbers below are proposals keyed to the ledger's next available ID.

## 1. Reference selection: Airbnb DLS

Requirement: an app in a similar category that has **already been publicly deconstructed** — not a fresh teardown.

Category scan result: pure pet-category or salon-booking apps (Rover, Booksy, Fresha, StyleSeat) have screenshot libraries and business comparisons, but **no deep public deconstruction** of their design systems. Airbnb is the closest structurally matching app with the deepest public deconstruction record: the original DLS articles by its design team, multiple independent third-party breakdowns (including a 2026 one), and an engineering post-mortem on retrofitting Dynamic Type — which is precisely the "accessibility big-rework" scenario this proposal exists to prevent.

Structural isomorphism (why Airbnb transfers to Beckon):

| Airbnb | Beckon |
|---|---|
| Guest / Host dual roles in one app | Customer / Groomer immutable role separation |
| Request to Book → host accepts → reservation | Open Request → Groomer Offer → Customer Confirmation → Booking |
| Photo-led listing card (image, price, rating) | Pet card, groomer offer/profile card, portfolio gallery |
| Reservation-scoped messaging thread | Conversation per booking participants |
| Post-stay review | Customer review after completion |
| Host workspace density vs guest browse density | R-039 role-adaptive density (Customer decision-oriented, Groomer schedule/action-oriented) |

Deconstruction sources used:

1. Karri Saarinen, "Building a Visual Language" / "Creating the Airbnb Design System" — https://karrisaarinen.com/posts/building-airbnb-design-system/ (canonical first-party DLS account)
2. Superdesign, "How Airbnb Designs Their UI: A Design System Breakdown" (2026) — https://superdesign.dev/blog/airbnb-design-system
3. DesignSystems.one, "Airbnb DLS — Design System Breakdown" — https://www.designsystems.one/design-systems/airbnb-design
4. Noah Martin, "Supporting Dynamic Type at Airbnb," Airbnb Tech Blog — https://medium.com/airbnb-engineering/supporting-dynamic-type-at-airbnb-b47c68b0c998
5. Supplementary screen-pattern reference for category-specific flows (booking/scheduling): Mobbin flow libraries — https://mobbin.com/explore/mobile/flows/booking-reserving and https://mobbin.com/explore/mobile/flows/scheduling

Non-transfers to respect: Airbnb's proprietary Cereal typeface (Beckon correctly uses SF semantic styles), map/search-first surfaces (deferred features), single brand accent (Beckon legitimately uses two role accents — the DLS *principle* "accent = reserved for action" still transfers per role).

## 2. What the deconstruction yields

**Principles:** Unified (no isolated features), Universal (accessible to all), Iconic (bold, focused), Conversational (motion communicates intent).

**Component model:** components are "organisms," not atoms — each has a defined function, **required + optional elements, explicit states and variants**, and can evolve independently. The library is organized by category (Navigation, Marquees, Content, Image, Specialty). Product review then shifts from restyling debates to UX substance.

**Foundations:**
- Typography: one family; hierarchy by **weight and semantic style, not ad-hoc sizes**; every text element maps to a semantic TextStyle.
- Color: vibrant accent **reserved for the primary action**; near-neutral inks elsewhere; restraint over vibrancy.
- Spacing: 4pt base grid (4/8/12/16/24/32/48/64).
- Depth: photography is the hero; minimal chrome; roughly one subtle elevation tier.

**Dynamic Type retrofit lessons (the cautionary tale):**
- ~30% of Airbnb app users had a non-default preferred text size. Enabling Dynamic Type on individual features produced a significant engagement increase.
- Retrofit costs concentrated in: fixed-size text, fixed-height containers, unscaled numeric layout values, custom line-height handling.
- What made it cheap where it was cheap: every text mapped to a TextStyle; containers sized to content; static chrome (tab/nav bars) stays fixed with Large Content Viewer; **snapshot/manual validation at accessibility sizes (AX3+) as a regression gate**.

The meta-lesson: accessibility retrofits are expensive at the **screen** level and cheap at the **token/primitive/process** level. Every rule below is placed at the cheapest enforcement level.

## 3. Beckon baseline (measured 2026-07-10, this branch)

Already aligned with the DLS playbook (keep, formalize):
- Semantic typography tokens backed by SwiftUI text styles (`DesignTokens.Typography`), Dynamic Type–native.
- Restrained warm-neutral palette with two role accents; primary buttons already use dark text on accent (this is the *correct* contrast choice — measured below).
- Spacing tokens on a 4pt grid (4/8/12/16/24) + screen padding 20/24.
- Nine shared primitives with state awareness; grouped-list density for Groomer per R-039.
- Existing hard rules: no color-only status, image labels, explicit loading/empty/error states.
- `dynamicTypeSize.isAccessibilitySize` adaptive layout branching already practiced (e.g. `ChatView`, `BookingsView`).

Measured accessibility API usage (`ios/Beckon/Beckon`):

| API | Files | Hits | Reading |
|---|---|---|---|
| `accessibilityIdentifier` | 35 | 249 | Strong (TestOps) — but identifiers are not VoiceOver UX |
| `accessibilityHidden` | 23 | 80 | Good decorative-image hygiene |
| `accessibilityElement` (grouping) | 19 | 43 | Partial |
| `accessibilityLabel` | 14 | 29 | **Low** vs 249 identifiers |
| `dynamicTypeSize` env reads | 8 | 43 | Good adaptive pattern, no hard caps found |
| `minimumScaleFactor` | 11 | 42 | **Shrink-to-fit crutch** (0.72–0.86); defeats Dynamic Type |
| `Font.system(size:)` fixed sizes | 9 | 29 | **Dynamic Type violations** (list in §7) |
| `lineLimit(1)` | 17 | 65 | Truncation risk at AX sizes |
| `accessibilityValue` / `Hint` | 7 / 1 | 10 / 2 | Sparse |
| `accessibilityAddTraits` (headers etc.) | 2 | 2 | **Near-absent** — no rotor heading navigation |
| `reduceMotion` | 1 | 5 | Single file only |
| `AccessibilityNotification` / `@ScaledMetric` | 0 | 0 | No async announcements; no scaled metrics |

Measured WCAG 2.x contrast of current `DesignTokens` pairs (AA: 4.5:1 text, 3:1 large text/UI):

| Pair | Ratio | Verdict |
|---|---|---|
| textPrimary `#232323` on surface / appBg | 15.7 / 14.7 | PASS |
| textPrimary on mint `#7ECFC0` / coral `#FF9A8B` | 8.7 / 7.7 | PASS — current button fg choice is right |
| textPrimary on mintDark / coralDark (pressed) | 7.2 / 6.4 | PASS |
| textPrimary on success / warning / error fills | 7.1 / 8.8 / 5.0 | PASS — status chips must use dark fg |
| textTertiary `#69717A` on surface / appBg | 5.0 / 4.6 | PASS |
| textSecondary `#6F767E` on surface | 4.6 | PASS |
| textSecondary `#6F767E` on appBg `#FAF7F2` | **4.3** | **FAIL (AA text)** — large-text only |
| white on mint / mintDark / coral / coralDark | **1.8–2.5** | **FAIL — ban white-on-accent** |
| success `#6CBF84` as text on surface | **2.2** | **FAIL** |
| warning `#F2B84B` as text on surface | **1.8** | **FAIL** |
| error `#E56B6F` as text on surface | **3.2** | Large-text only |

AA-passing replacement values (computed, hue-preserving), for text-on-surface status roles:
- `successText #37744E` (5.6:1) · `warningText #8F6800` (5.1:1) · `errorText #B4474C` (5.3:1)
- `textSecondary` → `#68707A` (4.7:1 on appBg) if secondary text ever renders directly on the app background; otherwise restrict the current value to card surfaces.

Gap summary: token *values* mostly sound; the failures are **usage-pair** failures (status colors as text, hypothetical white-on-accent) plus missing VoiceOver semantics (labels, headers, announcements) and Dynamic Type leaks (fixed sizes, scale-factor crutches). All fixable at token/primitive/process level today; expensive per-screen later.

## 4. Proposed UI design rules (UI-R1…R8)

Target home: new "UI Design Rules" section in `docs/01_product/DESIGN_SYSTEM.md`. These formalize the DLS-derived structure on top of existing rules; none change product flow, backend contracts, or R-039 scope.

- **UI-R1 Component-organism rule.** Any UI pattern used on ≥2 screens becomes a named `DesignSystem/` primitive defining its required + optional elements and its **full state set** (default / loading / disabled / error / empty / selected where applicable). Feature views compose primitives; they do not re-derive recurring patterns from raw modifiers.
- **UI-R2 Typography.** All text uses `DesignTokens.Typography` semantic styles. Hierarchy is expressed by style + weight, never by ad-hoc sizes. `Font.system(size:)` is banned in feature code; the 29 existing hits are a tracked migration list (§7), not a precedent.
- **UI-R3 Reserved accent.** Per screen, at most one visually primary action styled in the role accent (mint customer / coral groomer). Accents mean "act," never decoration or status. Repeated-card CTAs (e.g. one accept per offer card) count as one primary action pattern.
- **UI-R4 Color-by-role with a contrast contract.** Feature code references only semantic roles. The approved foreground/background pair table (§3) lives next to `DesignTokens`; any new pair must be measured ≥4.5:1 (text) or ≥3:1 (large text / meaningful UI graphics) before use. Banned pairs are listed explicitly (white on any accent; status hues as text without the `*Text` variants).
- **UI-R5 Spacing and shape from tokens only.** 4pt grid, existing spacing/radius tokens, screen padding 20/24. New values enter through `DesignTokens` first (existing rule, restated as part of this set).
- **UI-R6 Content-first depth.** Photography leads cards (pet, portfolio, groomer identity); one soft elevation tier; borders and shadows stay quiet. Groomer operational surfaces keep R-039 grouped-list density instead of raised card stacks.
- **UI-R7 State completeness.** Every async surface ships loading, empty, error, and success presentation through shared primitives — no silent spinners, no dead-end empties (empty states name the next action).
- **UI-R8 Screen archetypes.** Every screen declares one archetype: `List/Feed`, `Detail`, `Wizard`, `Thread`, `Editor`, `Workspace (segmented)`. Each archetype carries a layout contract (title placement, primary-action placement, grouping style) and the a11y contract in §5. Optionally record the archetype as a column in `SCREEN_INVENTORY.md`.

## 5. Accessibility groundwork rules (A11Y-R1…R10)

Each rule states *where it is enforced* — that placement is what prevents the later big-bang refactor.

- **A11Y-R1 Dynamic Type native (token + process).** Semantic text styles only (= UI-R2). Containers size to content: no fixed heights on text, no `lineLimit(1)` on informational text unless the full content is reachable elsewhere; prefer reflow (`ViewThatFits`, stacking, `isAccessibilitySize` branching — the existing ChatView/BookingsView pattern is the house style). `minimumScaleFactor` is not an overflow strategy; allowed only ≥0.85 on genuinely fixed chrome, with a comment justifying it. Screens must pass at AX3 (`.accessibility3`) as a review gate.
- **A11Y-R2 Touch targets (primitive).** Interactive elements ≥44×44pt. Buttons/chips get the floor from their primitive styles; list rows use full-row `contentShape` hit areas. Never rely on a small glyph's natural size.
- **A11Y-R3 Contrast contract (token).** Adopt §3's approved-pair table and add `successText/warningText/errorText` tokens (values above). Status colors are chip/fill/icon colors with dark foregrounds, never body-text colors. Status is always icon/text + color, never color alone (existing hard rule, kept).
- **A11Y-R4 Labels ≠ identifiers (screen + review).** Every interactive element and informative image has a human `accessibilityLabel`; `accessibilityIdentifier` remains TestOps-only and is never a VoiceOver substitute. Labels come from model data where possible (pet name, groomer name, service), not view internals. Today's ratio (249 identifiers vs 29 labels) is the gap to close slice by slice.
- **A11Y-R5 Card/row grouping (primitive + screen).** Composite cards/rows read as one element (`.accessibilityElement(children: .combine)`) with secondary actions exposed as `accessibilityAction`s — a booking card is "one swipe," not six fragments.
- **A11Y-R6 Heading traits (primitive, one line).** `BeckonSectionHeader` bakes in `.accessibilityAddTraits(.isHeader)`, giving every screen rotor heading navigation system-wide. Page titles use native navigation titles (already headers).
- **A11Y-R7 Async announcements (primitive).** Outcome feedback routes through the shared feedback primitives, which post `AccessibilityNotification.Announcement` (offer submitted, booking confirmed, save failed, list refreshed). Centralizing in `BeckonErrorBanner`/feedback helpers means zero per-screen wiring. Currently 0 usages — VoiceOver users get silent state changes.
- **A11Y-R8 Images (screen).** Decorative images stay `accessibilityHidden` (current practice is good); informative images (pet photos, portfolio, avatars) get model-derived labels; portfolio fit-note detail pairs image + text so meaning never lives in the image alone.
- **A11Y-R9 Motion (token).** One motion helper layer over custom animations that collapses to opacity/none under `accessibilityReduceMotion` (currently honored in 1 file). No meaning conveyed by motion alone. Keeps the existing "no decorative animation" rule enforceable.
- **A11Y-R10 Per-slice Definition of Done (process).** Append to `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` a checklist every UI slice must pass: ① VoiceOver walkthrough (labels, grouping, headings, actions) ② AX3 Dynamic Type pass (no clipped/overlapping/scaled-away text) ③ colors from approved token pairs only ④ 44pt targets ⑤ async outcomes announced ⑥ identifiers intact for TestOps. This converts the future "Accessibility optimization phase" from rework into verification.

Scope guards: dark mode stays out of scope per the existing hard rule — the contrast contract targets the current light palette, and role-based token naming keeps a future dark/increased-contrast variant a value-swap, not a refactor. Nothing above touches product flow, Store/repository boundaries, or backend contracts.

## 6. Why this prevents the big a11y refactor

| Rule placement | Cost now | Cost if deferred to an a11y phase |
|---|---|---|
| Tokens (A11Y-R3, R9; UI-R2, R4) | 3 color values + a pair table + a motion helper | Re-auditing every screen's colors and animations by hand |
| Primitives (A11Y-R2, R5, R6, R7) | ~4 one-point edits in `DesignSystem/` | The same semantics re-implemented on every screen that used the primitive "raw" |
| Process (A11Y-R1 gate, R10 DoD) | One checklist in the task template | Airbnb's scenario: a dedicated retrofit program across the whole app (30% of their users were affected before they acted) |
| Per-screen leftovers (fixed fonts, labels) | Folded into future slices via the DoD | A single monolithic sweep task with high regression risk |

## 7. Integration plan (proposals only — ledger governs)

- **Task A — docs-only (next available ID, e.g. T-259; can run before or after Q-104 without conflict):** add §4/§5 as "UI Design Rules" + "Accessibility Groundwork" sections in `DESIGN_SYSTEM.md`; add the A11Y-R10 checklist to `SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`; add this filename to `.gitignore`/`.rgignore` and archive the report. Validation: context hygiene only.
- **Task B — small code task:** `DesignTokens` additions (`successText/warningText/errorText`, optional `textSecondary` adjustment, motion helper, `minTouchTarget = 44`); primitive baking (SectionHeader header trait, feedback announcement posting, button/chip target floor). Validation: one `./scripts/ios-build.sh`, ideally `./scripts/ios-test.sh`.
- **Not a task:** per-screen migration backlog, absorbed by A11Y-R10 during future slices — fixed `Font.system(size:)` sites: CustomerProfileSettingsView (5), CustomerPetsView (6), AuthenticatedAccountView (5), AuthenticationView (5), CustomerRequestsDashboardView (3), BookingsView (2), CustomerRequestWizardView (1), ChatView (1), BeckonModuleImage (1); plus `minimumScaleFactor` and label-coverage sites from §3.
- Q-104 (T-258) is untouched; if Task A lands first, Q-104's cross-screen pass can adopt the DoD checklist opportunistically.

## 8. Ready-to-use implementation prompt (Task A)

```text
Start a new task from the ledger's next available ID (docs-only; follow SINGLE_AGENT_WORKFLOW).

Goal: adopt the reviewed UI design rules and accessibility groundwork from the external review
report UI_DESIGN_RULES_PROPOSAL.md (repo root; treat as review input only, verify claims against
current code where they matter).

Changes:
1. docs/01_product/DESIGN_SYSTEM.md — add two sections after "Component Rules":
   "UI Design Rules (UI-R1..R8)" and "Accessibility Groundwork (A11Y-R1..R10)", adapted from the
   report's §4 and §5, including the approved/banned color-pair table and the AA replacement
   values (successText #37744E, warningText #8F6800, errorText #B4474C). Keep existing hard rules;
   note dark mode remains out of scope.
2. docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md — append the A11Y-R10 per-slice
   Definition-of-Done checklist (VoiceOver pass, AX3 Dynamic Type pass, approved token pairs only,
   44pt targets, async announcements, TestOps identifiers intact).
3. .gitignore and .rgignore — add UI_DESIGN_RULES_PROPOSAL.md (external report convention), then
   archive the report to docs/09_frozen/external_agent_reports/ per T-150/T-151 convention.
4. Ledger/worklog/current-state entries per workflow; run context hygiene.

Do not change Swift code, tokens, backend, or R-039/Q-104 scope in this task. A follow-up code
task will add the token/primitive changes (report §7 Task B).
```

## Appendix — all sources

- https://karrisaarinen.com/posts/building-airbnb-design-system/ and https://karrisaarinen.com/dls/
- https://medium.com/airbnb-design/building-a-visual-language-behind-the-scenes-of-our-airbnb-design-system-224748775e4e
- https://superdesign.dev/blog/airbnb-design-system
- https://www.designsystems.one/design-systems/airbnb-design
- https://medium.com/airbnb-engineering/supporting-dynamic-type-at-airbnb-b47c68b0c998
- https://mobbin.com/explore/mobile/flows/booking-reserving · https://mobbin.com/explore/mobile/flows/scheduling
- Apple Human Interface Guidelines — Accessibility; WCAG 2.x AA (contrast thresholds used in §3)
