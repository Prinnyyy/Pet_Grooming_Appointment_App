# Design System

Canonical routing and core visual contract for Beckon UI work. Detailed accessibility and form behavior live in focused, on-demand files rather than this default entry.

Pre-routing source snapshot: `../09_frozen/design_notes/T-347_2026-07-13/DESIGN_SYSTEM.md`.

## Read Path

- Always start here for visual style, shared SwiftUI primitives, tokens, or screenshot-driven UI.
- Add `ACCESSIBILITY_RULES.md` when changing user-visible UI, controls, images, text, status, or async feedback.
- Add `FORM_INTERACTION_RULES.md` only for text entry, focus, keyboard avoidance, scrolling editors, or sheet gestures.
- Add `LIVELY_UI_SPEC.md` for any Tier L/M (expressive) Customer UI: ledge surfaces, rounded type, entrance and idle motion, the pup illustration. Screens not declared there are Tier C and keep this file's contract unchanged (D-063, extended by D-064).
- Use `../08_design/UI_IMPLEMENTATION_NOTES.md` to locate current screenshots and design evidence.
- Use `../08_design/GROOMER_UI_REDESIGN.md` for the Groomer workspace contract or a focused R-039 regression.
- Use `../ui-redesign/README.md` only when an explicit Figma/inventory task requires the heavy redesign evidence package.

Executable Feature-code rules and audit commands live in `../04_ios/UI_CODE_GOVERNANCE.md`. Product flow, role routing, repositories, Supabase, RLS/RPC, Storage, and deferred features are outside this contract.

## Visual Direction

- Friendly, calm, pet-focused marketplace UI with warm off-white pages and white surfaces.
- Customer uses mint/teal action roles; Groomer uses coral action roles.
- Role Fill is a light action surface, Ink is its foreground, Deep is for links, controls, progress and selection outlines, and opaque Tint is for selected/icon surfaces. Exact values and allowed contrast pairs live in `DesignTokens.swift` and `DesignTokenAccessibilityTests.swift`; D-060 supersedes earlier palette proposals.
- Role color communicates action, selection or role, never domain status or failure. Status uses semantic Text/Fill/Border with a symbol and label; shared screens keep the same status presentation for both roles.
- No accent-opacity control surfaces, gradient buttons or colored action shadows. The Customer Hero retains a related-color gradient. Tier C cards share one quiet warm shadow; depth primarily comes from borders. Tier L/M tappable surfaces use the opaque ledge from `LIVELY_UI_SPEC.md`, never a blur or glow. Customer profile placeholders use the role Tint/Deep pair; other placeholders and list icon tiles retain their role-scoped treatment. Species is conveyed by symbols rather than color. The authentication brand illustration has the separate, bounded material contract below.
- Destructive actions use a white surface with semantic error text/border for either role. Errors include an alert symbol and error container; success includes a checkmark. Never use white text on a light role Fill.
- Clear hierarchy, quiet borders/shadows, content-led imagery, and explicit loading, empty, error, selected, disabled, and success states.
- Customer remains pet/decision oriented. Groomer remains schedule/action oriented and uses grouped surfaces with row separators rather than card stacks.
- Native SwiftUI/SF typography and semantic Dynamic Type styles are required. Tier L/M may use the SF Rounded `DesignTokens.Typography.Expressive` roles, which are still semantic text styles.

Avoid dense dashboards, map-first layouts, oversized calendars, decorative animation outside the approved brand illustration and the Tier L expressive illustration layer, nested cards, and raw feature-local color, spacing, radius, shadow, or font values.

### Authentication Brand Illustration

`BeckonBrandBubble` owns the existing mascot bubble and seven surrounding small bubbles. The wordmark, copy, layout and authentication actions remain owned by `AuthenticationView`; no new asset, navigation or account capability is implied.

- Main bubble: mint body, soft translucent highlight, no outline. Do not substitute a selected-control Tint, a solid white highlight circle or a Deep selection border.
- Layer shadow: composite the icon first, then cast a soft neutral shadow behind its circular silhouette, slightly biased downward. It moves with the icon and separates the icon layer from the page background. No detached ground ellipse. Use `Shadows.brandBubble`, never change shared card elevation for this effect.
- Preserve the surrounding small bubbles as light translucent decoration, without hard white outlines or overlap with the wordmark/actions. Do not spread this treatment to operational screens.
- Preserve the one-time opening animation: the icon enters from above with a small scale/fade and a lightly damped spring, then continues a slow 4-second float with at most 4pt vertical displacement. Satellites drift slowly. `AuthenticationView` owns entrance completion so returning from the form does not replay it. Fixed artwork bounds keep the wordmark and actions stationary; entrance overshoot must not collide with the wordmark.
- One bounded animation timeline is owned by the artwork. Reduce Motion or an inactive scene stops all decorative motion; leaving the landing removes the artwork. Re-enabling motion must work without remounting the screen.
- `DesignTokens.BrandIllustration` owns decorative alpha/material values. Feature-local color-opacity, control contrast and status rules remain unchanged. Decorative artwork is hidden from accessibility and cannot intercept touches.
- Palette/elevation changes require a rendered comparison of the main body, highlight, edge and layer shadow, plus opening/settled, default/AX3 and moving/static checks. Source-audit success alone does not establish visual correctness.

## Sources And Ownership

