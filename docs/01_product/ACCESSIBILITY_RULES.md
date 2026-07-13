# Accessibility Rules

On-demand accessibility and light-palette contrast contract for Beckon UI. Read this with `DESIGN_SYSTEM.md` for any user-visible UI slice.

## Approved Color Pairs

Normal text requires at least 4.5:1 contrast; large text and meaningful UI graphics require at least 3:1. Feature code uses semantic roles, not raw color literals.

| Foreground | Background | Approved use |
|---|---|---|
| `textPrimary #333333` | surface or app background | Primary text. |
| `textPrimary #333333` | Customer accent or accentSoft | Customer primary-action foreground. |
| `groomerOnAccent #642620` | coral or coralDark | Groomer action foreground. |
| `customerHeroText #333333` | Display P3 Hero mint | Customer Hero title and supporting copy. |
| `customerHeroText #333333` | surface white | Customer Hero action foreground. |
| `textTertiary #69717A` | surface or app background | Tertiary text. |
| `textSecondary #6F767E` | surface | Secondary text on a surface only. |
| `successText #37744E` | surface | Success body text. |
| `warningText #8F6800` | surface | Warning body text. |
| `errorText #B4474C` | surface | Error body text. |

Banned pairs:

- White text on mint, mintDark, coral, or coralDark.
- Success `#6CBF84`, warning `#F2B84B`, or error `#E56B6F` as normal body text on a surface; use the corresponding `*Text` role.
- `textSecondary #6F767E` as normal-size text directly on `#FAF7F2` app background.
- Any unmeasured raw foreground/background combination in feature code.

Dark mode remains out of scope. Semantic role names must remain stable so a future palette can change values without rewriting feature layouts.

## Accessibility Groundwork (A11Y-R1..R10)

- **A11Y-R1 Dynamic Type:** Use semantic text styles and content-sized containers. Do not fix text heights or truncate informational text to one line unless the full value is available elsewhere. Prefer reflow, stacking, `ViewThatFits`, or `isAccessibilitySize`. `minimumScaleFactor` is not an overflow strategy; values below 0.85 are prohibited. Every UI slice must pass AX3 (`.accessibility3`).
- **A11Y-R2 Touch targets:** Interactive elements are at least 44x44pt. Icon controls and chips receive the same floor; list rows use full-row hit areas rather than glyph-sized targets.
- **A11Y-R3 Contrast and status:** Use only the approved pair table. Status fills/icons use dark foregrounds, body copy uses AA `successText`, `warningText`, and `errorText`, and status never relies on color alone.
- **A11Y-R4 Labels and identifiers:** Every control and informative image has a human, model-derived accessibility label. `accessibilityIdentifier` is TestOps-only and never replaces a VoiceOver label.
- **A11Y-R5 Grouped reading:** Composite rows/cards read coherently using combined children where appropriate. Secondary controls may become accessibility actions instead of fragmented swipe stops.
- **A11Y-R6 Headings:** Shared section headers expose the header trait; page titles use native navigation titles so VoiceOver rotor navigation remains useful.
- **A11Y-R7 Async announcements:** Meaningful success, failure, confirmation, and refresh outcomes are announced. New screens must not introduce silent async outcomes.
- **A11Y-R8 Images:** Decorative images are hidden from accessibility. Informative pet, portfolio, and avatar images use model-derived labels, with essential meaning also available as text.
- **A11Y-R9 Reduced motion:** Custom motion reduces to opacity or no animation when Reduce Motion is enabled. Motion never carries meaning by itself.
- **A11Y-R10 Per-slice Definition of Done:** Complete the checklist in `../06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` for every UI slice; accessibility is incremental, not a later retrofit.

## Review Evidence

For each changed slice, record a VoiceOver walkthrough, AX3 reflow result, target-size audit, approved-pair audit, async-announcement behavior, and confirmation that existing TestOps identifiers remain intact. Source audits supplement but do not replace runtime accessibility review.
