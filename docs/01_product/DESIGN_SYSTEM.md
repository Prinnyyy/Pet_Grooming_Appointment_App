# Design System

This is the active design-system contract for current UI work. Keep it as a short source of current rules, not a history of the completed Beckon implementation phase.

Full pre-slim text, including T-023 through T-035 task history and detailed component tables, is archived at `../09_frozen/design_notes/DESIGN_SYSTEM_2026-07-02_PRE_SLIM.md`.

## Role

Use this file when changing visual style, shared SwiftUI primitives, tokens, or screenshot-driven UI. For detailed prototype audit notes, read `../08_design/UI_IMPLEMENTATION_NOTES.md` first and open frozen archives only with a specific comparison or recovery reason.

Executable Feature-code rules, audit commands, baseline lifecycle, severities, and the narrow exception contract live in `../04_ios/UI_CODE_GOVERNANCE.md`.

Do not use design work to change product flow, role routing, repository boundaries, Supabase contracts, RLS/RPC behavior, Storage policy, or deferred feature scope.

## Visual Direction

- Friendly, calm, pet-focused marketplace UI.
- Warm off-white app backgrounds and soft white cards.
- Thin warm-gray borders, low-contrast shadows, rounded cards, pills, inputs, and bottom sheets.
- Mint/teal customer primary actions and progress states.
- Coral groomer/accent actions.
- Clear status chips and explicit loading, empty, error, selected, disabled, and success states.
- Native SwiftUI/SF typography with Dynamic Type support.

Avoid dense dashboards, map-first layouts, oversized calendars, decorative animation, and one-off raw colors or spacing in feature views.

R-039 applies this foundation with role-adaptive density: Customer remains pet/decision oriented, while Groomer becomes schedule/action oriented. Groomer operational lists use grouped surfaces and row separators rather than one raised card per row. The approved contract and targets live in `../08_design/GROOMER_UI_REDESIGN.md`.

## Current Sources

