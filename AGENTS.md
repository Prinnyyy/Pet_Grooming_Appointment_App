# AGENTS.md

## Mission

This is an iOS SwiftUI app project. Codex makes small, reversible changes and completes one primary task per run.

## Active Workflow

Use these files as the active workflow sources:

- `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`: task flow and completion gate.
- `docs/05_workflow/CONTEXT_AND_RECOVERY.md`: context tiers, recovery, compaction, and hygiene budgets.
- `docs/05_workflow/TOOLING_POLICY.md`: tools, validation, Supabase, Git, and remote-write rules.
- `docs/05_workflow/STOP_CONDITIONS.md`: when to stop and report.

Do not use archived agent-team or subagent workflows unless the user explicitly re-enables them.

## Minimal Startup

Read only what the task needs:

1. `AGENTS.md`.
2. Targeted top sections of `docs/00_memory/CURRENT_STATE.md` only when current branch, risks, or validation state matter.
3. Targeted top rows of `docs/06_tasks/TASK_LEDGER.md` only when choosing or updating task status.
4. An active task file only when the user explicitly provides or requests one.

Default searches must honor `.rgignore`. Do not use broad `rg --files -g '*.md'` as a default Markdown inventory because it can re-include ignored seed tables. Use `rg --no-ignore` only for explicitly needed frozen archives, machine-readable seed profiles, generated artifacts, or full design exports.

## Task Rules

- Preserve user work; run `git status --short` before edits.
- Current branch baseline is `codex/pet-fit-structure-cleanup`; do not continue work from another branch unless the user names it.
- Use the next available task ID from `docs/06_tasks/TASK_LEDGER.md` for new bugfix or iteration work.
- One primary task only. Do not start adjacent features, broad refactors, or unrelated cleanup.
- Make a short plan before non-trivial edits.
- Keep SwiftUI views thin and route business logic through Store/ViewModel/repository boundaries.
- Keep backend access behind repository/service boundaries.
- Do not invent Supabase schema facts or perform destructive database operations.
- Do not add dependencies, commit, push, create PRs, make remote writes, run seeds, or run cleanup without explicit user approval.

## Groomly UI Work

Implemented Groomly MVP UI work is historical. Detailed T-001 through T-088 records are archived under `docs/09_frozen/task_records_2026-06-26/`.

Future Groomly UI work is screenshot-driven. One uploaded screenshot is one bounded UI rework task unless the user explicitly combines or splits scope. Before SwiftUI edits, map visible modules to existing screens, Stores, repositories, models, or stop for new-feature approval.

Treat the Groomly design source under `docs/08_design/` as visual/interaction reference only. Do not copy HTML/CSS/React into SwiftUI. Ignore any long oval Customer/Groomer toggle above the visible app screen frame as an external prototype control.

If a screenshot implies new persistence, schema, RLS, RPC, Storage, navigation, role capability, or deferred feature, stop and report the decision needed.

## Validation

- Micro: read-only/status/tiny docs; no validation by default.
- Quick: docs/workflow/small scripts; usually `git diff --check`.
- Standard: Swift, Xcode, app behavior, or visible UI; `git diff --check` plus one `./scripts/ios-build.sh`.
- Deep: Supabase, auth, RLS, migrations, storage, major navigation, or high risk; state a validation plan first.

Launch the iOS Simulator only for app/UI behavior changes, screenshot tasks, or explicit inspection requests. Skip simulator launch for docs-only, workflow-only, read-only, and backend-only tasks unless visual inspection is useful.

If a required validation fails, report the first real error and stop unless the user approves a follow-up.

## Completion

Briefly review the diff when files changed. Record closeout in `docs/06_tasks/TASK_LEDGER.md` and `docs/00_memory/WORKLOG.md` when the task changes durable workflow/product state or app behavior. Update `docs/00_memory/CURRENT_STATE.md` only when a future run needs the changed fact.

After durable memory or task-ledger changes, run context hygiene. Archive old active memory/task rows immediately if thresholds are exceeded.

Before `/compact`, write a concise checkpoint with task ID/status, files changed, validation, risks, and next context. Stop when the requested task is complete.

## Recovery

If interrupted or context is stale, follow `docs/05_workflow/CONTEXT_AND_RECOVERY.md`. Do not reconstruct archived subagent state.
