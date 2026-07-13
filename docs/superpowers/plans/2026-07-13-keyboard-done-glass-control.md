# Keyboard Done Glass Control Implementation Plan

**Goal:** Replace the native Done text control with one circular Beckon keyboard accessory control across all production inputs.

**Architecture:** Keep feature call sites unchanged. Implement keyboard visibility and a circular Liquid Glass control inside `BeckonFormPrimitives`, then verify all input owners reach that shared modifier.

## Task 1: Lock the presentation contract

- [x] Add RED tests for a circular glass control, fixed diameter/gaps, checkmark symbol, and Beckon mint symbol color.
- [x] Verify the focused DesignSystem test fails because the new contract is missing.

## Task 2: Replace the native toolbar implementation

- [x] Remove `.toolbar(placement: .keyboard)` from the shared modifier.
- [x] Add keyboard-notification-driven visibility and a trailing circular accessory control.
- [x] Use interactive Liquid Glass on iOS 26 and an ultra-thin material fallback on earlier supported systems.
- [x] Keep `Done` as first-responder dismissal only.
- [x] Verify focused tests pass.

## Task 3: Audit coverage and close T-337

- [x] Audit every SwiftUI and UIKit-backed production input owner for shared modifier coverage.
- [x] Update design-system and task memory documentation.
- [x] Run full iOS tests/build, UI consistency, diff, context hygiene, and preflight.
- [x] Review the complete diff and prepare the task-scoped change for standing Git closeout.
