# Tool Usage Policy

## General Rules

1. Prefer existing project scripts over invented commands.
2. Use read-only commands during planning.
3. Keep writes inside the active task scope.
4. Avoid destructive commands.
5. Do not use network access unless the task requires it and the user approves.
6. Do not read or log secrets.
7. Do not add validation merely because a tool is available.

## Validation

- Quick Mode: no validation unless directly needed.
- Standard Mode: one build attempt by default.
- Deep Mode: an explicit validation plan is required.
- UI tests are not default.
- Unit tests are not default for initialization tasks.
- If build or test fails, report the first real error and stop.
- Do not enter fix loops unless the user approves a follow-up task.

## Xcode and iOS

Prefer documented project scripts when validation is required. Do not alter signing, capabilities, schemes, or project structure unless explicitly requested. Report environment failures separately from code failures.

## Supabase

Read local docs and migrations before making assumptions. Do not reset databases, repair migrations, weaken RLS, bypass protected RPC boundaries, expose service-role keys, or make remote writes without explicit approval.

## Git and GitHub

Read-only commands such as `git status`, `git diff`, and `git log` are allowed. Commit, push, reset, rebase, PR creation, merge, and repository-setting changes require explicit user approval.

## File Editing

Edit only files required by the active task. If scope must expand, stop and update the plan before editing.
