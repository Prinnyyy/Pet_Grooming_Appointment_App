# Customer Form Actions and Keyboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Pet and Request forms one clear action path, enrich the shared service-location choices, and guarantee one shared Done keyboard accessory across production inputs.

**Architecture:** `CustomerPetsStore` owns save eligibility, `BeckonGroomingLocationModePresentation` owns shared choice copy, and `BeckonFormPrimitives` owns the keyboard accessory. Feature views compose those contracts without duplicating persistence or keyboard behavior.

**Tech Stack:** SwiftUI, Observation, Swift Testing, Xcode iOS Simulator.

## Global Constraints

- Preserve `CustomerPetsStore.savePet()` repository behavior.
- Preserve grooming-location raw values and matching semantics.
- Keep Request bottom Back as the single back/dismiss action.
- Do not add dependencies, backend changes, or remote writes.
- User owns all in-app manual UI/UX review; Codex performs code-level implementation, automated validation, build, and static audits only.

---

### Task 1: Lock the interaction contracts

**Files:**
- Modify: `ios/Beckon/BeckonTests/CustomerPetFeatureTests.swift`
- Modify: `ios/Beckon/BeckonTests/CustomerRequestFeatureTests+WizardPresentation.swift`
- Modify: `ios/Beckon/BeckonTests/DesignSystemContractTests.swift`
- Modify: `ios/Beckon/BeckonTests/ChatFeatureTests.swift`

**Interfaces:**
- Produces: Pet `formActionTitle`, `hasFormChanges`, and `canSaveForm`; full-width Request progress; role-aware location descriptions; shared Done accessory policy.

- [x] Add failing tests for unchanged/changed Pet form eligibility and Create/Save titles.
- [x] Add failing tests that the Request header has no reserved back width.
- [x] Add failing tests for all four role-aware service-location descriptions.
- [x] Add failing tests that keyboard avoidance and Chat opt into one shared Done accessory with equal trailing/bottom inset.
- [x] Run focused tests and confirm failures are caused by the missing contracts.

### Task 2: Implement Pet navigation save

**Files:**
- Modify: `ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetsStore.swift`
- Modify: `ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetFormView.swift`

**Interfaces:**
- Consumes: Existing `savePet()` and form fields.
- Produces: Snapshot-based `hasFormChanges`, validated `canSaveForm`, and role-specific action title.

- [x] Capture a form snapshot after create/edit initialization and compare current fields plus pending photo state.
- [x] Add the right-side confirmation toolbar action and route it to `savePet()`.
- [x] Remove `CustomerPetFormBottomBar` and stationary action clearance.
- [x] Run focused Pet tests until green.

### Task 3: Simplify Request header and enrich location choices

**Files:**
- Modify: `ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestWizardView.swift`
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonGroomingLocationModeSelector.swift`

**Interfaces:**
- Consumes: Existing bottom Back action and `GroomingLocationMode` selection.
- Produces: Full-width progress header and shared title-plus-description choice rows.

- [x] Remove the header back action and obsolete progress-width inputs.
- [x] Add role-aware descriptions to the shared presentation.
- [x] Render supporting copy below each selector title without changing selection behavior.
- [x] Run focused Request presentation tests until green.

### Task 4: Share Done across every production input

**Files:**
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonFormPrimitives.swift`
- Modify: `ios/Beckon/Beckon/Features/Chat/ChatView.swift`

**Interfaces:**
- Produces: `.beckonKeyboardDoneAccessory()` used internally by `.beckonKeyboardAvoidance` and directly by Chat.

- [x] Extract the existing Done toolbar into a shared modifier with one equal edge inset constant.
- [x] Keep keyboard avoidance behavior unchanged while delegating accessory presentation.
- [x] Attach the accessory to Chat's text-entry hierarchy.
- [x] Audit every production `TextField`, `SecureField`, `TextEditor`, `UITextField`, and `UITextView` owner for direct or inherited coverage.
- [x] Run focused DesignSystem and Chat tests until green.

### Task 5: Validate and close T-336

**Files:**
- Modify: `docs/01_product/DESIGN_SYSTEM.md`
- Modify: `docs/06_tasks/TASK_LEDGER.md`
- Modify: `docs/00_memory/WORKLOG.md`
- Modify: `docs/00_memory/CURRENT_STATE.md`

- [x] Run `./scripts/ios-test.sh` and `./scripts/ios-build.sh`.
- [x] Run source inventory, `node scripts/ui-consistency-audit.mjs check`, and `git diff --check`.
- [x] Update durable documentation and run context hygiene.
- [x] Review the complete diff and prepare the task-scoped `T-336: fix: unify customer form actions and keyboard Done` commit for the standing Git closeout.
