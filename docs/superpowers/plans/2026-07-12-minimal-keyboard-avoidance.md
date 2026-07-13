# Minimal Keyboard Avoidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Replace Beckon's fixed 55% focused-field anchor with Apple-style minimum necessary scrolling, validate the Request Wizard baseline, and then migrate every remaining input surface according to its form or input-accessory semantics.

**Architecture:** `DesignSystem` owns the pure visibility decision, semantic focus-target geometry, measured scroll-viewport orchestration, and keyboard observation. A feature supplies only the focused semantic-group ID and its scroll proxy; the shared modifier returns no movement when the group is visible, reveals only the obscured edge when it is not, and lets content bounds clamp naturally. Page actions remain in page coordinates; true composers such as Chat may remain keyboard accessories after explicit review.

**Tech Stack:** Swift 6, SwiftUI, UIKit keyboard-frame notifications at one shared boundary, Swift Testing, Xcode Simulator, existing UI consistency audit.

## Global Constraints

- Preserve Store, repository, navigation, validation, publication, and backend behavior.
- Do not add a dependency or use private UIKit APIs or global `UIScrollView` appearance changes.
- The visible target is the label/title plus complete control and immediate validation/help text.
- Use measured container, keyboard, and target geometry; do not use a fixed screen percentage, guessed keyboard height, negative padding, or arbitrary corrective offset.
- If the target is already visible within the usable viewport, perform no scroll.
- If obscured, reveal only the nearest hidden edge plus `DesignTokens.Layout.fieldSpacing`; natural scroll bounds decide the final reachable position.
- Keep page-level Back/Continue/Save/Publish controls at their keyboard-hidden page coordinate. Allow keyboard-following behavior only for controls whose sole purpose is the active input, such as Send.
- Preserve Dynamic Type, VoiceOver order, interactive keyboard dismissal, long text, safe areas, hardware keyboards, and UIKit-backed focus callbacks.
- Every keyboard-aware scrolling form provides an explicit `Done` action as well as interactive drag dismissal; leaving the page is never the only dismissal path.
- Validate each migration slice with focused tests, full tests, build, and source audit. Runtime keyboard interaction remains user validation unless the user explicitly requests Simulator inspection.

## File Structure

- `ios/Beckon/Beckon/DesignSystem/BeckonFormPrimitives.swift`: pure visibility policy, focus-target bounds preference, and reusable semantic-group modifier.
- `ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestWizardView.swift`: first consumer and reference orchestration; retains feature-owned field IDs and bottom actions.
- `ios/Beckon/BeckonTests/CustomerRequestFeatureTests+WizardPresentation.swift`: geometry decision and Request integration contracts.
- `docs/01_product/DESIGN_SYSTEM.md`: replace the 55% anchor statement with minimum necessary reveal rules.
- `docs/04_ios/UI_CODE_GOVERNANCE.md`: review and evidence requirements.
- Auth/Customer, Groomer/business, and residual/modal/chat Feature files: migrated only in their bounded tasks after the reference implementation passes.

---

### Task 1: Shared Minimum-Reveal Decision

