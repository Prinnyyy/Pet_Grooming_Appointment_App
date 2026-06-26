# Tooling Policy

Use tools only when they reduce uncertainty, implement the requested scope, or verify the result.

## General Rules

1. Prefer existing repository scripts over invented commands.
2. Prefer read-only inspection before writes.
3. Keep file edits inside the active task scope.
4. Do not read or expose secrets.
5. Do not use destructive commands unless the user explicitly requests that operation.
6. Do not make remote writes without explicit user approval.
7. Do not add validation merely because a tool is available.

## Validation

- Micro Mode: no validation by default.
- Quick Mode: docs/workflow edits usually run `git diff --check`.
- Standard Mode: Swift, Xcode, app behavior, or visible UI changes run `git diff --check` and one `./scripts/ios-build.sh` attempt.
- Deep Mode: state a validation plan before implementation and make one planned validation attempt unless the user approves more.
- UI tests are not default.
- Unit tests are not default for initialization tasks.

If a required build, test, or diff check fails, report the first real error and stop unless the user approves a follow-up.

## File Editing

Edit only files required by the active task. If scope must expand, stop and update the plan before editing.

Review `git status` before edits and preserve unrelated user work.

## iOS and Xcode

Use documented scripts when validation is required:

- `./scripts/ios-build.sh`
- `./scripts/ios-test.sh`

Do not alter signing, capabilities, entitlements, schemes, project structure, or simulator assumptions unless explicitly planned.

## Supabase

Supabase CLI is the default interface for Supabase work. Use the installed `supabase` binary against the authorized linked project. Do not use `npx supabase`, local containers, direct database tools, or MCP migration writes unless a task explicitly documents that fallback.

Migration workflow:

1. Create the migration with `supabase migration new <name>`.
2. Draft and review one task-scoped SQL change locally.
3. Obtain explicit user approval for remote DDL.
4. Apply reviewed SQL only with `supabase db push --linked`.
5. Confirm version/name with `supabase migration list --linked`.
6. Validate metadata and positive/negative authorization cases with `supabase db query --linked`.
7. Run advisors with `supabase db advisors --linked --type security` and `supabase db advisors --linked --type performance`.

`./scripts/supabase-check.sh` is a static repository check. It does not replace remote verification and must not mutate remote state.

Never reset databases, weaken RLS, repair migration history, expose service-role keys, inspect local secrets, or make remote schema/Storage writes without explicit task authorization.

## MCP and Plugin Tools

Prefer local repository files first. Use MCP or plugin tools only for task-relevant facts or planned validation.

- Quick Mode: no MCP by default.
- Standard Mode: use MCP only when local context cannot answer a task-relevant question or it performs the planned validation.
- Deep Mode: use targeted MCP for explicitly planned backend/platform investigation.

If tool output conflicts with repository files, identify the conflict and prefer repository files unless they are demonstrably stale.

## Git and GitHub

Read-only commands such as `git status`, `git diff`, and `git log` are allowed.

Commit, push, reset, rebase, PR creation, merge, branch deletion, and repository-setting changes require explicit user approval.

## Superpowers

Superpowers is optional.

- Use at most one directly relevant capability when it is clearly useful.
- Skip Superpowers when no capability directly helps the current task.
- Do not let Superpowers expand task scope.
- Do not add subagents, extra reviews, validation loops, branches, commits, pushes, or PR workflows merely because a skill exists.

Repository instructions and explicit user limits remain authoritative.
