# CLAUDE.md

This file gives Claude Code the minimum active context for this repository.

## Active Phase

The MVP implementation is complete and the implemented Groomly UI phase is historical. Current task state and numbering live in `docs/06_tasks/TASK_LEDGER.md`.

Detailed task records, including T-001 through T-088 and completed Groomly UI records, are archived under:

```text
docs/09_frozen/task_records_2026-06-26/
```

No active next Groomly UI, pet-fit, availability, backend, or screenshot task is currently defined. Start new work only from an explicit user request and the next available task ID in the ledger.

## Claude's Role

Claude Code's role in this project is review, not implementation.

Without explicit user authorization, Claude must not modify project files, including Swift, Xcode, Supabase, scripts, configuration, or docs. Allowed default actions are read-only review, analysis, and recommendations.

## Current Task Reading Rules

For the next Groomly screen-specific task, read only:

- `AGENTS.md`
- `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
- `docs/05_workflow/CONTEXT_AND_RECOVERY.md` when read-budget or recovery decisions matter
- targeted sections of `docs/00_memory/CURRENT_STATE.md`
- `docs/06_tasks/TASK_LEDGER.md` only when choosing or updating task status
- `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` when a screenshot task is active
- `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`
- `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
- `docs/08_design/design_tokens.json`
- `docs/01_product/DESIGN_SYSTEM.md`
- the relevant SwiftUI files for the selected screen

Do not read backend docs, old task files, archived workflow docs, frozen snapshots, or full worklog history unless the user explicitly asks for that context or the task directly requires it.

## Non-Negotiable Boundaries

- Preserve the Open Request -> Groomer Offer -> Customer Confirmation -> Booking model.
- SwiftUI views must not call Supabase directly.
- Do not change backend schema, RLS, RPCs, repositories, role routing, or product behavior during Groomly UI screen slices.
- Do not copy HTML/CSS/React code directly into SwiftUI.
- Treat unsupported prototype features as visual inspiration only.
- Do not expose tokens, API keys, passwords, raw secrets, or full user identifiers.

## Validation Commands

Use only when the active task requires them:

```sh
./scripts/ios-build.sh
./scripts/ios-test.sh
./scripts/preflight.sh
./scripts/supabase-check.sh
```

Use the selected task file's validation commands. Standard SwiftUI screen slices should make one `./scripts/ios-build.sh` attempt by default.

## Source of Truth

- Current state: `docs/00_memory/CURRENT_STATE.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Context/recovery: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`
- Product rules: `docs/01_product/`
- Backend contract: `docs/03_backend/`
- Groomly design source: `docs/08_design/`
