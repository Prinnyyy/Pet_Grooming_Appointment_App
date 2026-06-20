# Plan Review Template

Use this template before implementation when the user wants to review the plan.

---

## Plan Summary

...

Execution mode: `Quick / Standard / Deep`

---

## Task Boundary

Primary task:

...

Out of scope:

...

---

## Agent Assignments

List only agents that are necessary. Quick Mode normally lists `none`. Do not include `task_planner` when the user supplied a clear plan.

| Agent | Why Required | Expected Output (max 30 lines) |
|---|---|---|
| ... | ... | ... |

---

## Files Expected to Change

- ...

---

## Validation Budget

- Build attempts: `0 / 1 / explicit Deep plan`
- Unit tests: `not needed / command`
- UI tests: `not needed / directly changed behavior + command`
- Stop on first failure: `yes` unless user approved otherwise

---

## Risk Assessment

`low / medium / high`

---

## User Decision Needed

Proceed / revise / split task
