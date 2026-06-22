# CLAUDE.md

This file gives Claude Code the minimum active context for this repository.

## Active Phase

The MVP is complete through T-022. T-022 post-MVP next-task suggestions are frozen and recoverable from `docs/09_frozen/pre_groomly_ui_2026-06-21/`.

The completed Groomly foundation sequence is:

```text
docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md
```

The completed first screen-specific Groomly slice is:

```text
docs/06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md
```

The only active next executable task is to create a new T-025 screen-specific Groomly task file before editing additional non-Auth feature screens.

Do not start T-025 implementation, backend work, or other post-MVP tasks automatically.

## Claude's Role

Claude Code's role in this project is review, not implementation.

Without explicit user authorization, Claude must not modify project files, including Swift, Xcode, Supabase, scripts, configuration, or docs. Allowed default actions are read-only review, analysis, and recommendations.

## Current Task Reading Rules

For the next Groomly screen-specific task, read only:

- `AGENTS.md`
- the selected task file under `docs/06_tasks/`
- targeted sections of `docs/00_memory/CURRENT_STATE.md`
- `docs/06_tasks/TASK_LEDGER.md` only when choosing or updating task status
- `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`
- `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
- `docs/08_design/design_tokens.json`
- `docs/01_product/DESIGN_SYSTEM.md`
- the relevant SwiftUI files for the selected screen

Do not read backend docs, old task files, archived workflow docs, frozen snapshots, or full worklog history unless the user explicitly asks for that context.

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
- Product rules: `docs/01_product/`
- Backend contract: `docs/03_backend/`
- Groomly design source: `docs/08_design/`
