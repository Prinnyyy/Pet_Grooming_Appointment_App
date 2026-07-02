# Workflow Completion Gate

Superseded by `docs/06_tasks/WORKFLOW-LIGHTWEIGHT-GATES-001.md`.
Current workflow uses adaptive gates by task mode and risk instead of requiring task closeout, validation, and simulator launch for every task.

Task ID: `WORKFLOW-COMPLETION-GATE-001`

Mode: `Quick`

Date: `2026-06-22`

## User Request

Standardize the completion process so every finished task records its completion process in the corresponding task markdown file, runs basic validation, and launches the app in the iOS Simulator for user inspection.

## Primary Task

Update the repository workflow documents and task templates to require a consistent completion gate.

## Scope

In scope:

- Document the required completion gate in `AGENTS.md`.
- Document the same workflow in `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Add stop conditions for failed validation or simulator launch.
- Update task templates so future task files include validation and simulator launch closeout fields.
- Record this workflow change in durable memory.

Out of scope:

- Changing app behavior.
- Changing validation scripts.
- Changing Supabase, backend, repositories, models, or Xcode project settings.

## Original Completion Gate Rule

This rule is historical and has been superseded. The original rule required every task to finish with this sequence before final reporting:

1. Record the completion process in the corresponding task markdown file.
2. Run the task's basic validation.
3. Launch the app in the iOS Simulator for user inspection.
4. Record validation and simulator launch status in the task closeout and durable memory when project state changed.

Current policy lives in `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md` and `docs/06_tasks/WORKFLOW-LIGHTWEIGHT-GATES-001.md`. Validation or simulator launch failures stop the task only when that validation or launch is required by the adaptive gate.

## Validation

Required for this workflow-only task:

```sh
git diff --check
```

Simulator launch:

- Launch the current app on the configured iOS Simulator after validation so the user can inspect the current result.

## Closeout

Status: `completed`

Changed files:

- `AGENTS.md`
- `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
- `docs/05_workflow/STOP_CONDITIONS.md`
- `docs/06_tasks/TASK_INTAKE_TEMPLATE.md`
- `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`
- `docs/06_tasks/WORKFLOW-COMPLETION-GATE-001.md`
- `docs/06_tasks/T-036_GROOMLY_SIGNED_OUT_LANDING_SCREENSHOT_UI.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- `git diff --check` passed.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Runtime UI snapshot confirmed `auth.landing` was visible.
- Simulator screenshot path: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_4f0a6d27-bce6-46a6-9669-a68db74e030c.jpg`.

Risks:

- Workflow-only change; no app logic, Supabase, backend, repository, model, script, dependency, or Xcode project settings changed.
- The simulator launch step now becomes a required closeout action unless the user explicitly waives it for a non-app task.

Next:

- Superseded by adaptive Micro/Quick/Standard/Deep completion gates.
