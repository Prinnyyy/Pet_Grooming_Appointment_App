# Project Structure Index

This file is the first stop when a path is unclear. It records the current folder ownership map and the few paths that were intentionally left in place because moving them would create more risk than readability.

## Top-Level Map

- `AGENTS.md`: repository operating rules for Codex.
- `README.md`: short project overview and validation commands.
- `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`: original canonical product/engineering brief. Keep at the repository root because active and historical docs cite it there.
- `CLAUDE.md` and `CLAUDE_reference/`: Claude-maintained root reference area. Keep separate from `docs/` by design.
- `.codex/config.toml`: active local Codex project configuration.
- `docs/09_frozen/agent_team_archive_2026-06-24/archive_agents/`: historical disabled agent role cards.
- `docs/09_frozen/task_records_2026-06-26/`: detailed historical task records moved out of the active task directory.
- `docs/09_frozen/superpowers_2026-06-26/`: historical Superpowers plans/specs moved out of the active docs directory.
- `docs/09_frozen/workflow_docs_2026-06-26/`: superseded workflow/context/tool policy docs consolidated into active workflow entrypoints.
- `docs/09_frozen/workspace_initialization_2026-06-24/`: historical workspace initialization prompt archive.
- `ios/`: Xcode project, SwiftUI app code, tests, and local iOS configuration. Do not move files here without also validating Xcode project references and running the iOS build script.
- `supabase/migrations/`: append-only local mirrors for applied or prepared Supabase migrations. Do not rename, reorder, or nest these files.
- `supabase/drafts/`: draft backend material when present.
- `scripts/`: repository validation and helper commands.
- `docs/`: durable project memory, task records, workflow rules, design references, decisions, and this structure index.
- `supabase_api_key`: local ignored secret. Never read, move into docs, or commit.

## Docs Map

- `docs/00_memory/`: current state, feature index, project memory, decision log, and worklog.
- `docs/01_product/`: product definitions, roles, flows, screen inventory, and UX rules.
- `docs/02_architecture/`: app architecture, data flow, boundaries, error handling, and fixtures.
- `docs/03_backend/`: Supabase contract, RLS/RPC policy, storage policy, and migration rules.
- `docs/04_ios/`: Swift, SwiftUI, build, testing, and accessibility rules.
- `docs/05_workflow/`: active single-agent workflow, context/recovery access tiers, tooling policy, GitHub rules, stop rules, and final-report template.
- `docs/06_tasks/`: active task ledger, task templates, and task-specific artifacts. Detailed completed task records are frozen under `docs/09_frozen/task_records_2026-06-26/`.
- `docs/06_tasks/sql_reviews/`: reviewed SQL drafts that were attached to task records before being mirrored as migrations.
- `docs/07_decisions/`: ADR template and decision documentation entrypoint.
- `docs/08_design/`: Groomly design prototype, normalized screenshot assets, extracted tokens, and implementation notes.
- `docs/09_frozen/`: frozen historical snapshots, archived workflow material, disabled agent roles, and initialization prompts for comparison or recovery only.
- `docs/10_project_structure/`: current path map and reorganization history.

## Task Search Guide

- Current task state: `docs/00_memory/CURRENT_STATE.md`.
- Full task ledger: `docs/06_tasks/TASK_LEDGER.md`.
- Frozen detailed task records: `docs/09_frozen/task_records_2026-06-26/`.
- Task folder guide: `docs/06_tasks/README.md`.
- Workflow rules: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Context and recovery tiers: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`.
- Tooling policy: `docs/05_workflow/TOOLING_POLICY.md`.
- Backend contract: `docs/03_backend/SUPABASE_CONTRACT.md`.
- iOS source root: `ios/PetGroomerMarketplace/PetGroomerMarketplace/`.
- iOS tests: `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/`.
- Design screenshot assets: `docs/08_design/screenshots/`.
- Frozen workflow archive: `docs/09_frozen/workflow_archive_2026-06-24/`.
- Frozen disabled agent archive: `docs/09_frozen/agent_team_archive_2026-06-24/`.

## Move History

Path move details live in `docs/10_project_structure/REORGANIZATION_LOG.md`.

## Do Not Move Without Explicit Follow-Up Approval

- Swift/Xcode source files under `ios/`.
- Any file under `supabase/migrations/`.
- `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`.
- `CLAUDE.md` or `CLAUDE_reference/`.
- `AGENTS.md`.
- `.codex/config.toml`.
- `scripts/`.
- Ignored local secrets such as `supabase_api_key`.
