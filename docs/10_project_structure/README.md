# Project Structure Index

This file is the first stop when a path is unclear. It records the current folder ownership map and the few paths that were intentionally left in place because moving them would create more risk than readability.

## Top-Level Map

- `AGENTS.md`: repository operating rules for Codex.
- `README.md`: short project overview and validation commands.
- `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`: original canonical product/engineering brief. Keep at the repository root because active and historical docs cite it there.
- `CLAUDE.md` and `CLAUDE_reference/`: Claude-maintained root reference area. Keep separate from `docs/` by design.
- `.codex/config.toml`: active local Codex project configuration. Historical disabled agent role cards were moved to `docs/09_frozen/agent_team_archive_2026-06-24/archive_agents/`.
- `docs/09_frozen/workspace_initialization_2026-06-24/CODEX_WORKSPACE_INIT.md`: historical workspace initialization prompt.
- `ios/`: Xcode project, SwiftUI app code, tests, and local iOS configuration. Do not move files here without also validating Xcode project references and running the iOS build script.
- `supabase/migrations/`: append-only local mirrors for applied or prepared Supabase migrations. Do not rename, reorder, or nest these files.
- `supabase/drafts/`: draft backend material when present.
- `scripts/`: repository validation and helper commands.
- `docs/`: durable project memory, task records, workflow rules, design references, decisions, and this structure index.
- `supabase_api_key`: local ignored secret. Never read, move into docs, or commit.

## Docs Map

- `docs/00_memory/`: current state, feature index, worklog, and recovery notes.
- `docs/01_product/`: product definitions, roles, flows, screen inventory, and UX rules.
- `docs/02_architecture/`: app architecture, data flow, boundaries, error handling, and fixtures.
- `docs/03_backend/`: Supabase contract, RLS/RPC policy, storage policy, and migration rules.
- `docs/04_ios/`: Swift, SwiftUI, build, testing, and accessibility rules.
- `docs/05_workflow/`: active single-agent workflow and tool policies only.
- `docs/06_tasks/`: task ledger, task templates, task closeouts, and task-specific artifacts.
- `docs/06_tasks/sql_reviews/`: reviewed SQL drafts that were attached to task records before being mirrored as migrations.
- `docs/07_decisions/`: ADR template and decision documentation entrypoint.
- `docs/08_design/`: Groomly design prototype, normalized screenshot assets, extracted tokens, and implementation notes.
- `docs/09_frozen/`: frozen historical snapshots, archived workflow material, disabled agent roles, and initialization prompts for comparison or recovery only.
- `docs/10_project_structure/`: current path map and reorganization history.
- `docs/superpowers/`: historical Superpowers plans/specs. Read only when directly relevant.

## Task Search Guide

- Current task state: `docs/00_memory/CURRENT_STATE.md`.
- Full task ledger: `docs/06_tasks/TASK_LEDGER.md`.
- Task folder guide: `docs/06_tasks/README.md`.
- Workflow rules: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Backend contract: `docs/03_backend/SUPABASE_CONTRACT.md`.
- iOS source root: `ios/PetGroomerMarketplace/PetGroomerMarketplace/`.
- iOS tests: `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/`.
- Design screenshot assets: `docs/08_design/screenshots/`.
- Frozen workflow archive: `docs/09_frozen/workflow_archive_2026-06-24/`.
- Frozen disabled agent archive: `docs/09_frozen/agent_team_archive_2026-06-24/`.

## Paths Moved During Structure Cleanup

The complete record is in `docs/10_project_structure/REORGANIZATION_LOG.md`.

- `docs/06_tasks/T-015_GROOMER_OFFER_BACKEND_REVIEWED_SQL.sql` -> `docs/06_tasks/sql_reviews/T-015_GROOMER_OFFER_BACKEND_REVIEWED_SQL.sql`
- `docs/06_tasks/T-018_OFFER_ACCEPTANCE_BOOKING_REVIEWED_SQL.sql` -> `docs/06_tasks/sql_reviews/T-018_OFFER_ACCEPTANCE_BOOKING_REVIEWED_SQL.sql`
- `docs/06_tasks/T-020_BOOKING_PARTICIPANT_CHAT_REVIEWED_SQL.sql` -> `docs/06_tasks/sql_reviews/T-020_BOOKING_PARTICIPANT_CHAT_REVIEWED_SQL.sql`
- `.codex/archive_agents/` -> `docs/09_frozen/agent_team_archive_2026-06-24/archive_agents/`
- `docs/05_workflow/agent_reports/` -> `docs/09_frozen/workflow_archive_2026-06-24/agent_reports/`
- `docs/05_workflow/archive_subagent_workflow/` -> `docs/09_frozen/workflow_archive_2026-06-24/archive_subagent_workflow/`
- `CODEX_WORKSPACE_INIT.md` -> `docs/09_frozen/workspace_initialization_2026-06-24/CODEX_WORKSPACE_INIT.md`
- `docs/08_design/原型截图/` -> `docs/08_design/screenshots/`

## Do Not Move Without Explicit Follow-Up Approval

- Swift/Xcode source files under `ios/`.
- Any file under `supabase/migrations/`.
- `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`.
- `CLAUDE.md` or `CLAUDE_reference/`.
- `AGENTS.md`.
- `.codex/config.toml`.
- `scripts/`.
- Ignored local secrets such as `supabase_api_key`.
