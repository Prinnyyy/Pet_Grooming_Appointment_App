# Reorganization Log

This log records repository structure changes so future agents do not lose track of moved paths.

## 2026-07-02 - Active Design Document Slimming

Scope:

- Preserve full design-system and Groomly UI audit history in frozen archives.
- Keep active design entrypoints focused on current UI rules, screenshot workflow, tokens, and safety boundaries.
- Add design-doc word budgets to the context hygiene check.

Moved or trimmed paths:

| Active path | Frozen path | Reason |
|---|---|---|
| `docs/01_product/DESIGN_SYSTEM.md` | `docs/09_frozen/design_notes/DESIGN_SYSTEM_2026-07-02_PRE_SLIM.md` | Remove completed T-023 through T-035 historical narrative and long component tables from active product context. |
| `docs/08_design/UI_IMPLEMENTATION_NOTES.md` | `docs/09_frozen/design_notes/UI_IMPLEMENTATION_NOTES_2026-07-02_PRE_SLIM.md` | Remove long prototype file inventory, screen catalog, mapping table, and asset audit from active design context. |

Validation:

- `git diff --check` passed.
- `node scripts/context-hygiene-check.mjs` passed with active design docs under budget.

## 2026-07-02 - Pointer and Lightweight Template Cleanup

Scope:

- Remove active compatibility/template files after preserving their original text in frozen archives.
- Keep Claude-specific files active because the user still uses Claude, but update their paths to current product/design/workflow entrypoints.

Moved or removed paths:

| Old active path | Frozen/current path | Reason |
|---|---|---|
| `docs/00_memory/DECISION_LOG.md` | `docs/09_frozen/memory_pointers/DECISION_LOG_POINTER_2026-07-02.md`; current source is `docs/07_decisions/DECISION_LOG.md` | The compatibility pointer no longer justifies an active file. |
| `docs/05_workflow/LIGHTWEIGHT_FINAL_REPORT_TEMPLATE.md` | `docs/09_frozen/workflow_templates/LIGHTWEIGHT_FINAL_REPORT_TEMPLATE_2026-07-02.md`; current source is `AGENTS.md` final-response rules | The template duplicated active workflow closeout rules. |
| `docs/06_tasks/LIGHTWEIGHT_TASK_PROMPT_TEMPLATE.md` | `docs/09_frozen/task_templates/LIGHTWEIGHT_TASK_PROMPT_TEMPLATE_2026-07-02.md`; current source is `docs/06_tasks/TASK_LEDGER.md` plus workflow rules | Generic prompt specs are no longer created by default. |
| `docs/06_tasks/TASK_INTAKE_TEMPLATE.md` | `docs/09_frozen/task_templates/TASK_INTAKE_TEMPLATE_2026-07-02.md`; current source is `docs/06_tasks/TASK_LEDGER.md` plus short inline spec fields when needed | Generic intake files are no longer active workflow artifacts. |
| `CLAUDE.md`, `CLAUDE_reference/` | Kept active with corrected pointers to `PRODUCT_BRIEF.md`, `UI_IMPLEMENTATION_NOTES.md`, and current task/memory docs | The user still uses Claude, so these files remain but must not point at deleted active files. |

Validation:

- Active stale-reference search passed outside historical worklog/reorganization text.
- `git diff --check` passed.
- `node scripts/context-hygiene-check.mjs` passed.

## 2026-07-02 - Active Historical Pointer Cleanup

Scope:

- Remove completed historical prompt/brief files from active context after preserving their original text in frozen archives.
- Route future product and design work through current concise entrypoints instead of root or active pointer files.

Moved or removed paths:

