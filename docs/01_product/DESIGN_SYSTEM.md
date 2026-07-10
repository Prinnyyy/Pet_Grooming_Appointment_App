# Design System

This is the active design-system contract for current UI work. Keep it as a short source of current rules, not a history of the completed Beckon implementation phase.

Full pre-slim text, including T-023 through T-035 task history and detailed component tables, is archived at `../09_frozen/design_notes/DESIGN_SYSTEM_2026-07-02_PRE_SLIM.md`.

## Role

Use this file when changing visual style, shared SwiftUI primitives, tokens, or screenshot-driven UI. For detailed prototype audit notes, read `../08_design/UI_IMPLEMENTATION_NOTES.md` first and open frozen archives only with a specific comparison or recovery reason.

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

## Current Sources

- Swift tokens: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift`
- Action primitives: `DesignSystem/BeckonActionPrimitives.swift`
- Feedback primitives: `DesignSystem/BeckonFeedbackPrimitives.swift`
- Form primitive: `DesignSystem/BeckonFormPrimitives.swift`
- Feature fallback: `DesignSystem/FeaturePlaceholderView.swift`
- Extracted token source: `../08_design/design_tokens.json`
- Screen inventory: `SCREEN_INVENTORY.md`
- Visual audit summary: `../08_design/UI_IMPLEMENTATION_NOTES.md`

## Token Rules

Use semantic tokens from `DesignTokens` before adding a new value.

Current token groups include:

- Colors: background, raised surface, border, divider, primary/secondary/tertiary text, customer primary states, groomer accent states, success, warning, and error.
- Spacing: compact through large gaps plus screen horizontal padding.
- Shape: card, button, input, bottom sheet, chip, and circular shapes.
- Shadow: soft card, small card, customer primary action, and groomer action.
- Typography: large title, title, headline, body, and caption using SwiftUI semantic styles.

New tokens must be introduced through `DesignTokens`, then reused by shared primitives or feature screens. Do not scatter raw Beckon hex colors, radii, shadows, or spacing through feature views.

## Component Rules

Implemented primitives:

- `BeckonPrimaryButtonStyle`
- `BeckonSecondaryButtonStyle`
- `BeckonCard`
- `BeckonStatusChip`
- `BeckonErrorBanner`
- `BeckonLoadingView`
- `BeckonEmptyState`
- `BeckonSectionHeader`
- `.beckonFormField()`

These primitives own only presentation. Calling screens still own validation, loading state, duplicate-submit prevention, retry actions, navigation, data fetching, and business mutations through existing Store/repository boundaries.

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
- Keep dark-mode changes, new brand assets, public groomer directory, direct booking, payments, attachments, maps/calendar, admin tools, and push behavior beyond the approved T-153/T-157 notification scope out of scope unless explicitly requested.
