# Design System

## Direction

The MVP should feel friendly, calm, and pet-focused without becoming visually busy. Use soft surfaces, clear step progression, readable status chips, and a small number of strong actions. Avoid dense dashboards, map-first layouts, oversized calendars, or decorative animation that competes with task completion.

## Principles

- Preserve a clear hierarchy and one primary action per decision point.
- Support Dynamic Type and system accessibility settings.
- Treat loading, empty, error, disabled, selected, and success as first-class component states.
- Use semantic colors so light/dark mode and contrast remain system-compatible.
- Reuse components before adding feature-specific visual variants.

## Implemented Baseline Tokens

Defined in `DesignSystem/DesignTokens.swift`:

| Token | Current Value | Usage |
|---|---|---|
| `Colors.background` | `systemGroupedBackground` | Screen background |
| `Colors.surface` | `secondarySystemGroupedBackground` | Cards and grouped surfaces |
| `Colors.primaryText` | `Color.primary` | Titles and primary content |
| `Colors.secondaryText` | `Color.secondary` | Supporting text |
| `Spacing.standard` | 16 pt | Default gaps and outer padding |
| `Spacing.large` | 24 pt | Major section spacing |
| `CornerRadius.card` | 16 pt | Card surfaces |

These are baseline semantics, not a finished brand palette. New tokens must be introduced through `DesignTokens` rather than embedded independently in screens.

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
