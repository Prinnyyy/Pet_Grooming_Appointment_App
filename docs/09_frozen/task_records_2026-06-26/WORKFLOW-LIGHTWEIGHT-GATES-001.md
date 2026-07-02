# Lightweight Workflow Gates

Task ID: `WORKFLOW-LIGHTWEIGHT-GATES-001`

Mode: `Quick`

Date: `2026-06-22`

## User Request

Make the current Codex project workflow less rigid, more flexible, and more lightweight.

## Primary Task

Replace the mandatory all-task completion gate with adaptive workflow gates based on task mode and risk.

## Scope

In scope:

- Update `AGENTS.md` and `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md` to define adaptive completion gates.
- Update stop conditions so validation and simulator launch failures block only when those steps are required.
- Update task templates so future tasks can explicitly skip simulator launch for non-app work.
- Record the workflow policy change in durable memory.

Out of scope:

- iOS app behavior changes.
- Build script changes.
- Supabase, backend, repository, model, dependency, or Xcode project changes.
- Commits, pushes, or remote writes.

## Policy

Future tasks use proportional gates:

- `Micro`: read-only answers, status checks, tiny docs wording; no task file, memory update, build, or simulator launch by default.
- `Quick`: docs, workflow, small scripts, small fixes; run `git diff --check` when files changed and skip simulator unless app-facing.
- `Standard`: normal Swift/app/UI work; run `git diff --check`, one `./scripts/ios-build.sh`, and launch the simulator for visible app/UI changes.
- `Deep`: Supabase, auth, RLS, migrations, storage, major navigation, or high-risk work; state a validation plan before implementation.

## Validation

Required for this workflow-only task:

```sh
git diff --check
```

Simulator launch:

- Skipped because this task changes workflow documentation only and does not affect app/UI behavior.

## Closeout

Status: `completed`

Changed files:

- `AGENTS.md`
- `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
- `docs/05_workflow/STOP_CONDITIONS.md`
- `docs/06_tasks/TASK_INTAKE_TEMPLATE.md`
- `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`
- `docs/06_tasks/WORKFLOW-COMPLETION-GATE-001.md`
- `docs/06_tasks/WORKFLOW-LIGHTWEIGHT-GATES-001.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- `git diff --check` passed.

Simulator launch:

- skipped because workflow-only task

Risks:

- Workflow-only change; no iOS app behavior, build script, Supabase, backend, repository, model, dependency, or Xcode project settings changed.
- Existing uncommitted app/UI and product-doc changes were present before this task and were preserved.

Next:

- Use Micro/Quick/Standard/Deep gates for future work. Launch the simulator only for visible app/UI changes, screenshot UI work, or explicit user inspection requests.
