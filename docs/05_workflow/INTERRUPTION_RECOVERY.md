# Interruption Recovery

## Purpose

This protocol reduces damage from Codex usage limits, interrupted runs, context compression, or accidental session closure.

---

## Before Starting Implementation

Every non-trivial task must have:

```text
docs/05_workflow/agent_reports/<TASK_ID>/00-task-intake.md
docs/05_workflow/agent_reports/<TASK_ID>/05-approved-patch-plan.md
```

If implementation is interrupted, these files define what the task was supposed to do.

---

## During Implementation

Implementation worker should keep changes small.

If the task has more than 5 likely files to edit, split it into smaller tasks unless the files are tightly coupled.

---

## After Interruption

On restart:

1. Read `docs/00_memory/CONTEXT_RECOVERY_PROTOCOL.md`.
2. Find the active task ID.
3. Read all report files for the active task.
4. Run `git status`.
5. Run `git diff`.
6. Determine whether changes are safe to continue.
7. Validate before making additional edits.

---

## Partial Change Handling

If partial implementation exists:

- do not continue blindly,
- compare diff against approved patch plan,
- revert only with explicit user approval,
- prefer completing the smallest safe validation step first.

---

## Stop Early Rule

If running out of time, token budget, or task clarity:

1. stop adding new changes,
2. write current status to the active report folder,
3. update `CURRENT_STATE.md` if appropriate,
4. report remaining work clearly.
