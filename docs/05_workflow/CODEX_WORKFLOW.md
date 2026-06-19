# Codex Workflow

## Standard Run

1. Read startup context.
2. Check Superpowers/plugin capabilities.
3. Confirm one active task.
4. Select specialist role.
5. Inspect only relevant files.
6. Make minimal changes.
7. Run relevant checks.
8. Update memory.
9. Report results.
10. Stop.

## Task Size Rule

A Codex task should normally fit one of these categories:

- One screen improvement
- One repository method
- One backend RPC/migration
- One bug reproduction and fix
- One documentation update
- One build/test repair

If a task touches product flow, backend contract, and multiple screens, split it.

## Interruption Safety

Every task must leave the repository in a recoverable state.

If interrupted:
- Current changes should be small.
- Active files should be clear.
- Handoff notes should be possible from diff + `WORKLOG.md`.