**Files:**
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonFormPrimitives.swift`
- Modify: `ios/Beckon/BeckonTests/CustomerRequestFeatureTests+WizardPresentation.swift`

**Interfaces:**
- Produces: `BeckonKeyboardFormLayout.RevealAction` with `.none`, `.top`, and `.bottom`.
- Produces: `revealAction(for: CGRect, clearance: CGFloat) -> RevealAction`.
- Retains: `keyboardOverlap` and `scrollBottomClearance(base:)` for page-action and scroll-content geometry.

- [x] **Step 1: Write failing pure-geometry tests**

Cover these exact cases with an 800pt container, keyboard beginning at 500pt, and 16pt clearance:

```swift
#expect(layout.revealAction(for: CGRect(x: 0, y: 300, width: 320, height: 80), clearance: 16) == .none)
#expect(layout.revealAction(for: CGRect(x: 0, y: 450, width: 320, height: 80), clearance: 16) == .bottom)
#expect(layout.revealAction(for: CGRect(x: 0, y: -10, width: 320, height: 80), clearance: 16) == .top)
```

Also test keyboard hidden, a target exactly on the boundary, a target taller than the usable viewport, and a floating/split keyboard frame that does not horizontally intersect the form container.

- [x] **Step 2: Run the focused test and confirm RED**

Run:

```bash
./scripts/ios-test.sh --filter CustomerRequestFeatureTests
```

Expected: compilation fails because `RevealAction` and `revealAction` do not exist.

- [x] **Step 3: Implement the pure decision**

Store the container and keyboard frames, derive their actual intersection, and define the usable vertical interval. Return `.none` when there is no relevant overlap or the target fits inside the interval; otherwise return the nearest obscured edge. For a target taller than the usable interval, prefer the edge closest to its current visible position instead of oscillating between edges.

- [x] **Step 4: Run the focused test and confirm GREEN**

Run the same focused command. Expected: all selected tests pass.

### Task 2: Reusable Semantic Focus-Target Geometry

**Files:**
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonFormPrimitives.swift`
- Modify: `ios/Beckon/BeckonTests/DesignSystemContractTests.swift` if present; otherwise keep structural contract tests in `CustomerRequestFeatureTests+WizardPresentation.swift`.

**Interfaces:**
- Produces: `.beckonKeyboardFocusTarget(_ id: String)` applied to the label/control/help container.
- Produces: top and bottom marker IDs derived deterministically from the semantic ID.
- Produces: bounds keyed by semantic ID in the same measured global coordinate space as the shared viewport and keyboard frame.

- [x] **Step 1: Add a failing contract test** proving one semantic ID yields stable top/bottom marker IDs and cannot collide with another field ID.
- [x] **Step 2: Run the focused test and confirm RED** because the target contract does not exist.
- [x] **Step 3: Implement the modifier and preference key** using zero-height `Color.clear` markers before and after the complete group. Report one group rect; do not add scrollable height or visual spacing.
- [x] **Step 4: Run the focused test and confirm GREEN** and inspect the modifier for unchanged accessibility order.

### Task 3: Request Wizard Reference Migration

**Files:**
- Modify: `ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestWizardView.swift`
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonAddressEditor.swift`
- Modify: `ios/Beckon/BeckonTests/CustomerRequestFeatureTests+WizardPresentation.swift`

**Interfaces:**
- Consumes: `BeckonKeyboardFormLayout.revealAction` and `.beckonKeyboardFocusTarget`.
- Removes: `focusedGroupAnchorY` and every `scrollTo(... anchor: UnitPoint(x: 0.5, y: 0.55))` call.

- [x] **Step 1: Add failing source/contract assertions** that the Wizard consumes top/bottom target markers and has no fixed focused-field anchor.
- [x] **Step 2: Run the focused test and confirm RED** against the existing 55% implementation.
- [x] **Step 3: Integrate measured target bounds** and recompute only when focus, keyboard frame, container frame, or focused-group bounds change.
- [x] **Step 4: Reveal the selected edge only when required**: scroll to the bottom marker for `.bottom`, top marker for `.top`, and do nothing for `.none`. Preserve keyboard overlap as scroll clearance and preserve the existing measured bottom-action compensation.
- [x] **Step 5: Prevent feedback loops** by ignoring unchanged geometry decisions and cancelling any pending reveal when focus changes or the keyboard hides.
- [x] **Step 6: Run focused tests and `./scripts/ios-build.sh`**. Expected: pass with no new UI-audit errors.
- [x] **Step 7: Verify on Simulator** with a middle address field, ZIP, and multiline Notes. Record keyboard-hidden/shown evidence proving: visible fields do not move, partly hidden fields move only enough, title/control remain visible, short content clamps naturally, and Back/Continue remain behind the keyboard.
- [x] **Step 8: Update the active rules** in `docs/01_product/DESIGN_SYSTEM.md` and `docs/04_ios/UI_CODE_GOVERNANCE.md`, replacing 55% language rather than retaining both policies.
- [x] **Step 9: Run full T-320 validation**: focused tests, full `./scripts/ios-test.sh`, build, strict Wizard and repository UI audits, `git diff --check`, context hygiene, and preflight.

### Task 4: Auth and Customer Forms

**Files:**
- Modify only audited callers under `Features/Auth/` and `Features/Customer/` that contain editable text and are not already the Request reference.
- Add focused tests beside each existing feature test family; do not create one cross-feature mega-test file.

- [x] **Step 1: Inventory each input and classify its container** as scrolling form, short non-scrolling form, modal editor, or true input accessory.
- [x] **Step 2: Add focus IDs around complete semantic groups** and migrate only scrolling forms that can be obscured. Leave naturally visible short forms native unless Simulator evidence shows an occlusion defect.
- [x] **Step 3: Preserve submit labels and focus progression** for Email/Password/Confirmation and preserve Customer Store validation.
- [x] **Step 4: Review Customer Profile, Pet editing, authentication, and onboarding** for semantic-group coverage, Dynamic Type-safe containers, and stationary page actions. Per the user's T-321 direction, runtime keyboard/Accessibility 3 interaction remains user validation rather than a per-module agent gate.
- [x] **Step 5: Run focused tests, full iOS tests, build, UI audit, diff, context hygiene, and preflight.**

### Task 5: Shared Keyboard Dismissal Contract

**Files:**
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonFormPrimitives.swift`
- Modify: `ios/Beckon/BeckonTests/DesignSystemContractTests.swift`
- Modify: keyboard design/governance rules and active task memory.

