# Lightweight Execution Policy

This is the default execution-budget policy for Codex runs. It overrides heavier defaults in older workflow documents when they conflict. Every run still executes at most one primary task.

## Task Modes

### Quick Mode

Use for documentation-only work, one-file edits, simple script changes, and small UI copy or style fixes.

- No subagents or `task_planner` by default.
- Use a short inline plan; intermediate agent reports are optional.
- Do not build or test unless the edited file directly requires it.
- Keep the final report brief.

### Standard Mode

Use for normal iOS implementation tasks.

- Use `context_librarian` only when context is unclear.
- Use `ios_code_mapper` only when code ownership is unclear.
- Use exactly one `implementation_worker` when delegating implementation.
- Use one `build_validator`; use `final_reviewer` only on the current diff when risk justifies it.
- Make at most one build attempt unless the user approves another.
- Do not use `task_planner` when the request or supplied plan is already clear.

### Deep Mode

Use only for Supabase, RLS, authentication, migrations, storage, major navigation changes, large refactors, or ambiguous architecture decisions.

- May use `task_planner`, `supabase_contract_auditor`, and more detailed review.
- The validation plan must be explicit before implementation.
- Deep Mode does not authorize multiple primary tasks or multiple implementation workers.

## Memory Reading Budget

Start with only:

1. `AGENTS.md`
2. `docs/00_memory/CURRENT_STATE.md`
3. `docs/06_tasks/TASK_LEDGER.md` if present
4. the active task intake file

Read `PROJECT_MEMORY.md`, long Briefs, architecture/backend docs, feature indexes, historical reports, or broad source areas only when the active task directly needs them. Do not re-read files already summarized in the active intake.

## Subagent Budget

- Do not spawn all agents by default.
- Quick Mode normally uses none.
- Standard Mode uses only the smallest justified subset of `context_librarian`, `ios_code_mapper`, `implementation_worker`, `build_validator`, and optional `final_reviewer`.
- Use `supabase_contract_auditor` only when backend impact exists or is uncertain.
- Use `task_planner` only for unclear, oversized, high-risk, or unplanned work. Never spawn it when the user supplied a clear implementation plan.
- If `task_planner` fails or times out once, record the failure and continue with a smaller safe plan. Do not retry it in the same run.
- Never run multiple implementation agents for one task.

## Validation Budget

- Quick Mode: no build/test unless necessary for the edited file.
- Standard Mode: one build attempt by default.
- Deep Mode: state the build/test plan explicitly.
- UI tests run only when launch behavior, navigation, or UI interaction directly changed.
- If validation fails, report the first real error and stop unless the user authorizes a fix loop or follow-up task.

## Initialization Task Limits

- Do not use TDD RED/GREEN loops.
- Do not create extensive test suites; minimal smoke tests are optional only when necessary.
- Run at most one build validation attempt.
- On build failure, report the first real error and stop. Do not enter a build-fix loop without explicit user approval.
- Do not implement product features during initialization.

## Superpowers Limit

- Check whether Superpowers is available.
- Use at most one directly relevant capability by default; multiple skills are allowed only in Deep Mode.
- Normal execution must not depend on Superpowers.
- Superpowers must not expand task scope or override repository/user limits.
- Report usage in one brief line.

## Report Budget

- Subagent reports are short, structured, and no more than 30 lines by default.
- Quick Mode may skip intermediate reports unless the task explicitly requires them.
- Final reports should state files, behavior/rules, checks, risks, and next action without narrative history.

## Stop Conditions

Stop when the single primary task and its budgeted validation are complete. Stop earlier when scope becomes unclear, a destructive action is required, user work conflicts, validation fails, or the task exceeds its selected mode. Do not start an adjacent task.
