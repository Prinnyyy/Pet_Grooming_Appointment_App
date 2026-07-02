# Project Structure Index

This file is the first stop when a path is unclear. It records the current folder ownership map and the few paths that were intentionally left in place because moving them would create more risk than readability.

## Top-Level Map

- `AGENTS.md`: repository operating rules for Codex.
- `.rgignore`: default ripgrep ignore rules for historical archives, generated artifacts, machine-readable seed profile tables, and large design exports.
- `README.md`: short project overview and validation commands.
- `CLAUDE.md` and `CLAUDE_reference/`: Claude-maintained root reference area. Keep separate from `docs/` by design.
- `.codex/config.toml`: active local Codex project configuration.
- `docs/09_frozen/agent_team_archive_2026-06-24/archive_agents/`: historical disabled agent role cards.
- `docs/09_frozen/task_records_2026-06-26/`: detailed historical task records moved out of the active task directory.
- `docs/09_frozen/superpowers_2026-06-26/`: historical Superpowers plans/specs moved out of the active docs directory.
- `docs/09_frozen/workflow_docs_2026-06-26/`: superseded workflow/context/tool policy docs consolidated into active workflow entrypoints.
- `docs/09_frozen/workspace_initialization_2026-06-24/`: historical workspace initialization prompt archive.
- `docs/09_frozen/current_state_snapshots/`: pre-trim snapshots of active current-state memory.
- `docs/09_frozen/worklogs/`: archived verbatim worklog history moved out of the active worklog.
- `docs/09_frozen/task_ledgers/`: archived completed task-ledger rows moved out of the active ledger.
- `docs/09_frozen/backend_contracts/`: archived long-form backend contract snapshots moved out of the active fast-path backend contract.
- `docs/09_frozen/backend_policies/`: archived pre-trim backend policy/runbook snapshots moved out of active backend context.
- `docs/09_frozen/feature_indexes/`: archived pre-trim feature index snapshots moved out of active memory context.
- `docs/09_frozen/design_prompts/`: archived historical design-task prompts moved out of active design context.
- `docs/09_frozen/design_notes/`: archived pre-slim design-system and Groomly UI audit notes moved out of active design context.
- `docs/09_frozen/product_briefs/`: archived original product/engineering briefs moved out of active root context.
- `docs/09_frozen/memory_pointers/`: archived removed compatibility pointers.
- `docs/09_frozen/workflow_templates/`: archived removed low-use workflow templates.
- `docs/09_frozen/task_templates/`: archived removed generic task templates.
- `ios/`: Xcode project, SwiftUI app code, tests, and local iOS configuration. Do not move files here without also validating Xcode project references and running the iOS build script.
- `supabase/migrations/`: append-only local mirrors for applied or prepared Supabase migrations. Do not rename, reorder, or nest these files.
- `supabase/drafts/`: draft backend material when present.
- `scripts/`: repository validation, TestOps automation, and helper commands.
- `scripts/context-hygiene-check.mjs`: read-only Markdown/context budget, link, hidden-path, and credential-wording check.
- `docs/`: durable project memory, task records, workflow rules, design references, decisions, and this structure index.
- `supabase_api_key` and `supabase_environment_variables`: local ignored Supabase credential files. Inspect only with explicit user authorization for the current operation; never move into docs, print, or commit.

## Docs Map

- `docs/00_memory/`: current state, feature index, project memory, and worklog.
- `docs/01_product/`: product definitions, roles, flows, screen inventory, and UX rules.
- `docs/02_architecture/`: app architecture, data flow, boundaries, error handling, and fixtures.
- `docs/03_backend/`: Supabase contract, RLS/RPC policy, storage policy, and migration rules.
- `docs/04_ios/`: Swift, SwiftUI, build, testing, accessibility, and DEBUG diagnostic rules.
- `docs/05_workflow/`: active single-agent workflow, context/recovery access tiers, tooling policy, GitHub rules, and stop rules.
- `docs/06_tasks/`: active task ledger, screenshot task checklist, handoff/review templates, and task-specific artifacts. Detailed completed task records are frozen under `docs/09_frozen/task_records_2026-06-26/`.
- `docs/06_tasks/sql_reviews/`: reviewed SQL drafts that were attached to task records before being mirrored as migrations.
- `docs/07_decisions/`: ADR template and canonical decision log.
- `docs/08_design/`: Groomly design prototype, normalized screenshot assets, extracted tokens, and implementation notes.
- `docs/09_frozen/`: frozen historical snapshots, archived workflow material, disabled agent roles, and initialization prompts for comparison or recovery only.
- `docs/10_project_structure/`: current path map and reorganization history.

## Task Search Guide

- Current task state: `docs/00_memory/CURRENT_STATE.md`.
- Active/recent task ledger: `docs/06_tasks/TASK_LEDGER.md`.
- Archived task ledger rows: `docs/09_frozen/task_ledgers/`.
- Archived worklog history: `docs/09_frozen/worklogs/`.
- Archived current-state snapshots: `docs/09_frozen/current_state_snapshots/`.
- Frozen detailed task records: `docs/09_frozen/task_records_2026-06-26/`.
- Task folder guide: `docs/06_tasks/README.md`.
- Workflow rules: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Context and recovery tiers: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`.
- Tooling policy: `docs/05_workflow/TOOLING_POLICY.md`.
- Backend contract: `docs/03_backend/SUPABASE_CONTRACT.md`.
- Full pre-trim backend contract snapshots: `docs/09_frozen/backend_contracts/`.
- Frozen backend policy snapshots: `docs/09_frozen/backend_policies/`.
- Frozen feature index snapshots: `docs/09_frozen/feature_indexes/`.
- Frozen design prompts: `docs/09_frozen/design_prompts/`.
- Frozen design notes: `docs/09_frozen/design_notes/`.
- Frozen product briefs: `docs/09_frozen/product_briefs/`.
- Removed memory pointers: `docs/09_frozen/memory_pointers/`.
- Removed workflow templates: `docs/09_frozen/workflow_templates/`.
- Removed task templates: `docs/09_frozen/task_templates/`.
- Test resource index: `docs/02_architecture/test_resources/README.md`.
- iOS source root: `ios/PetGroomerMarketplace/PetGroomerMarketplace/`.
- iOS tests: `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/`.
- Debug Console and structured event logs: `docs/04_ios/DEBUG_CONSOLE.md`.
- TestOps automation module: `docs/04_ios/testops/README.md`.
- Design screenshot assets: `docs/08_design/screenshots/`.
- Frozen workflow archive: `docs/09_frozen/workflow_archive_2026-06-24/`.
- Frozen disabled agent archive: `docs/09_frozen/agent_team_archive_2026-06-24/`.

## Move History

Path move details live in `docs/10_project_structure/REORGANIZATION_LOG.md`.

## Do Not Move Without Explicit Follow-Up Approval

- Swift/Xcode source files under `ios/`.
- Any file under `supabase/migrations/`.
- `CLAUDE.md` or `CLAUDE_reference/`.
- `AGENTS.md`.
- `.rgignore`.
- `.codex/config.toml`.
- `scripts/`.
- Ignored local secrets such as `supabase_api_key` and `supabase_environment_variables`.