- Swift tokens: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift`
- Action primitives: `DesignSystem/BeckonActionPrimitives.swift`
- Feedback primitives: `DesignSystem/BeckonFeedbackPrimitives.swift`
- Form primitive: `DesignSystem/BeckonFormPrimitives.swift`
- Feature fallback: `DesignSystem/FeaturePlaceholderView.swift`
- Extracted token source: `../08_design/design_tokens.json`
- Screen inventory: `SCREEN_INVENTORY.md`
- Visual audit summary: `../08_design/UI_IMPLEMENTATION_NOTES.md`
- Approved Groomer redesign: `../08_design/GROOMER_UI_REDESIGN.md`
- Remaining UI debt: `../04_ios/UI_CONSISTENCY_DEBT.md`

## Token Rules

Use semantic tokens from `DesignTokens` before adding a new value.

Current token groups include:

- Colors: background, raised surface, border, divider, primary/secondary/tertiary text, customer/groomer action states, status fills, AA status text, and notification unread.
- Layout: semantic page, section, surface, row, field, and action-area insets on the approved grid.
- Metrics: minimum touch target, field/action height, and settings icon slot.
- Spacing: compatibility aliases for existing compact through large gaps; new feature work uses semantic Layout roles.
- Shape: card, button, input, bottom sheet, chip, and circular shapes.
- Shadow: one canonical soft-card elevation plus customer/groomer action elevations; small-card and carousel-card names are temporary compatibility aliases.
- Typography: page title, section title, card title, body, supporting, field label, status, and action roles using SwiftUI semantic styles. Legacy large-title/title/headline/caption names remain only until audited usage reaches zero.

New tokens must be introduced through `DesignTokens`, then reused by shared primitives or feature screens. Do not scatter raw Beckon hex colors, radii, shadows, or spacing through feature views.

## Component Rules

Implemented primitives:

- `BeckonPrimaryButtonStyle`
- `BeckonSecondaryButtonStyle`
- `BeckonSection` and compatibility `BeckonSectionHeader`
- `BeckonGroupedSurface`
- `BeckonSelectionCard`
- `BeckonSettingsRowLabel`
- `BeckonFieldGroup`
- `BeckonCard`
- `BeckonStatusChip`
- `BeckonErrorBanner`
- `BeckonLoadingView`
- `BeckonEmptyState`
- `BeckonSectionHeader`
- `.beckonFormField()`

Use `.beckonPageInsets(bottom:)` for standard page geometry. `BeckonRoleAccent` maps Customer, Groomer, and neutral presentation without owning feature navigation or business semantics. `BeckonComponentCatalog` is DEBUG-only and previews default, disabled, selected, invalid, loading, empty, and error states at default and Accessibility 3 sizes.

These primitives own only presentation. Calling screens still own validation, loading state, duplicate-submit prevention, retry actions, navigation, data fetching, and business mutations through existing Store/repository boundaries.

Customer Home, Requests, Request Wizard, and Account are the first completed semantic reference slice. They use the token/component contracts above, pass the strict source gate, and reflow through Accessibility 3; future migrations should reuse these contracts without treating any one page as a universal layout.

## UI Design Rules (UI-R1..R8)

- **UI-R1 Component organisms:** A UI pattern used on two or more screens becomes a named `DesignSystem/` primitive with required and optional elements plus applicable default, loading, disabled, error, empty, and selected states. Feature views compose primitives instead of rebuilding recurring modifier stacks.
- **UI-R2 Semantic typography:** Use `DesignTokens.Typography` semantic styles for all feature text. Express hierarchy through semantic style and weight, not ad hoc sizes; do not add `Font.system(size:)` in feature code. Existing fixed-size sites are migration work, not precedent.
- **UI-R3 Reserved accents:** A screen has at most one visually primary action pattern in its role accent: mint for Customer and coral for Groomer. Accent means action, not decoration or status. Repeated equivalent card actions count as one pattern.
- **UI-R4 Semantic color and contrast:** Feature code references semantic color roles only. New foreground/background pairs require measured contrast of at least 4.5:1 for normal text or 3:1 for large text and meaningful UI graphics. Use only the approved pairs below.
- **UI-R5 Token spacing and shape:** Keep the 4pt grid, existing spacing/radius tokens, and 20/24pt screen padding. Introduce new values through `DesignTokens` before reuse.
- **UI-R6 Content-first depth:** Let pet, portfolio, and groomer photography lead relevant cards. Use one soft elevation tier with quiet borders and shadows. Groomer operational screens retain R-039 grouped-list density rather than raised card stacks.
- **UI-R7 Complete async states:** Every async surface provides loading, empty, error, and success presentation through shared primitives. Empty states identify the next available action; spinners and dead-end empty states are insufficient.
- **UI-R8 Screen archetypes:** Classify each screen as `List/Feed`, `Detail`, `Wizard`, `Thread`, `Editor`, or `Workspace (segmented)`. Follow a consistent title, primary-action, grouping, and accessibility contract for that archetype.

Approved light-palette color pairs:

| Foreground | Background | Rule |
|---|---|---|
| `textPrimary #232323` | surface or app background | Approved for primary text. |
| `textPrimary #232323` | mint, mintDark, coral, or coralDark | Approved for accent actions; dark foreground is required. |
| `textPrimary #232323` | success, warning, or error fill | Approved for status chips; pair color with text or an icon. |
| `textTertiary #69717A` | surface or app background | Approved. |
| `textSecondary #6F767E` | surface | Approved; do not use on app background for normal-size text. |
| `successText #37744E` | surface | Approved and implemented AA success body text. |
| `warningText #8F6800` | surface | Approved and implemented AA warning body text. |
| `errorText #B4474C` | surface | Approved and implemented AA error body text. |

Banned pairs:

- White text on mint, mintDark, coral, or coralDark.
- Success `#6CBF84`, warning `#F2B84B`, or error `#E56B6F` as normal body text on a surface; use the corresponding `*Text` role after its token is implemented.
- `textSecondary #6F767E` as normal-size text directly on app background `#FAF7F2`; restrict it to surfaces or use a future AA-adjusted semantic value.
- Any unmeasured raw foreground/background combination in feature code.

Dark mode remains out of scope. These rules govern the current light palette and preserve semantic role names so a future palette can change values without rewriting feature layouts.

## Accessibility Groundwork (A11Y-R1..R10)