- Swift tokens: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift`
- Shared primitives: `ios/Beckon/Beckon/DesignSystem/`; expressive kit: `BeckonLedge.swift`, `BeckonMotion.swift`, `BeckonExpressiveComponents.swift`, `BeckonJourney.swift`, `DesignKit.swift`, `DesignDialog.swift`, `DesignSnackbar.swift`, `FeedbackTimingPolicy.swift`, `BeckonExpressiveIllustration.swift`
- Shared business UI and reusable flow state: `ios/Beckon/Beckon/SharedFeatures/` (Address, Notifications, Matching)
- Historical prototype palette: `../09_frozen/design_notes/design_tokens_2026-10-17.json` (not an implementation source)
- Screen ownership: `SCREEN_INVENTORY.md`
- Remaining source debt: `../04_ios/UI_CONSISTENCY_DEBT.md`

Use semantic `DesignTokens` roles before adding a value. New values enter `DesignTokens` first and must serve repeatable semantics. DesignSystem owns visual primitives and must not depend on feature flows. SharedFeatures composes those primitives for business UI reused across roles; reusable address state belongs there, separately from its view. Feature Stores/flow states and repositories retain validation, loading, retry and business mutations. Views own layout/focus and hand navigation targets to the owning shell.

Reuse implemented primitives such as action styles, `BeckonSection`, `BeckonGroupedSurface`, selection/card/status/feedback primitives, settings rows, field groups, location-mode presentation, and `.beckonFormField()`. Add a new primitive only when a pattern recurs or a shared contract genuinely removes complexity.

## UI Design Rules (UI-R1..R8)

- **UI-R1 Component ownership:** Extract repeated stable presentation when it removes real duplication. Generic visual primitives belong in `DesignSystem/`; reusable business components belong in `SharedFeatures/`; one-feature helpers stay with that feature. Two call sites alone do not justify a new abstraction. Preserve applicable loading, disabled, error, empty, selected and accessibility behavior; do not add style flags that rendering never consumes.
- **UI-R2 Semantic typography:** Feature text uses `DesignTokens.Typography`; hierarchy comes from semantic style and weight, never new `Font.system(size:)` sites.
- **UI-R3 Reserved accents:** A screen has at most one role-accent primary-action pattern. Outside the approved brand illustration, the Customer Hero and the Tier L illustration layer, accent communicates action or selection, not decoration or status.
- **UI-R4 Semantic color and contrast:** Feature code uses semantic color roles and only approved foreground/background pairs from `ACCESSIBILITY_RULES.md`.
- **UI-R5 Token spacing and shape:** Keep the 4pt grid and established semantic insets, spacing, radii, and control metrics. Introduce reusable values through tokens first.
- **UI-R6 Content-first depth:** Let relevant pet, portfolio, and Groomer imagery lead. Use the quiet elevation tier (Tier C) or the ledge (Tier L/M), never both on one surface; operational lists remain grouped rather than card-heavy.
- **UI-R7 Complete async states:** Every async surface provides truthful loading, empty, error, and success presentation with a useful next action or retry.
- **UI-R8 Screen archetypes:** Classify screens as List/Feed, Detail, Wizard, Thread, Editor, or Workspace and follow a consistent hierarchy/action/accessibility contract for that archetype.

## Screenshot Rework

### Request-Scoped Groomer Browsing

T-420 (D-064) uses one request-scoped selectable groomer list in wizard step six and the Invite more sheet. Sort and Saved filters, profile details, favorites, invitation selections and pool consent are explicit controls. The former swipe deck and separate full-list page are retired. `GroomerChoiceRow`, `GroomerSelectionActions`, `GroomerPoolCard`, `GroomerCandidateSummaryView` and `GroomerCandidateActionsView` stay Customer-owned; professional-fit evidence reuses `BeckonFitEvidenceBlock` without a numeric score. Existing Stores/repositories own ranking, pagination, authorization and mutations.

The request wizard's fixed header and bottom action bar surround the scrolling form. Pet choices keep a selection-indicator slot and separate name, breed and weight rows. Step six uses the same motion/chrome and Done routes through the tab shell to the new request. Requests root shows active requests; closed requests belong in history. Never infer invitation capacity from every offered invitation: pending selectable offers count, unusable offers do not; partial evidence shows capacity as checked on send. Offer minima badges require a complete, current quote set.

Customer booking detail composes ticket, path, next step, review, Manage booking and collapsible record. Shared note/time confirmations retain real validation and recovery inside custom dialogs. Removing a pet requires confirmation; removing a favorite offers a page-owned Undo through the existing reversible mutation. Shared account actions order routine sign-out above quiet destructive deletion. Customer appearance is scoped through `beckonCustomerDesign`; groomer layout remains unchanged except the explicitly shared account actions and booking dialogs.

Start with `../06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`. Map visible modules to current screens, Stores, repositories, and models before editing. Classify each as visual-only, existing-feature rewire, reusable primitive, or new feature. Stop for approval before persistence, schema, backend, navigation, role capability, or deferred product changes.

## Hard Rules

- Never communicate status through color alone.
- Buttons expose disabled/loading state and prevent duplicate submissions.
- Images have useful accessibility labels unless decorative.
- Reuse shared primitives before adding feature-local variants.
- Preserve the Request -> Offer -> Acceptance -> Booking/Chat -> Completion -> Review lifecycle.
- Keep primary tab bars to five destinations; feature editors hide the tab bar and expose one back action.
- Dark mode, new brand assets, public Groomer discovery, direct booking, payments, attachments, maps/calendar expansion, admin tools, and new push behavior remain out of scope unless explicitly approved.
