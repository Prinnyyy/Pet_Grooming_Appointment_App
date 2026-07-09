# Reorganization Log

This is the active index for repository structure changes. It keeps recent moves and pointers only; full historical text is frozen.

Full pre-T-169 log snapshot: `../09_frozen/project_structure/REORGANIZATION_LOG_2026-06-24_TO_2026-07-07_PRE_T169.md`.

## 2026-07-08 - T-169 Active Document Structure Reduction

Scope:

- Shrink the active structure log into a pointer/index instead of a full historical narrative.
- Move old Claude-only reference material out of the active root while preserving `CLAUDE.md` as the current Claude entrypoint.
- Move low-use generic handoff/review templates out of the active task directory.
- Roll active ledger/worklog windows after adding T-169.

Moved or copied paths:

| Active source | Frozen path | Reason |
|---|---|---|
| `docs/10_project_structure/REORGANIZATION_LOG.md` pre-T-169 full text | `../09_frozen/project_structure/REORGANIZATION_LOG_2026-06-24_TO_2026-07-07_PRE_T169.md` | Preserve old detailed move history while keeping the active log short. |
| `CLAUDE_reference/CLAUDE_INDEX.md` | `../09_frozen/claude_reference_2026-07-08/CLAUDE_INDEX.md` | Old Claude reference index pointed to historical T-002 planning material already superseded by active roadmap/task docs. |
| `CLAUDE_reference/CLAUDE_INCREMENTAL_BUILD_PLAN.md` | `../09_frozen/claude_reference_2026-07-08/CLAUDE_INCREMENTAL_BUILD_PLAN.md` | Preserve the old T-002 roadmap snapshot without exposing it to default root searches. |
| Removed docs/06_tasks/HANDOFF_TEMPLATE.md | `../09_frozen/task_templates/HANDOFF_TEMPLATE_2026-07-08.md` | Generic handoff template is superseded by the compact checkpoint rule in active workflow docs. |
| Removed docs/06_tasks/REVIEW_TEMPLATE.md | `../09_frozen/task_templates/REVIEW_TEMPLATE_2026-07-08.md` | Generic review checklist is superseded by task validation, closeout, and hygiene gates. |
| `docs/06_tasks/TASK_LEDGER.md` row T-154 | `../09_frozen/task_ledgers/TASK_LEDGER_T-154_2026-07-07.md` | Keep the active ledger under the 15-row window after adding T-169. |
| `docs/00_memory/WORKLOG.md` entry T-159 | `../09_frozen/worklogs/WORKLOG_2026-07-07_T-159.md` | Keep the active worklog under the 10-entry window after adding T-169. |

Validation for the task is recorded in `../06_tasks/TASK_LEDGER.md` and `../00_memory/WORKLOG.md`.

## Recent Structure Changes

| Date | Task | Summary | Detail |
|---|---|---|---|
| 2026-07-08 | T-179 | Archived the adopted watch-items plan, lowered active memory windows, and compressed active indexes below the 85% waterline. | `../09_frozen/external_agent_reports/`, `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/`, `README.md` |
| 2026-07-08 | T-178 | Added backtick path integrity checks and rolled T-164 ledger row plus T-168 worklog entry to frozen. | `../../scripts/context-hygiene-check.mjs`, `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-08 | T-177 | Cleaned dead governance-plan ignore entries, expanded ROADMAP DoD, and rolled T-163 ledger row plus T-167 worklog entry to frozen. | `../../.rgignore`, `../../.gitignore`, `../06_tasks/ROADMAP.md`, `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-08 | T-176 | Removed AGENTS branch-baseline duplication, updated Claude routing, and rolled T-162 ledger row plus T-166 worklog entry to frozen. | `../../AGENTS.md`, `../../CLAUDE.md`, `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-08 | T-175 | Added hygiene v4 failure-mode checks and rolled T-161 ledger row plus T-165 worklog entry to frozen. | `../../scripts/context-hygiene-check.mjs`, `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-08 | T-174 | Snapshotted and trimmed the active decision log, archived the adopted governance review fix plan, and rolled T-160/T-164 ledger/worklog entries to frozen. | `../09_frozen/decisions/`, `../09_frozen/external_agent_reports/`, `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-08 | T-173 | Recorded `main` commit `2fddf7b` as superseded and rolled T-159 ledger row plus T-163 worklog entry to frozen. | `../05_workflow/GITHUB_RULES.md`, `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-08 | T-172 | Added standalone rule-change process and rolled T-158 ledger row plus T-162 worklog entry to frozen. | `../05_workflow/SINGLE_AGENT_WORKFLOW.md`, `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-08 | T-171 | Added periodic meta-review template and rolled T-156 ledger row plus T-161 worklog entry to frozen. | `../06_tasks/META_REVIEW_TEMPLATE.md`, `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-08 | T-170 | Rolled T-155 ledger row and T-160 worklog entry to frozen while adding hygiene v3 fact checks. | `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-07 | T-168 | Rolled T-153 ledger row and T-157 worklog note to frozen while adding backend preflight rules. | `../09_frozen/task_ledgers/`, `../09_frozen/worklogs/` |
| 2026-07-07 | T-167 | Added managed roadmap and archived older worklog entry T-158. | `../06_tasks/ROADMAP.md`, `../09_frozen/worklogs/` |
| 2026-07-07 | T-166 | Hardened Git/GitHub rules and archived T-151 through T-152 ledger rows. | `../05_workflow/GITHUB_RULES.md`, `../09_frozen/task_ledgers/` |
| 2026-07-07 | T-165 | Added context hygiene v2 truth checks and rolled old worklog entries out of active memory. | `../../scripts/context-hygiene-check.mjs`, `../09_frozen/worklogs/` |
| 2026-07-07 | T-163 | Archived external governance draft, current-state snapshot, and T-146 through T-150 ledger rows. | `../09_frozen/external_agent_reports/`, `../09_frozen/current_state_snapshots/`, `../09_frozen/task_ledgers/` |
| 2026-07-02 | T-147/T-148-era cleanup | Archived old root product brief, Groomly prompt, duplicate pointers, and generic lightweight templates. | `../09_frozen/product_briefs/`, `../09_frozen/design_prompts/`, `../09_frozen/task_templates/` |
| 2026-06-24 to 2026-06-26 | Structure baseline | Moved old workflow docs, detailed task records, agent-team material, Superpowers plans/specs, and initialization prompt into frozen archive families. | `../09_frozen/` |

## Current Indexes

- Current folder map: `README.md`.
- Frozen archive guide: `../09_frozen/README.md`.
- Task folder guide: `../06_tasks/README.md`.
- Active workflow and context rules: `../05_workflow/`.

## Rule

When moving, deleting, or archiving Markdown, update the active index that pointed to it in the same task. Do not add full historical narratives back to this file; add a frozen snapshot and a short pointer instead.
