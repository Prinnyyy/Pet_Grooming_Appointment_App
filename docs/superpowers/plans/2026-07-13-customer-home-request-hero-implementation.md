# Customer Home Request Hero Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the Customer Home request hero's mint-and-white visual hierarchy while keeping shared primary actions accessible and role-aware.

**Architecture:** Extend `DesignTokens` with role-specific on-accent foregrounds and make `BeckonPrimaryButtonStyle.Accent` select the correct token. Keep the screenshot-specific light mint Hero and white action local to `CustomerHomeRequestHero`, backed by presentation copy so tests can lock natural wrapping.

**Tech Stack:** SwiftUI, Swift Testing, existing Beckon DesignSystem.

## Global Constraints

- Keep the existing customer and groomer brand background colors unchanged.
- Preserve all Customer Home request behavior and identifiers.
- Do not add dependencies, backend changes, or new navigation.
- Do not perform automated visual approval; the user reviews UI manually.

---

### Task 1: Lock the color and copy contracts

**Files:**
- Modify: `ios/Beckon/BeckonTests/DesignTokenAccessibilityTests.swift`
- Modify: `ios/Beckon/BeckonTests/CustomerRequestFeatureTests+WizardPresentation.swift`

**Interfaces:**
- Consumes: `DesignTokens.ColorHex` and `CustomerHomeRequestHeroPresentation`
- Produces: failing expectations for role-specific foregrounds and newline-free hero copy

- [ ] Add tests that require customer and groomer foreground tokens to meet 4.5:1 against their own gradient endpoints.
- [ ] Add a test that requires the hero title to equal `Need grooming for your pet?` and contain no newline.
- [ ] Run the focused tests and confirm RED because the role tokens and presentation copy do not exist.

### Task 2: Implement shared role foregrounds

**Files:**
- Modify: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift`
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonActionPrimitives.swift`

**Interfaces:**
- Consumes: unchanged role gradient endpoints
- Produces: `customerOnAccent`, `groomerOnAccent`, and role-aware `BeckonPrimaryButtonStyle.Accent.foreground`

- [ ] Add deep customer-mint and deep groomer-coral foreground tokens.
- [ ] Select the foreground through the primary button accent instead of a single black token.
- [ ] Run the focused contrast tests and confirm GREEN.

### Task 3: Recompose the Customer Home hero

**Files:**
- Modify: `ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetsView.swift`
- Test: `ios/Beckon/BeckonTests/CustomerRequestFeatureTests+WizardPresentation.swift`

**Interfaces:**
- Consumes: existing hero action/disabled state and customer on-accent token
- Produces: reference-aligned hero with natural title wrapping and a white full-width action

- [ ] Move hero strings into `CustomerHomeRequestHeroPresentation` and remove the embedded newline.
- [ ] Match the reference's sampled light mint gradient, 110pt edge-aligned circle, and diagonal paw decoration.
- [ ] Replace the local filled primary action with a compact white surface action using shared `customerHeroText #333333` foreground and feature-level semantic typography, with unchanged disabled semantics.
- [ ] Keep the action content-sized and make the copy follow its measured width, with available-width contraction on narrower devices.
- [ ] Run focused presentation and accessibility tests and confirm GREEN.

### Task 4: Validate and close out T-341

**Files:**
- Modify: `docs/06_tasks/TASK_LEDGER.md`
- Modify: `docs/00_memory/WORKLOG.md`
- Modify: `docs/00_memory/CURRENT_STATE.md`

**Interfaces:**
- Consumes: validated source and tests
- Produces: durable task closeout, commit, and push

- [ ] Run focused tests, `./scripts/ios-test.sh`, `./scripts/ios-build.sh`, and `git diff --check`.
- [ ] Review the diff for visual-only scope and run context hygiene after memory updates.
- [ ] Record T-341 as completed, preserve T-340 as planned, and set T-342 as next unallocated.
- [ ] Commit and push only T-341 files on `codex/pet-fit-structure-cleanup`.
