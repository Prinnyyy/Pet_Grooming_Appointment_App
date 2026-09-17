# Context and Recovery

Owns: context access, recovery, compaction, and context hygiene.

## Access Model

| Layer | Read condition | Typical files |
|---|---|---|
| L0 required | Every session | `AGENTS.md` only |
| L0 state | Only when branch, task number, validation, risk, editing, or recovery requires it | targeted top of `docs/00_memory/CURRENT_STATE.md`; targeted top of `docs/06_tasks/TASK_LEDGER.md`; an explicitly supplied active task file |
| L1 index | One index after task classification | `docs/README.md`, `docs/00_memory/FEATURE_INDEX.md`, Roadmap for planning, Supabase/TestOps/structure indexes |
| L2 rules | Targeted sections needed for implementation/validation | product, architecture, backend, iOS/TestOps, and the relevant owner workflow file |
| L3 trace | Search first, then narrow line ranges | Worklog, Project Memory, Decision Log, Reorganization Log |
| L4 frozen/heavy | Named recovery, comparison, seed, migration, or design-source purpose only | `docs/09_frozen/**`, heavy UI body, Beckon export, seed tables, generated artifacts, broad migration history |

Start at L0 and stop reading when the next safe action is clear. Default searches honor `.rgignore`; bypass it only for a named ignored target. Do not use broad Markdown globs that re-include hidden files.

## Expansion And Stop

Search a target before reading it and prefer headings or line ranges. Expand one layer at a time and state why L3/L4 is needed.

Stop under `STOP_CONDITIONS.md` when source and docs conflict, a broad archive/export/seed/migration/Swift read appears necessary, the L4 purpose is unclear, critical current facts are missing, user work would be overwritten, or context expansion reveals another primary task.

## Durable Facts

- Task ID/status/next number: `docs/06_tasks/TASK_LEDGER.md`.
- Branch/latest validation/current risks: `docs/00_memory/CURRENT_STATE.md`.
- Recent closeout/checkpoint evidence: `docs/00_memory/WORKLOG.md`.
- Feature routing: `docs/00_memory/FEATURE_INDEX.md`.
- Durable decisions: `docs/07_decisions/DECISION_LOG.md`.
- Validation/remote authorization: `TOOLING_POLICY.md`.
- Git conventions: `GITHUB_RULES.md`.

Do not store secrets, source copies, full logs/diffs, generated output, or unverified assumptions in durable memory.

## Context Hygiene

Run after changes to durable memory, ledger, workflow rules, or active coordination documents:

```sh
node scripts/context-hygiene-check.mjs
```

The check owns active links, ignored-path visibility, current-fact alignment, workflow ownership, entry windows, and informational word telemetry. Generic word references do not trigger stopping or archival; the compact `AGENTS.md` and `CLAUDE.md` adapter ceilings are enforced workflow interfaces.

Ledger, Worklog, and Decision Log rotate only when their structural entry triggers are exceeded. Numbered durable task closeout uses `node scripts/task-closeout.mjs --task T-### --apply`; it performs a safe rotation preview, completed-artifact/backlink checks, one apply batch, and final hygiene. Run `context-rotate.mjs` directly only for a targeted recovery or governance repair. Index files replace stale facts, and completed task artifacts move verbatim to the matching frozen family after active pointers are updated.

## Recovery

After interruption, stale context, or compaction:

1. Read `AGENTS.md`.
2. Read targeted Current State and Task Ledger facts only if the active work needs them.
3. Inspect `git status --short` and `git diff --stat`.
4. Read an active task file only when explicitly supplied/requested.
5. Search the newest Worklog checkpoint only if the next step remains unclear.
6. Separate current-task edits from unrelated user work and choose the smallest safe next action.

Do not reconstruct archived subagent state, reload report chains, repeat completed validation automatically, use stash as recovery state, or revert user work.

## Checkpoint And Compaction

Task/session end is the default context reset. Repository Markdown cannot infer the host's real token budget. Use host-reported context pressure when available; without telemetry, checkpoint based on task size, output growth, uncertainty, and recovery risk rather than a guessed capacity.

Before ending an incomplete task or invoking compaction, record: task ID/status, files changed, validation attempted, decisions/evidence, risks, and the exact next context/action. Git authorization for incomplete checkpoint commits belongs to `GITHUB_RULES.md`.

If the host exposes compaction control, invoke it only after the checkpoint. Otherwise emit an explicit `/compact` handoff and stop. A completed periodic meta-review always creates this compaction boundary; do not begin implementation work after it in the same session.
