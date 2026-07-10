# Single-Agent Workflow

Default workflow for this repository. It keeps each run bounded, recoverable, and proportional to risk.

## Core Rules

- Complete one primary task per run.
- Preserve user work and inspect `git status --short` before edits.
- Use targeted context only; access tiers live in `CONTEXT_AND_RECOVERY.md`.
- Do not start adjacent features, broad refactors, seeds, unrelated cleanup, or non-Git remote writes unless explicitly requested.
- Standing Git approval is active: after a task is complete and required validation passes, commit and push that task's own changes automatically.
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
9. Run context hygiene if durable memory or task ledgers changed; resolve entry-count overflow with one `node scripts/context-rotate.mjs --apply` batch before closeout.
10. Launch the simulator only when required.
11. Create a task-scoped commit and push the current branch when completion and validation have passed.
12. Write a checkpoint before manual compaction.
13. Stop.

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

After durable memory or ledger changes, run context hygiene. Word/reference output is informational only. If an entry-count window exceeds its trigger, run `node scripts/context-rotate.mjs --apply` once and rerun hygiene; the batch must reach the retained count. Freeze completed task-specific plans/specs instead of leaving them in the active search path.

## Automatic Git Closeout

The user has granted standing approval for Codex to commit and push each completed task.

Automatic commit/push requirements:

- Run required validation for the task mode first.
- Review `git status --short` and the diff before staging.
- Stage only files changed for the current task.
- Use the task-prefixed commit format from `GITHUB_RULES.md`.
- Push only the current work branch.
- Skip commit/push and report why if validation fails, the branch is unclear, secrets appear in the diff, unrelated user work would be included, or the user explicitly disables auto Git for the task.
- If push fails or is rejected, stop and report; do not auto pull, rebase, merge, reset, force-push, or retry remote reconciliation.

This standing approval does not authorize PR creation, tags, branch deletion, merge/rebase/reset, Supabase writes, seeds, unrelated cleanup, or other remote operations.

## Rule Change Tasks

Changes to `AGENTS.md`, `CLAUDE.md`, or any file under `docs/05_workflow/` are workflow-rule changes.

Workflow-rule changes must:

- Use a standalone `T-###` task; do not bundle them with app, backend, design, or cleanup work.
- Update `docs/07_decisions/DECISION_LOG.md` with the rule decision and affected files.
- Update task closeout and current state when the changed rule affects future runs.
- Run `git diff --check` and `node scripts/context-hygiene-check.mjs` before closeout.

Stop and split scope if a workflow-rule change appears during another task.

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

Compaction belongs at task boundaries and follows the 353,000-token 65%/80% thresholds in `CONTEXT_AND_RECOVERY.md`; Markdown word telemetry never triggers it. Before `/compact`, write a checkpoint with task ID/status, files changed, validation, key decisions, risks, and next context.

## Reporting

Keep final reports concise. Use the final response rules in `AGENTS.md`; do not create a separate report file unless the user explicitly asks for one.
