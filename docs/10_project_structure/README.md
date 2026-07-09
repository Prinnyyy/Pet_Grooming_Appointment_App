# Project Structure Index

First stop when a path is unclear. Keep this file as a routing table, not a history log.

## Root Paths

| Path | Purpose |
|---|---|
| `AGENTS.md` | Codex operating rules. |
| `CLAUDE.md` | Claude minimum active entrypoint. |
| `README.md` | Short project overview and validation commands. |
| `.rgignore` | Default search exclusions for frozen archives, seed tables, and large design exports. |
| `.codex/config.toml` | Local Codex project configuration. |
| `docs/` | Active durable memory, product, architecture, backend, workflow, task, decision, design, and structure docs. |
| `ios/` | Xcode project, SwiftUI app, and tests. Validate Xcode references before moving anything here. |
| `supabase/migrations/` | Append-only local migration mirrors. Do not rename or reorder. |
| `supabase/drafts/` | Draft backend material when present. |
| `scripts/` | Validation, context hygiene, TestOps, and helper commands. |
| ignored local secrets | `supabase_api_key` and `supabase_environment_variables`; inspect only with explicit authorization and never commit. |

## Docs Paths

| Directory | Purpose |
|---|---|
| `docs/00_memory/` | Current state, feature routing, project memory, recent worklog. |
| `docs/01_product/` | Product rules, roles, flows, screen inventory, UX rules. |
| `docs/02_architecture/` | App architecture, data flow, boundaries, error handling, fixtures. |
| `docs/03_backend/` | Supabase fast path, RLS/RPC, storage, migration rules. |
| `docs/04_ios/` | Swift, SwiftUI, build, testing, accessibility, debug, TestOps. |
| `docs/05_workflow/` | Active workflow, context/recovery, tooling, Git, stop rules. |
| `docs/06_tasks/` | Active ledger, managed roadmap, screenshot/meta-review templates, SQL review index. |
| `docs/07_decisions/` | Decision log and ADR template. |
| `docs/08_design/` | Active Groomly visual notes and screenshot assets. |
| `docs/09_frozen/` | Historical archives; never read by default. |
| `docs/10_project_structure/` | This map and compact reorganization index. |

## Task Search

- Current state: `../00_memory/CURRENT_STATE.md`.
- Current task ledger: `../06_tasks/TASK_LEDGER.md`.
- Recent worklog: `../00_memory/WORKLOG.md`.
- Managed roadmap: `../06_tasks/ROADMAP.md`.
- Workflow: `../05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Context tiers: `../05_workflow/CONTEXT_AND_RECOVERY.md`.
- Tooling and remote gates: `../05_workflow/TOOLING_POLICY.md`.
- Backend contract: `../03_backend/SUPABASE_CONTRACT.md`.
- Frozen archive guide: `../09_frozen/README.md`.
- Move history: `REORGANIZATION_LOG.md`.

## Do Not Move Without Follow-Up Approval

- Swift/Xcode files under `../../ios/`.
- Any file under `../../supabase/migrations/`.
- `../../AGENTS.md`, `../../CLAUDE.md`, `.rgignore`, `.codex/config.toml`, and `../../scripts/`.
- Ignored local secret files.
