# Interruption Recovery

## Purpose

This protocol reduces damage from Codex usage limits, interrupted runs, context compression, or accidental session closure.

---

## Before Starting Implementation

Quick and Standard tasks may rely on the user request plus a concise intake. Deep Mode should have:

```text
docs/05_workflow/agent_reports/<TASK_ID>/00-task-intake.md
docs/05_workflow/agent_reports/<TASK_ID>/05-approved-patch-plan.md
```

Do not create a full report chain merely for recovery.

---

## During Implementation

Keep changes small and follow the selected mode's budget.

---

## After Interruption

On restart:

1. Read `AGENTS.md`, `CURRENT_STATE.md`, `TASK_LEDGER.md`, and the active intake.
2. Run `git status` and inspect the current task diff.
3. Read only the latest final/handoff or specialist report needed to identify the next safe action.
4. Resume with the smallest safe step; do not automatically repeat prior validation.

---

## Partial Change Handling

If partial implementation exists:

- do not continue blindly,
- compare diff against approved patch plan,
- revert only with explicit user approval,
- use only the remaining validation budget; do not enter a fix loop without approval.

---

## Stop Early Rule

If running out of time, token budget, or task clarity:

1. stop adding new changes,
2. write current status to the active report folder,
3. update `CURRENT_STATE.md` if appropriate,
4. report remaining work clearly.
