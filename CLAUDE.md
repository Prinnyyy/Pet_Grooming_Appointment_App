# CLAUDE.md

This file gives Claude Code the minimum active context for this repository.

## Active Phase

The MVP is complete through T-022. T-022 post-MVP next-task suggestions are frozen and recoverable from `docs/09_frozen/pre_groomly_ui_2026-06-21/`.

The completed Groomly foundation sequence is:

```text
docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md
```

The completed screen-specific Groomly slices are:

```text
docs/06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md
docs/06_tasks/T-025_GROOMLY_CUSTOMER_PETS_UI.md
docs/06_tasks/T-026_GROOMLY_CUSTOMER_REQUESTS_LIST_STATUS_UI.md
docs/06_tasks/T-027_GROOMLY_CUSTOMER_REQUEST_WIZARD_UI.md
docs/06_tasks/T-028_GROOMLY_CUSTOMER_REQUEST_DETAIL_OFFERS_UI.md
docs/06_tasks/T-029_GROOMLY_GROOMER_REQUESTS_FEED_DETAIL_UI.md
docs/06_tasks/T-030_GROOMLY_GROOMER_OFFER_FORM_STATUS_UI.md
docs/06_tasks/T-031_GROOMLY_GROOMER_PROFILE_SERVICES_UI.md
docs/06_tasks/T-032_GROOMLY_GROOMER_PORTFOLIO_UI.md
docs/06_tasks/T-033_GROOMLY_BOOKINGS_UI.md
docs/06_tasks/T-034_GROOMLY_CHAT_UI.md
docs/06_tasks/T-035_GROOMLY_ACCOUNT_TABS_DEBUG_FINAL_UI.md
```

The Groomly UI completion sequence is completed:

```text
docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md
```

No active next Groomly UI task is currently defined. Do not start later/post-Groomly tasks, backend work, Admin Dashboard work, or other post-MVP tasks automatically.

## Claude's Role

Claude Code's role in this project is review, not implementation.

Without explicit user authorization, Claude must not modify project files, including Swift, Xcode, Supabase, scripts, configuration, or docs. Allowed default actions are read-only review, analysis, and recommendations.

## Current Task Reading Rules

For the next Groomly screen-specific task, read only:

- `AGENTS.md`
- the selected task file under `docs/06_tasks/`
- `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md` when executing T-026 through T-035
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
