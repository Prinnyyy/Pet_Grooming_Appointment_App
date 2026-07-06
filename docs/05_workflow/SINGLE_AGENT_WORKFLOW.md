# Single-Agent Workflow

Default Codex workflow for this repository.

## Core Rules

- One primary task only.
- Preserve user work and run `git status --short` before edits.
- Start from L0 context only, then expand by task type.
- No subagents, archived agent-team protocols, broad refactors, remote writes, commits, pushes, or PRs unless the user explicitly asks.
- Stop after the requested task is complete.

## Flow

1. Identify the single primary task.
2. Classify it as Micro, Quick, Standard, or Deep.
3. Read L0 and at most one L1 index before deciding whether more context is needed.
4. Write a short plan before non-trivial edits.
5. Implement only the approved scope.
6. Run mode-appropriate validation once.
7. Review the diff briefly.
8. Update durable memory only when future runs need the changed fact.
9. Run context hygiene after durable memory or task-ledger edits.
10. Commit/push only when the user explicitly requested it.

## Modes

| Mode | Use For | Validation |
|---|---|---|
| Micro | Read-only answers, status checks, tiny wording edits | None by default |
| Quick | Docs, workflow, small scripts, one-file non-behavior fixes | `git diff --check`; context hygiene when memory/ledger changed |
| Standard | Swift, app behavior, visible UI, normal bugs | `git diff --check` plus one `./scripts/ios-build.sh`; simulator for visible UI |
| Deep | Supabase, auth, RLS, migrations, storage, major navigation, high risk | State plan first; run the planned checks once |

If required validation fails, report the first real error and stop unless the user approves a follow-up.

## Screenshot-Driven Groomly UI

One uploaded screenshot is one bounded UI rework task unless the user explicitly combines or splits scope.

Before SwiftUI edits:

- map each visible module to existing SwiftUI, Store, repository, and model ownership;
- classify each module as visual-only, existing-feature rewire, reusable UI primitive, or new feature;
- stop before new persistence, schema, RLS, RPC, Storage behavior, navigation, role capability, or deferred feature work.

Do not copy HTML/CSS/React into SwiftUI. Use design assets and notes only as visual reference.

## Durable Closeout

Update:

- `docs/06_tasks/TASK_LEDGER.md` for task ID/status/next ID facts.
- `docs/00_memory/WORKLOG.md` for meaningful closeout/checkpoints.
- `docs/00_memory/CURRENT_STATE.md` only for current facts future runs need.
- `docs/00_memory/FEATURE_INDEX.md` only when feature routing/status changed.
- `docs/07_decisions/DECISION_LOG.md` only for durable product/architecture decisions.

Then run:

```sh
node scripts/context-hygiene-check.mjs
```
