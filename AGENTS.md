# AGENTS.md

## Mission

This is an iOS app project. Codex makes small, reversible changes and completes one primary task per run.

## Default Workflow

Use the lightweight single-agent workflow in `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
Use `docs/05_workflow/CONTEXT_AND_RECOVERY.md` for read-budget and recovery decisions, and `docs/05_workflow/TOOLING_POLICY.md` for tooling and validation boundaries.

- One primary task; no adjacent features or broad refactors.
- Minimal context: targeted reads/searches only.
- No subagents or multi-agent orchestration unless the user explicitly re-enables them.
- Short plan before non-trivial edits.
- One validation attempt by mode.
- Completion gate is adaptive: match task closeout, validation, and simulator launch to the task mode and risk.
- Update durable memory only when project state changed.
- Write a closeout/checkpoint before `/compact`.
- Stop when the requested task is complete.

## Archived Groomly UI Phase and Active Screenshot Rework

The detailed task-record files for T-001 through T-088 and workflow policy tasks are archived under `docs/09_frozen/task_records_2026-06-26/`.

The active task record is `docs/06_tasks/TASK_LEDGER.md`. Use it as the single current task-status source; do not create new per-task `T-###_*.md` files unless the user explicitly asks for a long standalone task spec or the task cannot be represented clearly in the ledger/worklog.

The Groomly UI foundation and completion sequences are completed for implemented MVP screens. Their detailed records are historical context in the task-record archive.

Future Groomly UI work is screenshot-driven. Each uploaded screenshot becomes one bounded UI rework task unless the user explicitly combines or splits scope. Use `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` as the checklist for new screenshot tasks, starting from the next available task ID in `TASK_LEDGER.md` instead of reopening archived T-024 through T-035 records.

- T-022 remains completed, but its post-MVP next-task suggestions are frozen and must not auto-start.
- Use the Groomly design source in `docs/08_design/` only as a visual and interaction reference.
- T-023A through T-023D2 and T-024 through T-035 are completed and archived as historical implementation evidence. Do not rerun or extend them unless the user explicitly requests a review follow-up.
- Run only one primary task per Codex run.
- Before SwiftUI edits for a screenshot task, analyze the screenshot, map each visible module to existing app screens/data owners, and write a short implementation plan.
- When analyzing screenshots, ignore any long oval Customer/Groomer toggle located above the visible app screen frame. Treat it as an external prototype/control annotation, not an app module to map or implement.
- If a screenshot module maps to existing MVP behavior, wire the new UI to the existing Store, repository, model, and backend contract. Do not rebuild backend code or create duplicate data paths.
- Do not redesign additional feature screens, start Admin Dashboard work, or start non-Groomly post-MVP work unless the user explicitly requests it.
- Do not copy HTML/CSS/React code directly into SwiftUI.
- Product correctness and the existing Open Request -> Groomer Offer -> Customer Confirmation -> Booking model take priority over visual matching.
- If screenshot or prototype content implies new persistence, schema, RLS, RPC, Storage behavior, navigation model, role capability, or deferred feature, stop and report the feature, whether it is already supported, likely affected files, validation needed, and the user decision required.

## Minimal Startup Context

Read only what the task needs:

1. `AGENTS.md`
2. the active task file, only if the user explicitly provided/requested one
3. targeted sections of `docs/00_memory/CURRENT_STATE.md` when current state or risks matter
4. `docs/06_tasks/TASK_LEDGER.md` only when choosing or updating task status

Use the access tiers in `docs/05_workflow/CONTEXT_AND_RECOVERY.md` when deciding whether to read product briefs, `PROJECT_MEMORY.md`, architecture/backend docs, historical decisions, archived workflow docs, old reports, root reference material, or templates. Do not search `docs/09_frozen/**` unless the user asks for historical context or the task explicitly needs recovery/comparison.

## Working Rules

- Preserve existing user work and inspect `git status` before editing.
- Current branch baseline is `codex/pet-fit-structure-cleanup`; do not continue implementation, documentation, commits, or pushes from another branch unless the user explicitly names that branch.
- Use the next available task ID from `docs/06_tasks/TASK_LEDGER.md` for new bugfix and iteration work; do not reopen archived task files to record unrelated follow-up work.
- Do not start adjacent features or broad refactors.
- Prefer targeted searches and narrow file reads.
- Keep SwiftUI views thin and business logic outside views.
- Keep backend access behind repository/service boundaries.
- Do not invent Supabase schema facts or perform destructive database operations.
- Do not add dependencies, commit, push, or make remote writes without explicit user approval.

## Validation

- Micro Mode: for read-only answers, status checks, or tiny doc edits; no task file, memory update, build, or simulator launch by default.
- Quick Mode: validate only what changed; docs-only edits usually need only `git diff --check`.
- Standard Mode: make one build attempt by default.
- Deep Mode: state an explicit validation plan before implementation.
- When files are edited, basic validation should include `git diff --check` unless the change is intentionally left as an unvalidated checkpoint.
- For Swift, Xcode project, app behavior, or UI changes, also run `./scripts/ios-build.sh` unless the active task documents a stricter check.
- Launch the iOS Simulator only for app/UI behavior changes, screenshot tasks, or explicit user requests; skip it for docs-only, workflow-only, read-only, and backend-only tasks unless visual inspection is useful.
- UI tests are not default. Unit tests are not default for initialization tasks.
- If validation fails, report the first real error and stop unless the user approves a follow-up.

## Completion

- Briefly review the current diff.
- Record closeout in `docs/06_tasks/TASK_LEDGER.md` and `docs/00_memory/WORKLOG.md` when the task changes durable workflow/product state or app behavior. Create a standalone task markdown file only when explicitly requested or when a long task spec is necessary.
- Run mode-appropriate validation and report what was run or intentionally skipped.
- Launch the app in the iOS Simulator only when the task affects visible app behavior or the user asks for inspection; if launch is required and fails, record the blocker and report it.
- Update durable memory only when project state meaningfully changed.
- Before `/compact`, write a concise closeout or checkpoint with status, changed files, validation, risks, and next context.
- Report the result concisely and stop.

## Recovery

If interrupted or context is stale, follow `docs/05_workflow/CONTEXT_AND_RECOVERY.md`. Do not reconstruct archived subagent state.