| Old active path | Frozen/current path | Reason |
|---|---|---|
| `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` | `docs/09_frozen/product_briefs/FRESH_PET_GROOMER_MARKETPLACE_ENGINEERING_BRIEF_2026-07-02.md`; current source is `docs/01_product/PRODUCT_BRIEF.md` | The root brief was a completed rebuild source and no longer belongs in daily active context. |
| `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md` | `docs/09_frozen/design_prompts/GROOMLY_DESIGN_PROMPT_2026-07-02_PRE_INDEX_TRIM.md`; current source is `docs/08_design/UI_IMPLEMENTATION_NOTES.md` | The active pointer had served its compatibility purpose and kept a historical prompt visible in active docs. |

Validation:

- Active reference search passed after updating product, design, structure, and README indexes.
- `git diff --check` passed.
- `node scripts/context-hygiene-check.mjs` passed.

## 2026-07-02 - Indexed AI Collaboration Rules and Policy Trims

Scope:

- Turn active workflow docs into L0-L4 access rules and single-source task protocol.
- Move long historical policy/index/design text out of active context while preserving verbatim archives.
- Add a read-only context hygiene check for word budgets, links, hidden paths, and stale credential wording.

Changed paths:

| Path | Change | Reason |
|---|---|---|
| `AGENTS.md` | Compressed to hard entry rules. | Keep startup context small and route details to workflow docs. |
| `docs/05_workflow/CONTEXT_AND_RECOVERY.md` | Rewritten around L0-L4 access, expansion rules, recovery, and budgets. | Make context growth explicit and verifiable. |
| `docs/00_memory/FEATURE_INDEX.md` | Rewritten as a compact routing index. | Remove task timelines from active lookup context. |
| `docs/03_backend/RLS_RPC_POLICY.md`, `STORAGE_POLICY.md`, `MIGRATION_RULES.md` | Rewritten as current-rule indexes. | Keep backend history traceable without loading it by default. |
| `docs/04_ios/testops/TESTOPS_MEMORY.md` | Rewritten as current capability/limit memory. | Keep TestOps task history in ledger/worklog/results instead. |
| Historical Groomly design task prompt | Replaced by a short active pointer to frozen full text. T-147 later removed that active pointer entirely. | Avoid loading a completed historical UI task prompt as active context. |
| `scripts/context-hygiene-check.mjs` | Added read-only hygiene check. | Give future tasks one command for context budget and search-path validation. |

New archive families:

- `docs/09_frozen/backend_policies/`
- `docs/09_frozen/feature_indexes/`
- `docs/09_frozen/design_prompts/`

## 2026-07-02 - Markdown Fast-Path and Search Hygiene

Scope:

- Reduce duplicate active decision-log ownership.
- Keep backend contract details traceable without loading the long contract by default.
- Make broad text search skip frozen/heavy paths unless a task explicitly opts in.
- Preserve T-129 seed profile tables as machine-readable script inputs rather than trimming them in place.

Changed paths:

| Path | Change | Reason |
|---|---|---|
| `docs/07_decisions/DECISION_LOG.md` | Promoted as the single complete durable decision log. | Avoid two active decision-log sources. |
| `docs/00_memory/DECISION_LOG.md` | Replaced with a compatibility pointer to `../07_decisions/DECISION_LOG.md`. | Preserve old links without maintaining duplicate decision entries. |
| `.rgignore` | Added default ripgrep ignores for `docs/09_frozen/**`, `artifacts/**`, T-129 seed profile tables, and Groomly HTML exports. | Keep ordinary searches focused on active context. |
| `docs/09_frozen/backend_contracts/SUPABASE_CONTRACT_2026-07-01_PRE_FAST_PATH_TRIM.md` | Added archived long-form backend contract snapshot. | Preserve pre-trim backend detail verbatim. |
| `docs/03_backend/SUPABASE_CONTRACT.md` | Rewritten as a fast-path contract index. | Route detailed backend facts to focused policy docs, migrations, or archive on demand. |
| `docs/02_architecture/test_resources/README.md` | Added test-resource directory index. | Explain that T-129 profile docs are parser inputs and default-search ignored. |

Validation:

- Active Markdown link check passed.
- `git diff --check` passed.
- T-129 seed parser dry-runs passed.
- Reference checks confirmed active docs point to canonical decision and archive paths.

