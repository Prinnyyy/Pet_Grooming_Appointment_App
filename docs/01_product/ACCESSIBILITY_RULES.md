# Accessibility Rules

On-demand accessibility and light-palette contrast contract for Beckon UI. Read this with `DESIGN_SYSTEM.md` for any user-visible UI slice.

## Approved Color Pairs

Normal text requires at least 4.5:1 contrast; large text and meaningful UI graphics require at least 3:1. Feature code uses semantic roles, not raw color literals.

| Foreground | Background | Approved use |
|---|---|---|
| `textPrimary`, `textSecondary`, `textTertiary` | surface or app background | Warm text hierarchy; tertiary is lighter than secondary. |
| Role `Ink` | Same role `Fill` or `FillPressed` | Primary-action foreground, at least 4.5:1. |
| Role `Deep` | surface, app background or same role `Tint` | Links, controls, selection and progress, at least 4.5:1. |
| Customer `Ink` | Customer Hero Fill/End or surface | Hero title, supporting text and white-capsule foreground. |
| Status `Text` | surface or matching status `Fill` | Semantic text/icon, at least 4.5:1; include label and symbol. |
| surface white | `statusSuccessText` | Success-toast checkmark; does not permit white on light fills. |

The exact sRGB values and executable pairing assertions are owned by `DesignTokens.swift` and `DesignTokenAccessibilityTests.swift`; this table describes usage, not a second numeric palette.

Banned pairs:

- White text on either role's light Fill or FillPressed.
- Light role/status fills or `ratingStar` as text, control tint or meaningful fine lines.
- `accent.opacity()` or any Feature-local color-token opacity composited over a background; use opaque role Tint, status Fill or named neutral surfaces.
- Any unmeasured raw foreground/background combination in feature code.

Dark mode remains out of scope. Semantic role names must remain stable so a future palette can change values without rewriting feature layouts.

The authentication illustration's named DesignSystem material may use translucent highlights, small bubbles and a shadow behind the icon layer under the bounded contract in `DESIGN_SYSTEM.md`. These noninteractive, accessibility-hidden shapes are not foreground/background pairs for text or controls; this does not relax Feature color rules. Reduce Motion skips the opening animation and stops the continuous float; re-enabling motion resumes the float, not the opening animation.

## Accessibility Groundwork (A11Y-R1..R10)

- **A11Y-R1 Dynamic Type:** Use semantic text styles and content-sized containers. Do not fix text heights or truncate informational text to one line unless the full value is available elsewhere. Prefer reflow, stacking, `ViewThatFits`, or `isAccessibilitySize`. `minimumScaleFactor` is not an overflow strategy; values below 0.85 are prohibited. Every UI slice must pass AX3 (`.accessibility3`).
- **A11Y-R2 Touch targets:** Interactive elements are at least 44x44pt. Icon controls and chips receive the same floor; list rows use full-row hit areas rather than glyph-sized targets.
- **A11Y-R3 Contrast and status:** Use only the approved pair table. Status uses semantic Text/Fill/Border roles, a symbol and a label, never role color alone. Success includes a checkmark and errors an alert symbol/container.
- **A11Y-R4 Labels and identifiers:** Every control and informative image has a human, model-derived accessibility label. `accessibilityIdentifier` is TestOps-only and never replaces a VoiceOver label.
- **A11Y-R5 Grouped reading:** Composite rows/cards read coherently using combined children where appropriate. Secondary controls may become accessibility actions instead of fragmented swipe stops.
- **A11Y-R6 Headings:** Shared section headers expose the header trait; page titles use native navigation titles so VoiceOver rotor navigation remains useful.
- **A11Y-R7 Async announcements:** Meaningful success, failure, confirmation, and refresh outcomes are announced. New screens must not introduce silent async outcomes.
- **A11Y-R8 Images:** Decorative images are hidden from accessibility. Informative pet, portfolio, and avatar images use model-derived labels, with essential meaning also available as text.
- **A11Y-R9 Reduced motion:** Custom motion reduces to opacity or no animation when Reduce Motion is enabled. Motion never carries meaning by itself.
- **A11Y-R10 Per-slice Definition of Done:** Complete the checklist in `../06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` for every UI slice; accessibility is incremental, not a later retrofit.

## Review Evidence

For each changed slice, record a VoiceOver walkthrough, AX3 reflow result, target-size audit, approved-pair audit, async-announcement behavior, and confirmation that existing TestOps identifiers remain intact. Source audits supplement but do not replace runtime accessibility review.
