# CLAUDE.md

Claude adapter for the Beckon repository. `AGENTS.md` and its five owner workflow files are authoritative; this file adds no parallel workflow.

## Default Role

Claude defaults to read-only review, analysis, and recommendations. Modify files only when the user explicitly authorizes implementation. Any authorized change uses the next ledger task ID and the same single-task, validation, closeout, remote-write, and Git gates as Codex.

## Startup

1. Read `AGENTS.md`.
2. Read targeted `docs/00_memory/CURRENT_STATE.md` or `docs/06_tasks/TASK_LEDGER.md` only when their facts matter.
3. Use `docs/README.md` or `docs/00_memory/FEATURE_INDEX.md` to route one domain task.
4. Treat root reports, frozen archives, heavy UI inventory, old task files, and Claude reference snapshots as historical/review input only.

## Boundaries

Preserve the Request -> Offer -> Acceptance -> Booking/Chat -> Completion -> Review lifecycle, role separation, repository boundaries, and secret hygiene. Do not copy prototype runtime code into SwiftUI or infer product/backend behavior from screenshots.

Changes to `AGENTS.md`, this adapter, or `docs/05_workflow/**` require a standalone task, decision entry, and context hygiene. Current task/branch facts come only from active memory and ledger sources.
