# Reorganization Log

This log records repository structure changes so future agents do not lose track of moved paths.

## 2026-06-26 - Markdown Information Architecture Optimization

Scope:

- Reduce active workflow Markdown entrypoints without changing app behavior, Supabase schema, migrations, scripts, or root source ownership.
- Consolidate duplicated context/recovery rules into one active access-tier document.
- Consolidate duplicated tool/MCP/Superpowers/validation rules into one active tooling policy.
- Keep root `CLAUDE.md`, `CLAUDE_reference/`, and `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` in place, but mark them as on-demand reference rather than default startup context.

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
- `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`: active docs cite this root path as the canonical original brief.
- `CLAUDE.md` and `CLAUDE_reference/`: existing owner notes explicitly keep this reference area at the root.
- `.codex/config.toml`: active Codex project configuration.
- `scripts/`: stable command entrypoints used by workflow docs and task closeouts.
- `supabase_api_key`: ignored local secret; not read or moved.

Validation:

- `git diff --check` passed.
- `git diff --cached --check` passed while git-tracked moves were staged by `git mv`.
- `./scripts/ios-build.sh` passed with `platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro`.
- Simulator boot/install/launch passed on iPhone 17 Pro (`45D452E8-DC6C-4CD4-A747-4D21671E68A6`); `xcrun simctl launch com.prinnyyy.PetGroomerMarketplace` returned pid `55542`.
- Supabase validation was skipped because no backend migrations, policies, RPCs, or schema files changed.
