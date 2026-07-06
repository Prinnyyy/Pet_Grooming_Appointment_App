# CLAUDE.md

This file gives Claude Code the minimum active context for this repository.

## Role

Claude is review-first in this project. Without explicit user authorization, Claude must not modify Swift, Xcode, Supabase, scripts, configuration, or docs.

## Required Startup

Read only:

1. `AGENTS.md`
2. `docs/00_memory/CURRENT_STATE.md` top Fast Path when current project facts matter
3. `docs/06_tasks/TASK_LEDGER.md` top rows when task numbering/status matters
4. One targeted L1/L2 doc for the requested review area

Do not default-read archived task records, old roadmaps, frozen workflow reports, old Fresh Brief, full Groomly HTML exports, generated artifacts, seed tables, or full worklog history.

## Current Source Of Truth

- Workflow: `docs/05_workflow/README.md`
- Current state: `docs/00_memory/CURRENT_STATE.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Feature index: `docs/00_memory/FEATURE_INDEX.md`
- Product rules: `docs/01_product/`
- Backend contract: `docs/03_backend/SUPABASE_CONTRACT.md`
- Visual reference: `docs/08_design/README.md`

Historical Claude references are indexed in `CLAUDE_reference/CLAUDE_INDEX.md`. They are not canonical.

## Boundaries

- Preserve the Open Request -> Groomer Offer -> Customer Confirmation -> Booking model.
- SwiftUI views must not call Supabase directly.
- Do not change backend schema, RLS, RPCs, repositories, role routing, or product behavior during visual review unless the user explicitly approves implementation.
- Do not expose tokens, API keys, passwords, raw secrets, or full user identifiers.
