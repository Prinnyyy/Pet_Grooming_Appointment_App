# Keyboard Done Glass Control Design

## Goal

Replace the system-styled keyboard Done text button with one Beckon-owned circular accessory control that appears consistently for SwiftUI and UIKit-backed text inputs.

## Approved Presentation

- Use a 52-point circular control above the software keyboard at the trailing edge.
- Keep 12 points between the control and keyboard and 20 points from the screen edge.
- Use a centered checkmark in Beckon's dark customer mint color; do not show `Done` text.
- On iOS 26 and later, use interactive system Liquid Glass clipped to a circle.
- On iOS 18 through 25, use the same circle with an ultra-thin material fallback.
- The control dismisses the current first responder and contains no page-level save behavior.

## Architecture

`BeckonKeyboardDoneAccessoryModifier` remains the only presentation implementation. It observes keyboard frame notifications and inserts the floating control at the bottom safe-area boundary while the software keyboard is onscreen. Existing `.beckonKeyboardAvoidance(...)` consumers continue to receive it automatically; Chat and the DEBUG catalog retain direct shared-modifier adoption.

This avoids native keyboard-toolbar styling and covers `UIViewRepresentable` inputs because visibility is driven by keyboard notifications rather than SwiftUI toolbar inheritance.

## Scope

- No feature-owned accessory bars.
- No Store, repository, backend, persistence, or navigation changes.
- No Simulator or manual UI/UX review by Codex; the user owns visual acceptance.

## Validation

- Contract tests lock circular Liquid Glass presentation, dimensions, spacing, symbol, and mint color.
- Source audit confirms every production input owner receives the shared avoidance or accessory modifier.
- Full iOS tests, build, UI consistency audit, diff check, context hygiene, and preflight.
