# Form Interaction Rules

On-demand contract for editable pages, sheets, text entry, focus, keyboard avoidance, scrolling editors, and sheet gesture arbitration. Core visual rules remain in `DESIGN_SYSTEM.md`; general accessibility remains in `ACCESSIBILITY_RULES.md`.

The shared implementation boundary is `BeckonKeyboardFormLayout` and its modifiers in `ios/Beckon/Beckon/DesignSystem/BeckonFormPrimitives.swift`.

## Keyboard And Focus

- Keep the system keyboard safe area active. Feature forms must not call `ignoresSafeArea(.keyboard)` or add keyboard height as padding/inset.
- Use `ScrollView`, `List`, or `Form` whenever device size, Dynamic Type, validation, localization, or multiple fields can exceed the keyboard-reduced viewport.
- A focus target is the complete semantic field group: visible label/title, full control, and immediate validation text when practical. Do not target only the cursor.
- If the complete focused group is already visible with semantic clearance, perform no programmatic scroll. Otherwise reveal only the nearest hidden edge and allow normal content-bound clamping.
- Oversized groups choose the edge requiring less movement so repeated geometry updates cannot oscillate. Never create synthetic scroll range from keyboard height.
- Use one unambiguous optional/Boolean `FocusState` per form scope. Apply semantic keyboard/content types and `submitLabel`; Return advances only when a truthful next field exists.
- Native SwiftUI fields and UIKit representables publish focus through the same shared target contract. Representable callbacks stay at the shared component boundary.
- Automatic reveal is a one-time, non-animated response to new focus or keyboard appearance. User tracking/scrolling cancels pending reveal work; geometry and keyboard-frame updates must not restart it during the gesture.
- Shared geometry uses `onGeometryChange`; only the active non-empty target reports bounds and duplicate measurements are ignored. Do not create a same-frame PreferenceKey/state feedback loop.

## Actions And Dismissal

- Page actions retain their keyboard-hidden page coordinate. `.beckonStationaryPageAction` moves a stationary overlay action below the screen for a bottom-docked software keyboard and restores it after dismissal.
- Actions already in scroll content stay in that flow. The Chat composer Send control is the intentional input accessory; other current business actions do not track the keyboard.
- Floating, split, hidden, and hardware keyboards produce zero stationary-action offset. Use semantic content clearance when scroll content must remain reachable behind an overlay.
- Every text-entry surface provides `.beckonKeyboardDoneAccessory()`. `.beckonKeyboardAvoidance` supplies it for scrolling forms; non-form input owners attach it directly. No Feature creates another keyboard toolbar.
- Keyboard-aware scrolling forms also use interactive drag dismissal. Shared movement uses the system frame and timing and suppresses custom animation under Reduce Motion; never guess keyboard height or duration.

## Sheet Gesture Arbitration

| State | Downward gesture | Sheet dismissal |
|---|---|---|
| Software keyboard onscreen, or its dismissal drag has not returned to idle | Scroll content or dismiss keyboard interactively | Disabled |
| Keyboard hidden or hardware keyboard | Normal content/sheet behavior | Enabled |
| Feature business lock, such as saving or a critical overlay | Normal keyboard behavior | Disabled until the lock clears |

The shared modifier derives keyboard presence from the actual onscreen frame, combines it with one optional business lock, and retains the dismissal lock through tracking, interaction, and deceleration. One drag must not change from keyboard dismissal into sheet dismissal. Every sheet still provides explicit Cancel/Back and Done/Save actions; unsaved-change confirmation remains a separate data-protection rule.

Prefer a large-only sheet or full-screen page for long composition and multi-step forms.

## Ownership Boundary

Use `.beckonKeyboardFocusTarget(_:)` on complete field groups, `.beckonKeyboardAvoidance(focusedTarget:using:additionallyPreventsPresentationDismissal:)` on scrolling forms, and `.beckonStationaryPageAction` only for page actions.

DesignSystem owns keyboard observation, geometry, one-shot reveal, scroll-phase handoff, animation, dismissal, sheet arbitration, and stationary-action behavior. Features may own field IDs, focus order, keyboard/content types, business validation, and one business-lock Boolean. Features must not add keyboard padding, offsets, dismissal toolbars, viewport-percentage anchors, keyboard-driven `interactiveDismissDisabled`, or a second observer.

## Review Matrix

Review at least one low single-line field and one multiline field when present. Cover docked, floating, and hardware keyboard behavior; default and AX3 Dynamic Type; VoiceOver order; long text; focus dismissal; and sheet behavior. Runtime interaction remains required evidence when the task changes these behaviors.

Primary Apple references: HIG virtual keyboards and sheets; SwiftUI keyboard safe area, `FocusState`, `scrollDismissesKeyboard`, `onScrollPhaseChange`, `presentationContentInteraction`, and `interactiveDismissDisabled`; UIKit `UIKeyboardLayoutGuide` and interactive keyboard dismissal.
