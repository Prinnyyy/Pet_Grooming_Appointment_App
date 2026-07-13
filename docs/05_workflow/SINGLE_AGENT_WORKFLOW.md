# Single-Agent Workflow

Owns: task lifecycle, task boundaries, modes, closeout, and meta-review scheduling.

Validation commands belong only to `TOOLING_POLICY.md`; Git conventions belong only to `GITHUB_RULES.md`; read/recovery rules belong only to `CONTEXT_AND_RECOVERY.md`; stop triggers belong only to `STOP_CONDITIONS.md`.

## Task Lifecycle

1. Identify one user-visible primary objective.
2. Confirm the branch and next task ID only when the work changes files or durable state.
3. Classify the task mode and make a short plan for non-trivial work.
4. Read the smallest context allowed by `CONTEXT_AND_RECOVERY.md`.
5. Implement only the approved objective; stop before an independent feature or rule change.
6. Run the mode's completion validation from `TOOLING_POLICY.md`.
7. Review status and diff; separate unrelated user work.
8. Write only the required closeout facts.
9. For a numbered durable closeout, run the unified closeout gate described below.
10. Complete Git closeout under `GITHUB_RULES.md` when Tooling authorization permits it.
11. End the session. A later user request starts the next task.

## Modes

| Mode | Scope |
|---|---|
| Micro | Read-only answers, status checks, or tiny wording with no durable effect. |
| Quick | Docs, workflow, focused scripts, or narrow low-risk fixes. |
| Standard | Swift/Xcode, visible UI, app behavior, or normal feature/bug work. |
| Deep | Supabase, auth, RLS, migrations, Storage, major navigation, destructive risk, or broad shared contracts. |

Mode determines validation depth, not permission. Remote and destructive operations still use Tooling authorization gates.

## Task Boundary

- Allocate one `T-###` for each implementation, bugfix, iteration, governed rule change, or requested durable audit.
- A test run alone is not a task unless it changes test infrastructure, records governed remote evidence, or the user explicitly requests it as the objective.
- A bugfix discovered inside the current objective stays in the task only when it is necessary, local, and covered by the same validation. Otherwise record it and stop.
- Do not start adjacent cleanup, roadmap work, dependency changes, or unrelated refactors.
- Do not use a second task ID in the same session.

## Closeout

Update `TASK_LEDGER.md` and `WORKLOG.md` when the task is Standard/Deep or changes app behavior, workflow rules, backend contracts, durable state, or task coordination. Tiny Micro/Quick work that future runs do not need may skip durable closeout.

Before a numbered durable closeout, mark its ledger row completed, add one compact Worklog entry, and replace the Current State task baseline with the completed and next IDs. Change other Current State sections only when future startup needs the new validation, risk, branch, or product fact. `FEATURE_INDEX.md` changes only when routing/ownership changes. `DECISION_LOG.md` changes only for a durable architecture, product, backend, or workflow decision.

Run `node scripts/task-closeout.mjs --task T-### --apply` after those facts are ready. It verifies their alignment, blocks active backlinks to pending artifacts, archives eligible completed plans/specs, applies structural window rotation, and runs context hygiene. Omit `--apply` for a read-only preview; add `--verbose` only when diagnostics are needed.

Task-specific plans/specs live temporarily under `docs/superpowers/` and use its metadata contract. Mark them completed only at closeout. The gate moves them verbatim to the dated frozen Superpowers family. Markdown moves/deletions update every active backlink and index in the same task.

## Rule Changes

Changes to `AGENTS.md`, `CLAUDE.md`, or `docs/05_workflow/**` must be one standalone numbered task. They require a decision-log entry, affected indexes, workflow contract checks, and context hygiene. If a rule change appears inside another task, stop and split it.

## Periodic Meta-Review

Context hygiene owns cadence detection. When completing a task makes the review exactly due, reserve the next task ID and end the current task after its normal closeout. Do not start the review in the same session. The reserved review runs only in a fresh session after a user continuation/request and has its own task ID, validation, closeout, commit, and push.

After the meta-review itself completes, follow the mandatory compaction boundary in `CONTEXT_AND_RECOVERY.md`.

## Screenshot UI Tasks

One uploaded screenshot is one task unless the user explicitly combines scope. Use `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`; map each visible in-app module to current SwiftUI, Store, repository, and model ownership. Ignore prototype controls outside the app frame.

Visual-only work, existing-feature rewiring, and small presentation primitives may stay in scope. Stop before new persistence, backend behavior, navigation, role capability, deferred features, or direct Supabase access from SwiftUI.
