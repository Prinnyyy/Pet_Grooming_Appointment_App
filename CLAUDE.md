# CLAUDE.md

This file gives Claude Code the minimum active context for this repository.

## Active Phase

The MVP is complete through T-022. T-022 post-MVP next-task suggestions are frozen and recoverable from `docs/09_frozen/pre_groomly_ui_2026-06-21/`.

The active Groomly foundation sequence is:

```text
docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md
```

The only active next executable task is:

```text
docs/06_tasks/T-023A_GROOMLY_DESIGN_AUDIT_NOTES.md
```

Do not start T-023B/C/D1/D2, T-024, backend work, or other post-MVP tasks automatically.

## Claude's Role

Claude Code's role in this project is review, not implementation.

Without explicit user authorization, Claude must not modify project files, including Swift, Xcode, Supabase, scripts, configuration, or docs. Allowed default actions are read-only review, analysis, and recommendations.

## Current Task Reading Rules

For T-023A, read only:

- `AGENTS.md`
- `docs/06_tasks/T-023A_GROOMLY_DESIGN_AUDIT_NOTES.md`
- `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`
- `docs/08_design/Groomly.html`
- `docs/08_design/Groomly/`
- `docs/01_product/SCREEN_INVENTORY.md`
- the current SwiftUI file list, if needed

Do not read backend docs, old task files, archived workflow docs, frozen snapshots, or full worklog history unless the user explicitly asks for that context.

## Non-Negotiable Boundaries

- Preserve the Open Request -> Groomer Offer -> Customer Confirmation -> Booking model.
- SwiftUI views must not call Supabase directly.
- Do not change backend schema, RLS, RPCs, repositories, role routing, or product behavior during T-023A.
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

T-023A is documentation-only and should use `git diff --check`, not `ios-build.sh`.

## Source of Truth

- Current state: `docs/00_memory/CURRENT_STATE.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Product rules: `docs/01_product/`
- Backend contract: `docs/03_backend/`
- Groomly design source: `docs/08_design/`
