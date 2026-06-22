# Pet Groomer Marketplace

iOS SwiftUI marketplace app for pet grooming appointments.

Current product flow:

```text
Customer publishes an open grooming request
-> matched groomers make offers
-> customer accepts one offer
-> booking and chat are created
-> groomer completes the booking
-> customer leaves a review
```

## Active Phase

The MVP implementation is complete through T-022. T-022 post-MVP next-task suggestions are frozen and recoverable from:

```text
docs/09_frozen/pre_groomly_ui_2026-06-21/
```

The completed Groomly foundation sequence is:

```text
docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md
```

The completed screen-specific Groomly slices are:

```text
docs/06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md
docs/06_tasks/T-025_GROOMLY_CUSTOMER_PETS_UI.md
```

The active next executable task is to create a T-026 Customer Requests Groomly task file before editing request screens. Run one screen-specific Groomly task per Codex run. Do not change backend contracts, product flow, or deferred features during UI slices.

## Main References

- Agent rules: `AGENTS.md`
- Current state: `docs/00_memory/CURRENT_STATE.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Groomly foundation sequence: `docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`
- Completed Auth/Onboarding slice: `docs/06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md`
- Completed Customer Pets/Home slice: `docs/06_tasks/T-025_GROOMLY_CUSTOMER_PETS_UI.md`
- Groomly design prompt: `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`
- Groomly prototype: `docs/08_design/Groomly.html`
- Existing SwiftUI design tokens: `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/DesignTokens.swift`

## Validation Commands

```sh
./scripts/ios-build.sh
./scripts/ios-test.sh
./scripts/preflight.sh
./scripts/supabase-check.sh
```
