# T-088: Markdown Baseline Consistency Cleanup

## Status

- Status: completed
- Date: 2026-06-26
- Mode: Quick
- Branch: `codex/pet-fit-structure-cleanup`

## User Request

Deep-clean the project's Markdown files so branch, task, current-state, and archive records use one consistent line and do not create ambiguity for future Codex runs.

## Scope

This is documentation-only cleanup. It may update active project rules, memory files, product/architecture summaries, task guide/ledger records, and archive boundary notes. It must not change Swift, Supabase migrations, scripts, app behavior, backend contracts, or remote state.

## Cleanup Rules

- `codex/pet-fit-structure-cleanup` is the canonical work branch unless the user explicitly names another branch.
- New bugfix and iteration work uses the next available task ID in `docs/06_tasks/TASK_LEDGER.md`.
- Current state comes from `docs/00_memory/CURRENT_STATE.md`, `docs/06_tasks/TASK_LEDGER.md`, and active product/architecture/backend docs.
- `docs/00_memory/WORKLOG.md` is reverse chronological history; older `Next:` lines are historical closeout notes.
- `docs/09_frozen/` is historical-only unless a task explicitly asks for recovery or comparison context.

## Closeout

Changed files:

- `AGENTS.md`
- `docs/README.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/PROJECT_MEMORY.md`
- `docs/00_memory/WORKLOG.md`
- `docs/01_product/NAVIGATION_AND_FLOWS.md`
- `docs/01_product/PRODUCT_BRIEF.md`
- `docs/01_product/SCREEN_INVENTORY.md`
- `docs/01_product/USER_ROLES.md`
- `docs/02_architecture/ARCHITECTURE.md`
- `docs/05_workflow/GITHUB_RULES.md`
- `docs/06_tasks/README.md`
- `docs/06_tasks/T-002_INCREMENTAL_BUILD_ROADMAP.md`
- `docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`
- `docs/06_tasks/T-058_GROOMLY_GROOMER_ACCOUNT_PROFILE_AVAILABILITY.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/09_frozen/README.md`
- `docs/09_frozen/pre_groomly_ui_2026-06-21/FREEZE_README.md`

Validation:

- Branch/wrong-task search returned no matches for known divergent branch markers or wrong task markers.
- Stale active-baseline search returned only the real Offers domain feature ownership, not an old visible groomer Offers tab instruction.
- `git diff --check` passed.

Result:

The Markdown baseline now points future work to `codex/pet-fit-structure-cleanup`, `docs/00_memory/CURRENT_STATE.md`, and `docs/06_tasks/TASK_LEDGER.md`. Product, architecture, role, navigation, screen inventory, and project memory entrypoints now reflect the implemented MVP/Groomly/pet-fit state instead of the early baseline. Historical task/worklog/archive records are marked as historical where needed so older next-task or branch notes are not current instructions.
