# Single-Agent Workflow

## Purpose

Default Codex workflow for this repository. It favors limited context, small reversible changes, and one verifiable task per run.
The workflow is intentionally adaptive: small tasks stay small, while app, backend, and screenshot work keep stronger guardrails.

## Core Rules

- One primary task only.
- No adjacent features, broad refactors, commits, pushes, or remote writes unless explicitly requested.
- No subagents or archived agent-team protocol.
- Targeted context reads/searches only.
- One validation attempt by mode.
- Adaptive completion gate: task closeout, validation, and simulator launch are required only when the task mode and risk call for them.
- Stop after the requested task is complete.

## Context Budget

Startup reads:

1. `AGENTS.md`
2. active task file, if provided
3. targeted `CURRENT_STATE.md` sections when current state or risks matter
4. `TASK_LEDGER.md` only when choosing or updating task status

Avoid broad searches. Do not read or search `docs/09_frozen/workflow_archive_2026-06-24/archive_subagent_workflow/` or `docs/09_frozen/workflow_archive_2026-06-24/agent_reports/` unless the task is explicitly about historical workflow state.

## Flow

1. Identify one primary task.
2. Classify it as Micro, Quick, Standard, or Deep.
3. Read only the context needed for that task.
4. Write a short plan before non-trivial edits.
5. Implement only that scope.
6. Run the mode-appropriate validation once, if validation is required.
7. Review the current diff briefly when files changed.
8. Record task closeout only when the gate below requires it.
9. Launch the app in the iOS Simulator only when the gate below requires it.
10. Update durable memory only if project state changed.
11. Write a closeout/checkpoint before manual compaction.
12. Stop.

## Completion Gate

Completion is proportional, not one-size-fits-all.

Always do these before the final response:

- Preserve existing user work.
- Keep the response scoped to the requested task.
- If files changed, briefly review the diff and report validation that ran or why it was skipped.

Task closeout is required when any of these apply:

- The user provided or requested a task file.
- The task is Standard or Deep.
- The task changes Swift, app behavior, visible UI, backend contracts, Supabase, auth, navigation, or persistence.
- The task changes durable workflow/product state that future runs must remember.

Task closeout is optional, and usually skipped, for Micro tasks and small docs-only Quick tasks.

Validation rules:

1. **No file edits:** no validation required unless the user requested a command/check.
2. **Docs/workflow-only edits:** run `git diff --check` by default.
3. **Swift, Xcode project, simulator, app behavior, or UI edits:** run `git diff --check` and one `./scripts/ios-build.sh` attempt unless the active task defines a stricter command.
4. **Deep tasks:** state the validation plan before implementation and run one planned attempt unless the user approves more.

Simulator launch is required only for:

- User-facing app/UI behavior changes.
- Screenshot-driven UI rework tasks.
- Tasks where the user explicitly asks to inspect the app.

Simulator launch is skipped by default for docs-only, workflow-only, read-only, command-output, and backend-only tasks. If launch is required, prefer XcodeBuildMCP simulator tools when available; otherwise use local Xcode/simulator tooling. Record the simulator/device used and whether the app reached a visible root screen.

Durable memory updates are limited to meaningful project state changes. Do not update `CURRENT_STATE.md`, `WORKLOG.md`, `TASK_LEDGER.md`, `FEATURE_INDEX.md`, or `DECISION_LOG.md` for tiny docs-only edits unless future runs need that fact.

## Screenshot-Driven Groomly UI Rework

For future Groomly UI rework, one uploaded screenshot is one primary task unless the user explicitly says otherwise.

Required flow:

1. Create or use a task file from `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`.
2. Analyze the screenshot before editing SwiftUI.
3. Ignore any long oval Customer/Groomer toggle located above the visible app screen frame; treat it as an external prototype/control annotation, not an app module.
4. Map every visible in-app module to an existing SwiftUI surface, Store, repository/model path, or mark it as a new feature.
5. Classify each module as visual-only, existing-feature rewire, reusable UI primitive, or new feature.
6. Implement only visual-only, existing-feature rewire, or small pure DesignSystem primitive work that is inside the approved screenshot task.
7. Stop before implementing new features unless the user explicitly approves a separate feature scope.

Existing MVP behavior must use existing Store, repository, model, and backend contracts. Do not add duplicate backend paths, direct Supabase access from SwiftUI, or schema/RLS/RPC/Storage changes during a screenshot UI task.

## Modes

| Mode | Use For | Validation |
|---|---|---|
| Micro | Read-only answers, status checks, small command output, tiny docs wording | None by default; `git diff --check` if files changed and useful |
| Quick | Docs, workflow changes, small scripts, one-file fixes, simple UI text/style | `git diff --check` when files changed; no simulator unless app-facing |
| Standard | Normal iOS feature, bug, or visible UI work | `git diff --check` plus one `./scripts/ios-build.sh`; simulator launch for user-facing app/UI changes |
| Deep | Supabase, auth, RLS, migrations, storage, major navigation, high-risk work | Explicit validation plan; one planned attempt unless approved otherwise |

If a required validation or required launch fails, report the first real error and stop unless the user approves a follow-up task. A skipped simulator launch for non-app work is not a failure.

## Durable Memory

Update only files whose facts changed:

- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/07_decisions/DECISION_LOG.md`

Do not update memory for tiny documentation-only changes unless needed.

## Compaction

Manual compaction belongs at task boundaries. Capture a closeout or debug checkpoint first, then compact when context is high or the next task is unrelated. Detailed thresholds live in `docs/05_workflow/CONTEXT_MANAGEMENT.md`.

## Reporting

Keep final reports concise. Use `LIGHTWEIGHT_FINAL_REPORT_TEMPLATE.md` only when a durable report is useful or explicitly requested.
