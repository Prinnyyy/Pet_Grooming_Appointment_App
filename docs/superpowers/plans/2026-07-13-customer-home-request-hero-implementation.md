# Customer Home Request Hero Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the Customer Home request Hero, then adopt its approved mint and soft-black palette across shared Customer components without changing Groomer or status semantics.

**Architecture:** Define one Display P3 Customer palette in `DesignTokens`, retain temporary compatibility aliases, and make shared primitives choose fill, soft, subtle, and strong roles by semantic purpose. Feature code continues consuming tokens; it must not receive copied raw values. Keep the Hero presentation copy and measured action-driven layout local to `CustomerHomeRequestHero`.

**Tech Stack:** SwiftUI, Swift Testing, existing Beckon DesignSystem.

## Global Constraints

- Replace the old Customer palette through semantic tokens; keep Groomer coral, status colors, warm app background, and white surfaces unchanged.
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
- Consumes: existing hero action/disabled state and Customer Hero tokens
- Produces: reference-aligned hero with natural title wrapping and a content-sized white action

- [ ] Move hero strings into `CustomerHomeRequestHeroPresentation` and remove the embedded newline.
- [ ] Match the reference's sampled light mint gradient, 110pt edge-aligned circle, and diagonal paw decoration.
- [ ] Replace the local filled primary action with a compact white surface action using shared `customerHeroText #333333` foreground and feature-level semantic typography, with unchanged disabled semantics.
- [ ] Keep the action content-sized and make the copy follow its measured width, with available-width contraction on narrower devices.
- [ ] Run focused presentation and accessibility tests and confirm GREEN.

### Task 4: Migrate the global Customer palette

**Files:**
- Modify: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift`
- Modify: shared primitives under `ios/Beckon/Beckon/DesignSystem/`
- Audit: Customer feature views under `ios/Beckon/Beckon/Features/`
- Modify: `ios/Beckon/BeckonTests/DesignTokenAccessibilityTests.swift`

**Interfaces:**
- Consumes: approved accent, soft, subtle, strong, and primary-text roles
- Produces: shared Customer components using one semantic Display P3 palette

- [ ] Add `customerAccent`, `customerAccentSoft`, `customerAccentSubtle`, and `customerAccentStrong` Display P3 roles and change global `textPrimary` to `#333333`.
- [ ] Alias existing Hero values and temporary `customerPrimary` compatibility names to the new roles.
- [ ] Update shared Customer action, selection, form, feedback, image, layout, progress, and tint primitives to consume roles by semantic purpose.
- [ ] Audit remaining Customer feature references and direct colors; preserve Groomer and status semantics.
- [ ] Add contrast/token contract tests for primary text, Customer action fills, strong graphics, and unchanged Groomer/status values.

### Task 5: Validate and close out T-341

**Files:**
- Modify: `docs/06_tasks/TASK_LEDGER.md`
- Modify: `docs/00_memory/WORKLOG.md`
- Modify: `docs/00_memory/CURRENT_STATE.md`

**Interfaces:**
- Consumes: validated source and tests
- Produces: durable task closeout, commit, and push

- [ ] Run focused token/component tests, `./scripts/ios-test.sh`, `./scripts/ios-build.sh`, and `git diff --check`.
- [ ] Review the diff for visual-only scope and run context hygiene after memory updates.
- [ ] Record T-341 as completed, preserve T-340 as planned, and set T-342 as next unallocated.
- [ ] Commit and push only T-341 files on `codex/pet-fit-structure-cleanup`.