- **A11Y-R1 Dynamic Type:** Use semantic text styles and content-sized containers. Do not fix text heights or truncate informational text to one line unless its full value is available elsewhere. Prefer reflow with stacking, `ViewThatFits`, or `isAccessibilitySize`. `minimumScaleFactor` is not an overflow strategy; allow values of 0.85 or greater only for genuinely fixed chrome with a justification comment. Each UI slice must pass AX3 (`.accessibility3`).
- **A11Y-R2 Touch targets:** Interactive elements are at least 44x44pt. Button and chip primitives provide the minimum floor; list rows use full-row hit areas such as `contentShape` rather than a glyph's natural size.
- **A11Y-R3 Contrast:** Enforce UI-R4's approved pair table. Status fills/icons use dark foregrounds, while body text uses the AA `successText`, `warningText`, and `errorText` roles. Never communicate status through color alone.
- **A11Y-R4 Labels and identifiers:** Every interactive element and informative image has a human, model-derived accessibility label. `accessibilityIdentifier` remains TestOps-only and never substitutes for a VoiceOver label.
- **A11Y-R5 Grouped reading:** Composite cards and rows read as one coherent element using combined children where appropriate; expose secondary controls as accessibility actions instead of forcing users through fragmented swipes.
- **A11Y-R6 Headings:** Shared section headers expose the header trait, and page titles use native navigation titles so VoiceOver rotor heading navigation works consistently. Primitive implementation remains follow-up code work.
- **A11Y-R7 Async announcements:** Shared feedback primitives announce meaningful success, failure, confirmation, and refresh outcomes. Centralized announcement posting remains follow-up code work; new screens must not introduce silent async outcomes.
- **A11Y-R8 Images:** Hide decorative images from accessibility. Informative pet, portfolio, and avatar images use model-derived labels, and image meaning is also available in text where needed.
- **A11Y-R9 Reduced motion:** Custom motion routes through a shared helper that reduces to opacity or no animation when Reduce Motion is enabled. Motion never carries meaning by itself; helper implementation remains follow-up code work.
- **A11Y-R10 Per-slice Definition of Done:** Every UI slice completes the checklist in `../06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`; accessibility is verified incrementally instead of deferred to a broad retrofit.

## Keyboard-Aware Form Contract

Apply this contract to scrolling forms and editors. The shared geometry source is `BeckonKeyboardFormLayout` in `DesignSystem/BeckonFormPrimitives.swift`.

- Focus targets represent the complete semantic field group: its visible label or title, the full input control, and immediate validation text when practical. Do not scroll only the text cursor into view.
- Treat the keyboard as a measured occlusion boundary. If the complete focused group is already visible inside that boundary plus `DesignTokens.Layout.fieldSpacing`, perform no programmatic scroll.
- When an edge is obscured, reveal only the nearest hidden top or bottom edge plus semantic clearance. A group taller than the usable viewport uses the edge requiring less movement so repeated geometry updates cannot make it oscillate. `ScrollViewReader` must allow normal content-bound clamping: the rule is "move only as much as needed and as far as naturally reachable."
- Keyboard overlap adds scroll clearance for form content. It must not become arbitrary negative padding, a guessed offset, or a second source of safe-area truth.
- Page-level actions such as Back, Continue, Save, or Publish retain their original page position and may be covered by the keyboard. They must not automatically become a floating keyboard toolbar. A send/reply control whose sole purpose is text entry is an input accessory and may track the keyboard.
- Native SwiftUI fields and UIKit-backed representables publish focus through the same field-group target contract. Attach stable IDs to the label-plus-control container, and keep representable focus callbacks at the shared component boundary.
- Preserve Dynamic Type, VoiceOver order, safe areas, interactive keyboard dismissal, long text, and native focus behavior. Do not use a fixed input height that clips dynamic text.

Use `BeckonKeyboardFormLayout` for visibility decisions and `.beckonKeyboardFocusTarget(_:)` on complete semantic groups. A feature may own field IDs, scroll orchestration, and business validation, but it must not redefine keyboard geometry policy or introduce a screen-percentage anchor.

## Screenshot Rework Rules

Future Beckon UI work is screenshot-driven. Start from `../06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`, then map each visible module to `SCREEN_INVENTORY.md`, existing SwiftUI files, and existing Store/repository/model owners.

Classify each module before editing:

- `visual-only`: style existing state.
- `existing-feature rewire`: connect a new visual module to existing app state and backend contracts.
- `reusable UI primitive`: add a pure design-system helper only when it removes real duplication.
- `new feature`: stop and request approval before adding persistence, schema, RLS, RPC, Storage behavior, repository contracts, navigation models, role capabilities, or deferred product behavior.

Product correctness and accessibility take priority over visual matching when a prototype or screenshot conflicts with the implemented app.

## Hard Rules

- Never use color alone to communicate status.
- Buttons must expose disabled/loading state and prevent duplicate submissions.
- Images need useful accessibility labels unless decorative.
- Reuse shared primitives before creating feature-local variants.
- Preserve the Open Request -> Groomer Offer -> Customer Confirmation -> Booking model.
- Keep primary tab bars to five destinations; feature editors hide the tab bar and expose one navigation back action.
- Keep dark-mode changes, new brand assets, public groomer directory, direct booking, payments, attachments, maps/calendar, admin tools, and push behavior beyond the approved T-153/T-157 notification scope out of scope unless explicitly requested.
