# Single-Agent Workflow

Default workflow for this repository. It keeps each run bounded, recoverable, and proportional to risk.

## Core Rules

- Complete one primary task per run.
- Preserve user work and inspect `git status --short` before edits.
- Use targeted context only; access tiers live in `CONTEXT_AND_RECOVERY.md`.
- Do not start adjacent features, broad refactors, commits, pushes, seeds, cleanup, or remote writes unless explicitly requested.
- No subagents or archived agent-team orchestration unless the user explicitly re-enables them.
- Write a short plan before non-trivial edits.
- Use one validation attempt by mode unless the user approves more.
- Stop after the requested task is complete.

## Task Flow

1. Identify the single primary task.
2. Classify it as Micro, Quick, Standard, or Deep.
3. Read only the L0/L1 context needed to plan the work.
4. Expand to L2/L3/L4 context only under the access rules in `CONTEXT_AND_RECOVERY.md`.
5. Implement only the approved scope.
6. Run mode-appropriate validation.
7. Review the current diff.
8. Update task closeout and durable memory only when the completion gate requires it.
9. Run context hygiene if durable memory or task ledgers changed.
10. Launch the simulator only when required.
11. Write a checkpoint before manual compaction.
12. Stop.

## Modes

| Mode | Use For | Validation |
|---|---|---|
| Micro | Read-only answers, status checks, command output, tiny docs wording | None by default |
| Quick | Docs, workflow changes, small scripts, one-file fixes | `git diff --check` when files changed |
| Standard | Normal iOS feature, bug, visible UI, user-facing app behavior | `git diff --check` plus one `./scripts/ios-build.sh`; simulator launch for visible UI/app behavior |
| Deep | Supabase, auth, RLS, migrations, storage, major navigation, destructive-risk work | State validation plan before edits; make one planned attempt |

## Completion Gate

Always:

- Keep the final response scoped to the user request.
- Report validation run or why it was intentionally skipped.
- Report if iOS build, simulator, tests, Supabase, commit, or push were intentionally not run.

Task closeout in `TASK_LEDGER.md` and `WORKLOG.md` is required when:

- The user provided or requested a task file.
- The task is Standard or Deep.
- The task changes Swift, app behavior, visible UI, backend contracts, Supabase, auth, navigation, persistence, workflow rules, or durable state future runs need.

Task closeout is usually skipped for Micro tasks and tiny docs-only Quick tasks that future runs do not need.

Durable memory updates are limited to changed facts:

- `docs/00_memory/CURRENT_STATE.md`: current branch, latest completed task, validation baseline, active risks, next-task facts.
- `docs/00_memory/WORKLOG.md`: recent closeout/checkpoint evidence.
- `docs/06_tasks/TASK_LEDGER.md`: task numbering and status.
- `docs/00_memory/FEATURE_INDEX.md`: feature ownership or routing changes.
- `docs/07_decisions/DECISION_LOG.md`: durable architecture/product decisions.

After durable memory or ledger changes, run context hygiene and archive old rows/content in the same task if thresholds are exceeded.

## Screenshot UI Tasks

One uploaded screenshot is one primary task unless the user explicitly says otherwise.

Before SwiftUI edits:

- Use `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` as the checklist.
- Map every visible in-app module to an existing SwiftUI surface, Store, repository, model, or mark it as a new feature.
- Ignore any long oval Customer/Groomer toggle above the visible app frame.

Allowed inside a screenshot task:

- Visual-only work.
- Existing-feature rewiring to current Store/repository/model paths.
- Small reusable DesignSystem primitive work within the screenshot scope.

Stop before:

- New persistence, schema, RLS, RPC, Storage, navigation, role capability, or deferred-feature work.
- Direct Supabase access from SwiftUI.
- Copying HTML/CSS/React into SwiftUI.

## Compaction

Compaction belongs at task boundaries. Before `/compact`, write a checkpoint with task ID/status, files changed, validation, key decisions, risks, and next context.

## Reporting

Keep final reports concise. Use the final response rules in `AGENTS.md`; do not create a separate report file unless the user explicitly asks for one.