## 2026-06-26 - Markdown Information Architecture Optimization

Scope:

- Reduce active workflow Markdown entrypoints without changing app behavior, Supabase schema, migrations, scripts, or root source ownership.
- Consolidate duplicated context/recovery rules into one active access-tier document.
- Consolidate duplicated tool/MCP/Superpowers/validation rules into one active tooling policy.
- Keep root `CLAUDE.md` and `CLAUDE_reference/` in place, but mark them as on-demand reference rather than default startup context. The former root product brief was still kept at this time and later archived by the 2026-07-02 active historical pointer cleanup.

Moved paths:

| Old path | New path | Reason |
|---|---|---|
| `docs/05_workflow/CODEX_WORKFLOW.md` | `docs/09_frozen/workflow_docs_2026-06-26/CODEX_WORKFLOW.md` | Superseded by `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`. |
| `docs/05_workflow/CONTEXT_MANAGEMENT.md` | `docs/09_frozen/workflow_docs_2026-06-26/CONTEXT_MANAGEMENT.md` | Consolidated into `docs/05_workflow/CONTEXT_AND_RECOVERY.md`. |
| `docs/05_workflow/INTERRUPTION_RECOVERY.md` | `docs/09_frozen/workflow_docs_2026-06-26/INTERRUPTION_RECOVERY.md` | Consolidated into `docs/05_workflow/CONTEXT_AND_RECOVERY.md`. |
| `docs/00_memory/COMPRESSION_RECOVERY.md` | `docs/09_frozen/workflow_docs_2026-06-26/COMPRESSION_RECOVERY.md` | Consolidated into `docs/05_workflow/CONTEXT_AND_RECOVERY.md`. |
| `docs/00_memory/CONTEXT_RECOVERY_PROTOCOL.md` | `docs/09_frozen/workflow_docs_2026-06-26/CONTEXT_RECOVERY_PROTOCOL.md` | Consolidated into `docs/05_workflow/CONTEXT_AND_RECOVERY.md`. |
| `docs/05_workflow/TOOL_RULES.md` | `docs/09_frozen/workflow_docs_2026-06-26/TOOL_RULES.md` | Consolidated into `docs/05_workflow/TOOLING_POLICY.md`. |
| `docs/05_workflow/TOOL_USAGE_POLICY.md` | `docs/09_frozen/workflow_docs_2026-06-26/TOOL_USAGE_POLICY.md` | Consolidated into `docs/05_workflow/TOOLING_POLICY.md`. |
| `docs/05_workflow/MCP_USAGE_POLICY.md` | `docs/09_frozen/workflow_docs_2026-06-26/MCP_USAGE_POLICY.md` | Consolidated into `docs/05_workflow/TOOLING_POLICY.md`. |
| `docs/05_workflow/SUPERPOWERS_USAGE_POLICY.md` | `docs/09_frozen/workflow_docs_2026-06-26/SUPERPOWERS_USAGE_POLICY.md` | Consolidated into `docs/05_workflow/TOOLING_POLICY.md`. |

New active files:

- `docs/05_workflow/CONTEXT_AND_RECOVERY.md`: access tiers, do-not-read-by-default list, durable memory, interruption recovery, and compaction rules.
- `docs/05_workflow/TOOLING_POLICY.md`: tool, validation, editing, iOS, Supabase, MCP/plugin, Git/GitHub, and Superpowers policy.

Validation:

- `git diff --check` passed.
- Active-path stale reference search passed; remaining old task-file references are historical text in `WORKLOG.md`, `REORGANIZATION_LOG.md`, or frozen archives.

## 2026-06-24 - Documentation Structure Cleanup

Scope:

