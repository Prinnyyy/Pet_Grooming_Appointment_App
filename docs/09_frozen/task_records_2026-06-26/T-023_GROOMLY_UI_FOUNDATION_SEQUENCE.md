# T-023 - Groomly UI Foundation Sequence

- State: completed historical sequence; this file preserves the original execution plan.
- Mode: split into Quick/Standard child tasks.
- Depends on: T-022 completion and the Groomly design files under `docs/08_design/`.
- Active source prompt: `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`.

Current task status and next-work decisions live in `docs/06_tasks/TASK_LEDGER.md` and `docs/00_memory/CURRENT_STATE.md`. Any "active next" language below describes the sequence state when T-023 was being executed, not the current project queue.

## Goal

Start the Groomly UI phase in small, reversible steps before any feature-screen redesign. This sequence replaces the previous single large "Groomly UI Design Audit and Tokens" task.

## Execution Order

Run exactly one child task per Codex run:

1. `T-023A_GROOMLY_DESIGN_AUDIT_NOTES.md`
2. `T-023B_GROOMLY_DESIGN_TOKENS_JSON.md`
3. `T-023C_GROOMLY_SWIFTUI_TOKEN_FOUNDATION.md`
4. `T-023D1_GROOMLY_SWIFTUI_ACTION_PRIMITIVES.md`
5. `T-023D2_GROOMLY_SWIFTUI_FEEDBACK_PRIMITIVES.md`

At sequence start, the first child task was T-023A. Do not use this historical sequence record as a current next-task instruction.

## Shared Rules

- Preserve the current Open Request -> Groomer Offer -> Customer Confirmation -> Booking model.
- Do not reintroduce the old direct "task card sent to groomer" flow.
- Do not copy HTML, CSS, React, or generated web code directly into SwiftUI.
- Do not change backend schemas, migrations, RLS, grants, RPCs, Storage policy, repositories, role routing, or product behavior.
- Do not implement deferred features shown by the prototype.
- Product correctness and accessibility take priority over visual matching.
- Keep every child task small enough to stop after one validation pass.

## Child Task Summary

| ID | Mode | Primary output | Validation |
|---|---|---|---|
| T-023A | Quick | `docs/08_design/UI_IMPLEMENTATION_NOTES.md` | `git diff --check` |
| T-023B | Quick | `docs/08_design/design_tokens.json` | JSON lint and `git diff --check` |
| T-023C | Standard | `DesignSystem/DesignTokens.swift` Groomly token foundation | `./scripts/ios-build.sh`, `git diff --check` |
| T-023D1 | Standard | Button, card, and chip primitives in `DesignSystem/` | `./scripts/ios-build.sh`, `git diff --check` |
| T-023D2 | Standard | Feedback, loading, empty-state, and section-header primitives in `DesignSystem/` | `./scripts/ios-build.sh`, `git diff --check` |

## Completion Criteria

The Groomly foundation sequence is complete only after T-023D2 passes validation and memory docs record the final state. After that, the next action must be creating a new T-024 screen-specific Groomly task file. Do not directly edit feature screens after T-023D2, and do not start backend or post-MVP feature work.