- [x] **Step 1: Reproduce the contract gap** in Edit Pet: minimum reveal exists, but the shared modifier provides no guaranteed dismissal action and Edit Pet does not own a dismissal policy.
- [x] **Step 2: Add a failing DesignSystem contract test** requiring interactive scrolling and an explicit `Done` path.
- [x] **Step 3: Implement both dismissal paths once in `.beckonKeyboardAvoidance`** so current and future consumers inherit them without feature-local toolbars.
- [x] **Step 4: Keep `Done` classified as a true input accessory**; page Save/Back/Continue actions retain their keyboard-hidden coordinates.
- [x] **Step 5: Run focused tests, full iOS tests, build, UI audit, diff, context hygiene, and preflight.**

### Task 6: Native Safe-Area and Scroll-Range Correction

**Files:**
- Modify: shared keyboard/stationary-action primitives and tests.
- Modify: Request Wizard only to remove its duplicate keyboard observer and synthetic clearance.
- Modify: UI consistency audit/core tests for deterministic feature-level keyboard-policy violations.
- Modify: keyboard design/governance and active task memory.

- [x] **Step 1: Reproduce the opposing failures**: Request can expose a keyboard-height blank overscroll region, while Edit Pet cannot reach lower fields.
- [x] **Step 2: Reconcile the project contract with Apple guidance** for virtual keyboards, keyboard safe areas, `FocusState`, interactive dismissal, and `UIKeyboardLayoutGuide` docked/floating behavior.
- [x] **Step 3: Add RED tests** proving form content receives no synthetic keyboard clearance, docked keyboards compensate stationary page actions, and floating keyboards do not.
- [x] **Step 4: Restore native keyboard safe-area resizing** and move docked-only stationary-action compensation into DesignSystem. Preserve Reduce Motion and system keyboard duration.
- [x] **Step 5: Remove Request's feature-local keyboard observer, overlap padding, and action offset**; Edit Pet changes only by inheriting the corrected shared behavior.
- [x] **Step 6: Add audit errors** for feature-level keyboard safe-area bypass, keyboard-derived padding/offset, and keyboard notification/frame access; retain geometry tests for semantic cases regex cannot decide.
- [x] **Step 7: Run focused/full tests, build, audit tests/repository audit, source duplication search, diff, context hygiene, and preflight.**

### Task 7: Unified Sheet Gesture Arbitration

**Files:**
- Modify: shared keyboard presentation policy/modifier and DesignSystem tests.
- Modify: Request and Edit Pet only to route existing business dismissal locks through the shared modifier.
- Modify: keyboard design/governance and active task memory.

