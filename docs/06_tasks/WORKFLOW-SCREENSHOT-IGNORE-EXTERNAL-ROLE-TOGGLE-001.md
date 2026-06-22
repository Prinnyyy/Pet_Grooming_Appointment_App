# Workflow Screenshot External Role Toggle Ignore Rule

Task ID: `WORKFLOW-SCREENSHOT-IGNORE-EXTERNAL-ROLE-TOGGLE-001`

Mode: `Quick`

Date: `2026-06-22`

## User Request

Add a rule for screenshot recognition: ignore the long oval Customer/Groomer toggle button located above the app screen frame at the top of an image.

## Primary Task

Update screenshot-driven UI workflow rules so future screenshot analysis ignores the external top role toggle when it is outside the app screen frame.

## Scope

In scope:

- Add the ignore rule to `AGENTS.md`.
- Add the ignore rule to `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Add the ignore rule to `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`.
- Record the workflow change in durable memory.

Out of scope:

- Changing current app UI.
- Reworking T-036 implementation.
- Changing Auth, role onboarding, backend, repositories, models, or product behavior.

## Rule

When analyzing uploaded screenshots, ignore any long oval Customer/Groomer toggle located above the visible app screen frame. Treat it as an external prototype/control annotation, not as an app module to map, classify, or implement.

## Validation

Required:

```sh
git diff --check
```

Simulator launch:

- Launch or confirm the app is visible in the iOS Simulator after validation, per the completion gate.

## Closeout

Status: `completed`

Changed files:

- `AGENTS.md`
- `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
- `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`
- `docs/06_tasks/WORKFLOW-SCREENSHOT-IGNORE-EXTERNAL-ROLE-TOGGLE-001.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- `git diff --check` passed.

Simulator launch:

- Existing XcodeBuildMCP simulator session on `iPhone 17` (`B9639233-9E78-41C9-A372-330D36C38DA7`) confirmed `auth.landing` was visible.

Risks:

- Workflow-only rule change; no current app UI, Auth, role onboarding, backend, repository, model, or product behavior changed.

Next:

- Apply this ignore rule on future screenshot analysis before mapping visible in-app modules.
