# AGENTS.md

## Project Mission

This repository is an iOS app project. Codex works through small, reversible changes and completes at most one primary task per run.

## Default Codex Workflow

This project uses a lightweight single-agent Codex workflow.

Default rules:
- one primary task per run,
- minimal context reading,
- no subagents by default,
- short plan before non-trivial changes,
- one validation attempt by default,
- durable memory updates only when meaningful,
- stop after the requested task is complete.

Detailed workflow:
- `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`

Do not spawn `context_librarian`, `task_planner`, `ios_code_mapper`, `supabase_contract_auditor`, `implementation_worker`, `build_validator`, or `final_reviewer`. Multi-agent orchestration remains disabled unless the user explicitly re-enables it in a future request.

## Minimal Startup Context

Read only:

1. `AGENTS.md`
2. `docs/00_memory/CURRENT_STATE.md`
3. `docs/06_tasks/TASK_LEDGER.md` if present
4. the active task file, if provided

Read product briefs, `PROJECT_MEMORY.md`, architecture/backend docs, historical decisions, or old reports only when directly relevant.

## Working Rules

- Preserve existing user work and inspect `git status` before editing.
- Do not start adjacent features or broad refactors.
- Prefer targeted searches and narrow file reads.
- Keep SwiftUI views thin and business logic outside views.
- Keep backend access behind repository/service boundaries.
- Do not invent Supabase schema facts or perform destructive database operations.
- Do not add dependencies, commit, push, or make remote writes without explicit user approval.

## Validation and Completion

- Quick Mode: validate only when directly needed.
- Standard Mode: make one build attempt by default.
- Deep Mode: state an explicit validation plan before implementation.
- UI tests are not default. Unit tests are not default for initialization tasks.
- If validation fails, report the first real error and stop; do not enter a fix loop without approval.
- Briefly review the current diff.
- Update durable memory only when project state meaningfully changed.
- Report the result concisely and stop.

## Recovery

If interrupted or context is stale, follow `docs/05_workflow/INTERRUPTION_RECOVERY.md`. Do not reconstruct archived subagent state.
