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
- New scrolling forms reuse the accepted coordinated reveal: begin with the keyboard destination-frame notification and its duration; do not wait for keyboardDidShow and start a second animation. Reveal only the obscured distance using absolute content coordinates, not a viewport-relative view-ID anchor. User tracking/scrolling cancels pending reveal work; geometry updates must not restart it during the gesture. Reduce Motion disables the custom animation.
- On dismissal, let the native scroll viewport and content bounds settle. Do not subtract keyboard height, animate back to a saved offset, or apply a delayed corrective scroll. Older consumers retain their compatibility mode until individually migrated.
- Shared geometry uses `onGeometryChange`; only the active non-empty target reports bounds and duplicate measurements are ignored. Do not create a same-frame PreferenceKey/state feedback loop.

## Actions And Dismissal

- New form page actions use `.beckonKeyboardDock`: a constant content reservation and a fixed overlay at the device bottom, with opaque background covering the bottom safe area. The keyboard covers/uncover the dock; no entrance animation, collapsing reservation, or keyboard-height translation. Only the shared dock overlay ignores the keyboard safe area. `.beckonStationaryPageAction` remains a compatibility path for existing consumers, not the new-form template.
- Actions already in scroll content stay in that flow. The Chat composer Send control is the intentional input accessory; other current business actions do not track the keyboard.
- Fixed docks never derive an action offset from keyboard height. Use semantic content clearance when scroll content must remain reachable behind an overlay; a floating keyboard must not move the whole footer.
- New forms set `showsDoneAccessory: false`; no full-width Done/checkmark accessory or invisible input-blocking strip. Keep inline keyboard controls where designed, taps outside input controls, and interactive drag dismissal. Outside-tap handling must include the page reservation without stealing field or button touches. Chat retains its own composer behavior. Existing accessory consumers remain compatible until separately migrated.
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

Use `.beckonKeyboardFocusTarget(_:)` on complete field groups. New scrolling forms reuse the existing entry with the accepted settings:

```swift
.beckonKeyboardAvoidance(
    focusedTarget: focusedTarget,
    using: proxy,
    additionallyPreventsPresentationDismissal: isSaving,
    showsDoneAccessory: false,
    coordinatesRevealWithKeyboard: true
)
.defaultScrollAnchor(.top, for: .sizeChanges)
```

Use `.beckonKeyboardDock` when the form has fixed bottom page actions. The coordinated modifier owns `ScrollPosition`; do not attach another scroll-position controller to the same scroll view. Reuse the shared input components and outside-input dismissal mechanism; features supply only field identity, focus, validation and actions. Reference implementation: `GroomerGroomingRequestDetail` and its offer form. This is the reuse standard for new/refactored forms, not an automatic migration of every existing screen or the Chat composer.

DesignSystem owns keyboard observation, geometry, one-shot reveal, scroll-phase handoff, animation, dismissal, sheet arbitration, and stationary-action behavior. Features may own field IDs, focus order, keyboard/content types, business validation, and one business-lock Boolean. Features must not add keyboard padding, offsets, dismissal toolbars, viewport-percentage anchors, keyboard-driven `interactiveDismissDisabled`, or a second observer.

## Review Matrix

Review at least one low single-line field and one multiline field when present. Cover docked, floating, and hardware keyboard behavior; default and AX3 Dynamic Type; VoiceOver order; long text; focus dismissal; and sheet behavior. Runtime interaction remains required evidence when the task changes these behaviors.

Primary Apple references: HIG virtual keyboards and sheets; SwiftUI keyboard safe area, `FocusState`, `scrollDismissesKeyboard`, `onScrollPhaseChange`, `presentationContentInteraction`, and `interactiveDismissDisabled`; UIKit `UIKeyboardLayoutGuide` and interactive keyboard dismissal.