- Improve path readability without changing app behavior, Supabase schema, migrations, or build scripts.
- Keep high-risk app/build/backend roots in place and document why they were not moved.
- Move task SQL review attachments into a dedicated task subfolder.
- Move disabled agent role cards, archived workflow reports, archived subagent workflow docs, and the historical initialization prompt into `docs/09_frozen/`.
- Rename prototype screenshot assets into stable ASCII paths under `docs/08_design/screenshots/`.
- Add navigation docs for project structure, task records, frozen archives, and design assets.
- Remove local `.DS_Store` filesystem artifacts after the tracked documentation changes.

Moved paths:

| Old path | New path | Reason |
|---|---|---|
| `docs/06_tasks/T-015_GROOMER_OFFER_BACKEND_REVIEWED_SQL.sql` | `docs/06_tasks/sql_reviews/T-015_GROOMER_OFFER_BACKEND_REVIEWED_SQL.sql` | Keep reviewed SQL attachments out of the main task-doc listing while preserving task ownership. |
| `docs/06_tasks/T-018_OFFER_ACCEPTANCE_BOOKING_REVIEWED_SQL.sql` | `docs/06_tasks/sql_reviews/T-018_OFFER_ACCEPTANCE_BOOKING_REVIEWED_SQL.sql` | Keep reviewed SQL attachments out of the main task-doc listing while preserving task ownership. |
| `docs/06_tasks/T-020_BOOKING_PARTICIPANT_CHAT_REVIEWED_SQL.sql` | `docs/06_tasks/sql_reviews/T-020_BOOKING_PARTICIPANT_CHAT_REVIEWED_SQL.sql` | Keep reviewed SQL attachments out of the main task-doc listing while preserving task ownership. |
| `.codex/archive_agents/` | `docs/09_frozen/agent_team_archive_2026-06-24/archive_agents/` | Remove disabled historical role cards from the active project root. |
| `docs/05_workflow/agent_reports/` | `docs/09_frozen/workflow_archive_2026-06-24/agent_reports/` | Keep old agent-team reports available without making them part of active workflow navigation. |
| `docs/05_workflow/archive_subagent_workflow/` | `docs/09_frozen/workflow_archive_2026-06-24/archive_subagent_workflow/` | Move the superseded subagent workflow out of the active workflow directory. |
| `docs/06_tasks/T-*.md` and completed workflow task records | `docs/09_frozen/task_records_2026-06-26/` | Keep one active task-status record in `docs/06_tasks/TASK_LEDGER.md` while preserving detailed task history. |
| `docs/superpowers/plans/` and `docs/superpowers/specs/` Markdown files | `docs/09_frozen/superpowers_2026-06-26/` | Move historical planning/spec artifacts out of the active docs tree. |
| `CODEX_WORKSPACE_INIT.md` | `docs/09_frozen/workspace_initialization_2026-06-24/CODEX_WORKSPACE_INIT.md` | Keep the root focused on active project entrypoints. |
| `docs/08_design/原型截图/` | `docs/08_design/screenshots/` | Replace non-ASCII, space-containing screenshot paths with stable ASCII names. |

Screenshot filename mapping:

