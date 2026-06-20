# AGENTS.md

## Mission

This is an iOS app project. Codex makes small, reversible changes and completes one primary task per run.

## Default Workflow

Use the lightweight single-agent workflow in `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.

- One primary task; no adjacent features or broad refactors.
- Minimal context: targeted reads/searches only.
- No subagents or multi-agent orchestration unless the user explicitly re-enables them.
- Short plan before non-trivial edits.
- One validation attempt by mode.
- Update durable memory only when project state changed.
- Write a closeout/checkpoint before `/compact`.
- Stop when the requested task is complete.

## Minimal Startup Context

Read only what the task needs:

1. `AGENTS.md`
2. the active task file, if provided
3. targeted sections of `docs/00_memory/CURRENT_STATE.md` when current state or risks matter
4. `docs/06_tasks/TASK_LEDGER.md` only when choosing or updating task status

Read product briefs, `PROJECT_MEMORY.md`, architecture/backend docs, historical decisions, archived workflow docs, or old reports only when directly relevant. Do not search `docs/05_workflow/archive_subagent_workflow/` or `docs/05_workflow/agent_reports/` unless the user asks for historical workflow context.

## Working Rules

- Preserve existing user work and inspect `git status` before editing.
- Do not start adjacent features or broad refactors.
- Prefer targeted searches and narrow file reads.
- Keep SwiftUI views thin and business logic outside views.
- Keep backend access behind repository/service boundaries.
- Do not invent Supabase schema facts or perform destructive database operations.
- Do not add dependencies, commit, push, or make remote writes without explicit user approval.

## Validation

- Quick Mode: validate only when directly needed.
- Standard Mode: make one build attempt by default.
- Deep Mode: state an explicit validation plan before implementation.
- UI tests are not default. Unit tests are not default for initialization tasks.
- If validation fails, report the first real error and stop unless the user approves a follow-up.

## Completion

- Briefly review the current diff.
- Update durable memory only when project state meaningfully changed.
- Before `/compact`, write a concise closeout or checkpoint with status, changed files, validation, risks, and next context.
- Report the result concisely and stop.

## Recovery

If interrupted or context is stale, follow `docs/05_workflow/INTERRUPTION_RECOVERY.md`. Do not reconstruct archived subagent state.
