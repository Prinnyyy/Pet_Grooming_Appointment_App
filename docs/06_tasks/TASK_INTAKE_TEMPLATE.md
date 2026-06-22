# Task Intake

Task ID: `<TASK_ID>`

Date: `<YYYY-MM-DD>`

---

## User Request

Paste or summarize the user request.

---

## Primary Task

Define exactly one primary task.

For screenshot-driven Groomly UI rework, use `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` instead of this generic intake template.

---

## Out of Scope

- ...
- ...

---

## Expected Output

- ...

---

## Required Validation

- Match validation to the selected mode and risk.
- Docs/workflow-only edits usually require only `git diff --check`.
- For Swift, Xcode project, app behavior, or UI changes, also run `./scripts/ios-build.sh` unless this task defines a stricter command.
- Launch the app in the iOS Simulator only for app/UI behavior changes, screenshot tasks, or explicit user inspection requests.

---

## Risk Level

`low / medium / high`

## Completion Gate

`micro / tracked / app-visible / deep`

- `micro`: no task closeout, memory update, build, or simulator launch by default.
- `tracked`: close out this task file and run docs/workflow validation.
- `app-visible`: close out this task file, run app validation, and launch the simulator.
- `deep`: use an explicit validation plan and stop on the first required failure.

---

## Stop Condition

Define where Codex must stop.

---

## Closeout

Status: `pending / completed / blocked`

Changed files:

- pending

Validation:

- pending

Simulator launch:

- pending / skipped because non-app task

Risks:

- pending

Next:

- pending
