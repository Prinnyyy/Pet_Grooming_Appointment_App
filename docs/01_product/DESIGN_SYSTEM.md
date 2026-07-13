# Design System

Canonical routing and core visual contract for Beckon UI work. Detailed accessibility and form behavior live in focused, on-demand files rather than this default entry.

Pre-routing source snapshot: `../09_frozen/design_notes/T-347_2026-07-13/DESIGN_SYSTEM.md`.

## Read Path

- Always start here for visual style, shared SwiftUI primitives, tokens, or screenshot-driven UI.
- Add `ACCESSIBILITY_RULES.md` when changing user-visible UI, controls, images, text, status, or async feedback.
- Add `FORM_INTERACTION_RULES.md` only for text entry, focus, keyboard avoidance, scrolling editors, or sheet gestures.
- Use `../08_design/UI_IMPLEMENTATION_NOTES.md` to locate current screenshots and design evidence.
- Use `../08_design/GROOMER_UI_REDESIGN.md` only for deferred Groomer Q-104 or a focused R-039 regression.
- Use `../ui-redesign/README.md` only when an explicit Figma/inventory task requires the heavy redesign evidence package.

Executable Feature-code rules and audit commands live in `../04_ios/UI_CODE_GOVERNANCE.md`. Product flow, role routing, repositories, Supabase, RLS/RPC, Storage, and deferred features are outside this contract.

## Visual Direction

- Friendly, calm, pet-focused marketplace UI with warm off-white pages and white surfaces.
- Customer uses mint/teal action roles; Groomer uses coral action roles.
- Clear hierarchy, quiet borders/shadows, content-led imagery, and explicit loading, empty, error, selected, disabled, and success states.
- Customer remains pet/decision oriented. Groomer remains schedule/action oriented and uses grouped surfaces with row separators rather than card stacks.
- Native SwiftUI/SF typography and semantic Dynamic Type styles are required.

Avoid dense dashboards, map-first layouts, oversized calendars, decorative animation, nested cards, and raw feature-local color, spacing, radius, shadow, or font values.

## Sources And Ownership

- Swift tokens: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift`
- Shared primitives: `ios/Beckon/Beckon/DesignSystem/`
- Extracted prototype tokens: `../08_design/design_tokens.json` (reference only)
- Screen ownership: `SCREEN_INVENTORY.md`
- Remaining source debt: `../04_ios/UI_CONSISTENCY_DEBT.md`

Use semantic `DesignTokens` roles before adding a value. New values enter `DesignTokens` first and must serve repeatable semantics. Shared primitives own presentation; feature Stores and repositories retain validation, loading, retry, navigation, and business mutations.

Reuse implemented primitives such as action styles, `BeckonSection`, `BeckonGroupedSurface`, selection/card/status/feedback primitives, settings rows, field groups, location-mode presentation, and `.beckonFormField()`. Add a new primitive only when a pattern recurs or a shared contract genuinely removes complexity.

## UI Design Rules (UI-R1..R8)

- **UI-R1 Component organisms:** A pattern used on two or more screens becomes a named `DesignSystem/` primitive with applicable default, loading, disabled, error, empty, and selected states.
- **UI-R2 Semantic typography:** Feature text uses `DesignTokens.Typography`; hierarchy comes from semantic style and weight, never new `Font.system(size:)` sites.
- **UI-R3 Reserved accents:** A screen has at most one role-accent primary-action pattern. Accent communicates action or selection, not decoration or status.
- **UI-R4 Semantic color and contrast:** Feature code uses semantic color roles and only approved foreground/background pairs from `ACCESSIBILITY_RULES.md`.
- **UI-R5 Token spacing and shape:** Keep the 4pt grid and established semantic insets, spacing, radii, and control metrics. Introduce reusable values through tokens first.
- **UI-R6 Content-first depth:** Let relevant pet, portfolio, and Groomer imagery lead. Use one quiet elevation tier; operational lists remain grouped rather than card-heavy.
- **UI-R7 Complete async states:** Every async surface provides truthful loading, empty, error, and success presentation with a useful next action or retry.
- **UI-R8 Screen archetypes:** Classify screens as List/Feed, Detail, Wizard, Thread, Editor, or Workspace and follow a consistent hierarchy/action/accessibility contract for that archetype.

## Screenshot Rework

Start with `../06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`. Map visible modules to current screens, Stores, repositories, and models before editing. Classify each as visual-only, existing-feature rewire, reusable primitive, or new feature. Stop for approval before persistence, schema, backend, navigation, role capability, or deferred product changes.

## Hard Rules

- Never communicate status through color alone.
- Buttons expose disabled/loading state and prevent duplicate submissions.
- Images have useful accessibility labels unless decorative.
- Reuse shared primitives before adding feature-local variants.
- Preserve the Request -> Offer -> Acceptance -> Booking/Chat -> Completion -> Review lifecycle.
- Keep primary tab bars to five destinations; feature editors hide the tab bar and expose one back action.
- Dark mode, new brand assets, public Groomer discovery, direct booking, payments, attachments, maps/calendar expansion, admin tools, and new push behavior remain out of scope unless explicitly approved.
