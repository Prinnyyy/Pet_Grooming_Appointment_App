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

The active Groomly foundation sequence is:

```text
docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md
```

The only active next executable task is:

```text
docs/06_tasks/T-023A_GROOMLY_DESIGN_AUDIT_NOTES.md
```

T-023 is split into T-023A through T-023D2. Run one child task per Codex run. Do not redesign feature screens, change backend contracts, or implement deferred features. After T-023D2, create a T-024 screen-specific task file before editing any feature screen.

## Main References

- Agent rules: `AGENTS.md`
- Current state: `docs/00_memory/CURRENT_STATE.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Groomly foundation sequence: `docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`
- Active child task: `docs/06_tasks/T-023A_GROOMLY_DESIGN_AUDIT_NOTES.md`
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
