# Design System

## Direction

The MVP should feel friendly, calm, and pet-focused without becoming visually busy. Use soft surfaces, clear step progression, readable status chips, and a small number of strong actions. Avoid dense dashboards, map-first layouts, oversized calendars, or decorative animation that competes with task completion.

## Groomly UI Phase

The Groomly design files in `docs/08_design/` are the active visual reference for the next UI phase. T-023 is split into five small foundation tasks before feature screens are redesigned: T-023A design audit notes, T-023B design tokens JSON, T-023C SwiftUI token foundation, T-023D1 action primitives, and T-023D2 feedback primitives.

Use Groomly for:

- warm off-white app backgrounds;
- soft white cards with thin warm borders;
- mint customer-facing primary actions;
- coral groomer/accent actions;
- rounded cards, pills, and inputs;
- gentle shadows and clear status chips;
- calm empty, loading, and error states.

Do not use Groomly to change product flow, backend contracts, repository boundaries, or role routing.

Initial prototype color evidence:

| Purpose | Prototype Values |
|---|---|
| Text primary | `#232323` |
| Text secondary | `#6F767E` |
| App background | `#FAF7F2`, `#EFEAE1`, `#EBE4D9` |
| Border and divider | `#E8E2D8`, `#EFEAE1` |
| Customer primary | `#7ECFC0`, `#5FBFAE` |
| Groomer accent | `#FF9A8B`, `#F58575` |
| Success | `#6CBF84` |
| Warning | `#F2B84B` |
| Error | `#E56B6F` |

T-023A confirmed these values against `Groomly.html` and `docs/08_design/Groomly/` in `UI_IMPLEMENTATION_NOTES.md`. T-023B records the selected exact or inferred token source in `docs/08_design/design_tokens.json`. T-023C is responsible for translating that JSON into SwiftUI `DesignTokens` without changing feature screens; mobile prototype `px` values should map 1:1 to SwiftUI `pt`, while chip and circular radius tokens should become `Capsule`/`Circle` shapes rather than raw CSS radius constants.

## Principles

- Preserve a clear hierarchy and one primary action per decision point.
- Support Dynamic Type and system accessibility settings.
- Treat loading, empty, error, disabled, selected, and success as first-class component states.
- Use semantic colors so contrast remains deliberate. The current Groomly foundation uses fixed warm light-theme tokens; dark-mode adaptation requires a separate token pass rather than ad hoc screen colors.
- Reuse components before adding feature-specific visual variants.

## Implemented SwiftUI Tokens

Defined in `DesignSystem/DesignTokens.swift`:

| Token | Current Value | Usage |
|---|---|---|
| `Colors.background` | alias of `appBackground`, `#FAF7F2` | Screen background |
| `Colors.surface` | `#FFFFFF` | Cards and grouped surfaces |
| `Colors.primaryText` | alias of `textPrimary`, `#232323` | Titles and primary content |
| `Colors.secondaryText` | alias of `textSecondary`, `#6F767E` | Supporting text |
| `Spacing.standard` | alias of `lg`, 16 pt | Default gaps and outer padding |
| `Spacing.large` | alias of `xl`, 24 pt | Major section spacing |
| `CornerRadius.card` | 24 pt | Card surfaces |

Groomly semantic token groups now include:

| Group | Swift Tokens |
|---|---|
| Colors | `appBackground`, `surfaceRaised`, `border`, `borderSoft`, `divider`, `textPrimary`, `textSecondary`, `textTertiary`, `customerPrimary`, `customerPrimaryDark`, `customerPrimaryPressed`, `groomerAccent`, `groomerAccentDark`, `groomerAccentPressed`, `success`, `warning`, `error` |
| Spacing | `xs`, `sm`, `md`, `lg`, `xl`, `screenHorizontal`, `screenHorizontalLarge` |
| Radius and shape | `CornerRadius.card`, `button`, `input`, `bottomSheet`; JSON `chip` and `circular` map to `Shapes.chip` and `Shapes.circular` so SwiftUI uses `Capsule`/`Circle` instead of CSS radius constants |
| Shadow | `Shadows.softCard`, `smallCard`, `primaryAction`, `groomerAction` using a lightweight `ShadowStyle` value; `spread` preserves CSS source evidence because SwiftUI `.shadow` has no direct spread parameter |
| Typography | `Typography.largeTitle`, `title`, `headline`, `body`, `caption` using SwiftUI semantic `Font` styles for Dynamic Type |

New tokens must be introduced through `DesignTokens` rather than embedded independently in screens.

## Typography

- Use SwiftUI semantic text styles and Dynamic Type.
- Use `.title`/`.title2` for page and card titles, `.body` for primary content, and secondary styles for metadata.
- Avoid fixed font sizes unless a later design task documents an accessibility-safe reason.

## Component Contracts

| Component | Purpose | Required States | Current Status |
|---|---|---|---|
| `FeaturePlaceholderView` | Honest baseline for unimplemented tab content | Static placeholder | implemented |
| Primary action button | Submit the screen's main mutation | normal, loading, disabled, error recovery | planned with first form feature |
| Form field | Collect validated input | normal, focused, invalid, disabled | planned with Auth/forms |
| Content card | Present pet, request, offer, or booking summary | normal, selected when applicable | planned by feature |
| Status chip | Present request, offer, or booking state | semantic label and color | planned by feature |
| Empty/error state | Explain missing content or recoverable failure | message, optional retry/action | planned by feature |

## Rules

- Never use color alone to communicate status.
- Buttons must expose disabled/loading state and prevent duplicate submissions.
- Image content needs useful accessibility labels or must be marked decorative.
- Update this document when a reusable component or semantic token is added.
- Do not scatter raw Groomly hex colors or spacing values through feature views. Add semantic tokens and reusable primitives in `DesignSystem` first.
- Product correctness and accessibility take priority over visual matching when the prototype conflicts with the implemented app.