- [x] **Step 1: Identify the missing state**: interactive keyboard dismissal inside a sheet can become a sheet-dismiss gesture before editing ends.
- [x] **Step 2: Add RED policy tests** for docked, floating, hidden, and hardware keyboards plus an independent business lock.
- [x] **Step 3: Let the shared modifier prioritize sheet content scrolling and disable interactive sheet dismissal only while software keyboard content remains onscreen.**
- [x] **Step 4: Merge feature business locks through one Boolean input** and remove duplicate Request/Edit Pet presentation modifiers.
- [x] **Step 5: Record the concise state table and ownership boundary; keep unsaved-change confirmation as a separate feature/data-protection concern.**
- [x] **Step 6: Run focused/full tests, build, repository audit, diff, context hygiene, and preflight.**

### Task 8: Groomer and Business Editors

**Files:**
- Modify only audited editable callers under `Features/Groomer/`, including profile, services, and offer composition.
- Add tests to the existing Groomer feature test families.

- [ ] **Step 1: Classify page forms versus sheet/modal editors** and identify page-level Save/Submit actions.
- [ ] **Step 2: Apply shared semantic focus targets and minimum reveal** without moving page actions into keyboard accessories.
- [ ] **Step 3: Review the lowest single-line and multiline fields** in Groomer Profile, Services, and Offer composition for shared-rule coverage; runtime interaction remains user validation.
- [ ] **Step 4: Run focused tests, full iOS tests, build, UI audit, diff, context hygiene, and preflight.**

### Task 9: Modal, Booking, Chat, and Residual Audit

**Files:**
- Modify audited residual editable callers, including `Features/Bookings/BookingsView.swift` and `Features/Chat/ChatView.swift`, only when their current behavior violates their classification.
- Update existing Booking/Chat tests.

- [ ] **Step 1: Run a complete tracked Swift inventory** for `TextField`, `SecureField`, `TextEditor`, `UITextField`, and `UITextView`; account for every production result.
- [ ] **Step 2: Keep Chat Send as a keyboard accessory** if it remains attached to the active composer and does not obscure thread content; document this as the intentional exception.
- [ ] **Step 3: Migrate form-like booking/review/modal inputs** to minimum reveal and preserve modal detents and dismiss behavior.
- [ ] **Step 4: Verify hardware-keyboard/no-overlap behavior** so no empty clearance or unnecessary scrolling occurs when the software keyboard is absent.
- [ ] **Step 5: Run full iOS tests/build, repository UI audit, source coverage inventory, diff, context hygiene, and preflight.**
- [ ] **Step 6: Close the migration only when the final inventory has an explicit disposition for every production input.**

## Acceptance Matrix

| Case | Expected result |
|---|---|
| Focused group already visible | Zero programmatic scroll. |
| Bottom edge obscured | Reveal bottom edge plus semantic clearance only. |
| Top edge obscured | Reveal top edge plus semantic clearance only. |
| Group taller than usable viewport | Stable nearest-edge reveal; no oscillation. |
| Short page lacks scroll range | Natural nearest reachable position; no synthetic blank space. |
| Keyboard hidden or hardware keyboard | Zero keyboard overlap and zero keyboard-driven scroll. |
| Interactive dismissal | Clearance and action compensation track the keyboard frame without jumps. |
| Dynamic Type | Label, complete control, and immediate validation remain the semantic target. |
| Page action | Original page coordinate; keyboard may cover it. |
| Chat/send accessory | May track keyboard after explicit classification. |

## Sources

- Apple HIG: `https://developer.apple.com/design/human-interface-guidelines/text-fields`
- Apple HIG: `https://developer.apple.com/design/human-interface-guidelines/virtual-keyboards`
- Apple UIKit: `https://developer.apple.com/documentation/uikit/adjusting-your-layout-with-keyboard-layout-guide`
- Apple SwiftUI keyboard safe area: `https://developer.apple.com/documentation/swiftui/safearearegions/keyboard`
- Apple SwiftUI interactive dismissal: `https://developer.apple.com/documentation/swiftui/view/scrolldismisseskeyboard(_:)`
