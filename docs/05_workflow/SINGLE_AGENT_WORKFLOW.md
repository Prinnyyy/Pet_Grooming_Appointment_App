# Single-Agent Workflow

## Purpose

This is the default Codex workflow. It is optimized for limited context, interrupted sessions, and small verifiable changes. Archived agent-team materials are historical only.

## Core Rules

- One primary task per Codex run.
- No adjacent features.
- No broad refactors unless explicitly requested.
- No subagents by default.
- No long chain-of-thought style reports.
- No repeated build-fix loops.
- No repeated test-fix loops.
- No commit or push unless the user explicitly asks.
- Prefer small, reversible changes.
- Stop once the requested task is complete.

Do not dispatch `context_librarian`, `task_planner`, `ios_code_mapper`, `supabase_contract_auditor`, `implementation_worker`, `build_validator`, or `final_reviewer`. Do not create per-agent reports or use the archived dispatch protocol. Multi-agent orchestration requires a future explicit user request.

## Minimal Context Reading

Default read list:

1. `AGENTS.md`
2. `docs/00_memory/CURRENT_STATE.md`
3. `docs/06_tasks/TASK_LEDGER.md` if present
4. the active task file, if provided

Only read these when directly relevant:

- long project briefs,
- full `PROJECT_MEMORY.md`,
- architecture docs,
- Supabase docs,
- old task reports,
- historical decision logs.

Do not read large documents unless needed for the current task.

## Default Flow

1. Read minimal context.
2. Identify exactly one primary task.
3. Write a short plan.
4. Implement only that task.
5. Run one appropriate validation attempt.
6. Review the current diff briefly.
7. Update durable memory only if project state changed.
8. Stop.

## Task Modes

### Quick Mode

Use for documentation edits, small script edits, one-file fixes, and simple UI text/style changes.

Rules:
- no build or test unless necessary,
- no large memory updates,
- no report folder unless useful.

### Standard Mode

Use for normal iOS feature or bug tasks.

Rules:
- write a short plan before implementation,
- make one implementation pass,
- make one build attempt by default,
- do not run UI tests unless UI launch/navigation behavior changed,
- update memory if feature state changed.

### Deep Mode

Use for Supabase, auth, RLS, migrations, storage, large navigation changes, major architecture changes, and ambiguous or high-risk work.

Rules:
- read relevant architecture/backend docs,
- write a more explicit plan,
- ask the user before destructive or high-risk changes,
- state the validation plan explicitly.

## Validation Policy

- Quick Mode: no validation unless directly needed.
- Standard Mode: one build attempt by default.
- Deep Mode: an explicit validation plan is required.
- UI tests are not default.
- Unit tests are not default for initialization tasks.
- If build or test fails, report the first real error and stop.
- Do not enter a fix loop unless the user approves a follow-up task.

## Superpowers

Superpowers is optional. Use at most one directly relevant capability when it clearly reduces risk or effort. Skip it otherwise. It must not expand scope, add review chains, or trigger branch workflows that the user did not request.

## Durable Memory

Update only what changed:

- `docs/00_memory/CURRENT_STATE.md` when project state changed,
- `docs/00_memory/WORKLOG.md` after meaningful implementation,
- `docs/06_tasks/TASK_LEDGER.md` when a tracked task status changed,
- `docs/00_memory/FEATURE_INDEX.md` when a feature was added, removed, or changed,
- `docs/07_decisions/DECISION_LOG.md` when a durable architecture/product decision changed.

Do not update memory for tiny documentation-only changes unless needed.

## Reporting

Do not create per-agent reports. Write one concise final report only when useful or explicitly requested. Use `LIGHTWEIGHT_FINAL_REPORT_TEMPLATE.md` when a durable report is needed.
