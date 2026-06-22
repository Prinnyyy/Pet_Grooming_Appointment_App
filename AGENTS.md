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

The Groomly foundation sequence `docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md` is completed.

The completed screen slices are:

- `docs/06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md`
- `docs/06_tasks/T-025_GROOMLY_CUSTOMER_PETS_UI.md`
- `docs/06_tasks/T-026_GROOMLY_CUSTOMER_REQUESTS_LIST_STATUS_UI.md`
- `docs/06_tasks/T-027_GROOMLY_CUSTOMER_REQUEST_WIZARD_UI.md`
- `docs/06_tasks/T-028_GROOMLY_CUSTOMER_REQUEST_DETAIL_OFFERS_UI.md`
- `docs/06_tasks/T-029_GROOMLY_GROOMER_REQUESTS_FEED_DETAIL_UI.md`
- `docs/06_tasks/T-030_GROOMLY_GROOMER_OFFER_FORM_STATUS_UI.md`
- `docs/06_tasks/T-031_GROOMLY_GROOMER_PROFILE_SERVICES_UI.md`
- `docs/06_tasks/T-032_GROOMLY_GROOMER_PORTFOLIO_UI.md`

The planned remaining Groomly UI sequence is `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`.

The active next executable task is `docs/06_tasks/T-033_GROOMLY_BOOKINGS_UI.md`.

- T-022 remains completed, but its post-MVP next-task suggestions are frozen and must not auto-start.
- Use the Groomly design source in `docs/08_design/` only as a visual and interaction reference.
- T-023A through T-023D2 and T-024 through T-032 are completed. Do not rerun or extend them unless the user explicitly requests a review follow-up.
- T-026 through T-032 are completed. T-033 through T-035 are planned. Execute them in order unless the user explicitly replans the sequence.
- Run only one screen-specific Groomly task per Codex run.
- Do not redesign additional feature screens, skip ahead to later Groomly tasks, or start non-Groomly post-MVP work unless the user explicitly requests it.
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