| Old filename under `docs/08_design/原型截图/` | New path |
|---|---|
| `截屏2026-06-22 上午2.05.17.png` | `docs/08_design/screenshots/screenshot-2026-06-22-am-02-05-17.png` |
| `截屏2026-06-22 上午12.26.36.png` | `docs/08_design/screenshots/screenshot-2026-06-22-am-12-26-36.png` |
| `截屏2026-06-22 上午12.26.45.png` | `docs/08_design/screenshots/screenshot-2026-06-22-am-12-26-45.png` |
| `截屏2026-06-22 上午12.26.57.png` | `docs/08_design/screenshots/screenshot-2026-06-22-am-12-26-57.png` |
| `截屏2026-06-22 上午12.27.13.png` | `docs/08_design/screenshots/screenshot-2026-06-22-am-12-27-13.png` |
| `截屏2026-06-22 上午12.27.26.png` | `docs/08_design/screenshots/screenshot-2026-06-22-am-12-27-26.png` |
| `截屏2026-06-22 上午12.27.41.png` | `docs/08_design/screenshots/screenshot-2026-06-22-am-12-27-41.png` |
| `截屏2026-06-22 上午12.27.50.png` | `docs/08_design/screenshots/screenshot-2026-06-22-am-12-27-50.png` |
| `截屏2026-06-22 上午12.27.57.png` | `docs/08_design/screenshots/screenshot-2026-06-22-am-12-27-57.png` |
| `截屏2026-06-22 下午9.54.20.png` | `docs/08_design/screenshots/screenshot-2026-06-22-pm-09-54-20.png` |
| `截屏2026-06-22 下午9.55.02.png` | `docs/08_design/screenshots/screenshot-2026-06-22-pm-09-55-02.png` |
| `截屏2026-06-22 下午9.55.15.png` | `docs/08_design/screenshots/screenshot-2026-06-22-pm-09-55-15.png` |
| `截屏2026-06-22 下午10.06.23.png` | `docs/08_design/screenshots/screenshot-2026-06-22-pm-10-06-23.png` |
| `截屏2026-06-22 下午10.06.34.png` | `docs/08_design/screenshots/screenshot-2026-06-22-pm-10-06-34.png` |
| `截屏2026-06-23 上午11.44.01.png` | `docs/08_design/screenshots/screenshot-2026-06-23-am-11-44-01.png` |
| `截屏2026-06-23 下午3.17.46.png` | `docs/08_design/screenshots/screenshot-2026-06-23-pm-03-17-46.png` |
| `截屏2026-06-23 下午6.56.11.png` | `docs/08_design/screenshots/screenshot-2026-06-23-pm-06-56-11.png` |
| `截屏2026-06-23 下午6.56.24.png` | `docs/08_design/screenshots/screenshot-2026-06-23-pm-06-56-24.png` |
| `截屏2026-06-24 上午12.16.03.png` | `docs/08_design/screenshots/screenshot-2026-06-24-am-12-16-03.png` |

New navigation files:

- `docs/10_project_structure/README.md`: project path map and owner boundaries.
- `docs/10_project_structure/REORGANIZATION_LOG.md`: this move record.
- `docs/06_tasks/README.md`: task folder guide and task family map.
- `docs/06_tasks/sql_reviews/README.md`: reviewed SQL attachment guide.
- `docs/08_design/screenshots/README.md`: screenshot filename guide.
- `docs/09_frozen/README.md`: frozen archive guide.
- `docs/09_frozen/agent_team_archive_2026-06-24/README.md`: disabled role-card archive guide.
- `docs/09_frozen/workflow_archive_2026-06-24/README.md`: archived workflow guide.
- `docs/09_frozen/workspace_initialization_2026-06-24/README.md`: initialization prompt archive guide.

Paths intentionally not moved:

- `ios/`: Xcode references and build scripts depend on this layout.
- `supabase/migrations/`: migration filenames and ordering are part of the backend audit trail.
- Former root product brief: active docs cited it as the canonical original brief at the time. It was later archived under `docs/09_frozen/product_briefs/` and removed from the repository root.
- `CLAUDE.md` and `CLAUDE_reference/`: existing owner notes explicitly keep this reference area at the root.
- `.codex/config.toml`: active Codex project configuration.
- `scripts/`: stable command entrypoints used by workflow docs and task closeouts.
- `supabase_api_key`: ignored local secret; not moved. Later Supabase workflow docs allow inspecting ignored credential files only with explicit user authorization for the current operation.

Validation:

- `git diff --check` passed.
- `git diff --cached --check` passed while git-tracked moves were staged by `git mv`.
- `./scripts/ios-build.sh` passed with `platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro`.
- Simulator boot/install/launch passed on iPhone 17 Pro (`45D452E8-DC6C-4CD4-A747-4D21671E68A6`); `xcrun simctl launch com.prinnyyy.PetGroomerMarketplace` returned pid `55542`.
- Supabase validation was skipped because no backend migrations, policies, RPCs, or schema files changed.
