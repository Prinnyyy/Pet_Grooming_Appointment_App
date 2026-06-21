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

## Active Groomly UI Phase

The active Groomly foundation sequence is `docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`.

The active next executable task is `docs/06_tasks/T-023A_GROOMLY_DESIGN_AUDIT_NOTES.md`.

- T-022 remains completed, but its post-MVP next-task suggestions are frozen and must not auto-start.
- Use the Groomly design source in `docs/08_design/` only as a visual and interaction reference.
- Run only one T-023 child task per Codex run: T-023A, then T-023B, then T-023C, then T-023D1, then T-023D2.
- Start with T-023A only: design audit and `UI_IMPLEMENTATION_NOTES.md`.
- For T-023A startup, use the task file's Required Context list. Do not read backend docs, old task files, frozen snapshots, full worklog history, or full current-state history unless the user explicitly asks.
- Do not redesign feature screens, implement Slice 2-8, or start non-Groomly post-MVP work unless the user explicitly requests it.
- Do not copy HTML/CSS/React code directly into SwiftUI.
- Product correctness and the existing Open Request -> Groomer Offer -> Customer Confirmation -> Booking model take priority over visual matching.
- If prototype content requires backend/schema/RLS/RPC changes or deferred features, stop and report.

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
