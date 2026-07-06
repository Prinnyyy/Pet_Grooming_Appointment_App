# Task Ledger

Task numbering and active status live here. This file is not a full history.

## Numbering

- Last completed task: T-049.
- Next available task ID: T-050.
- Historical T-001 through T-048 task files: `docs/09_frozen/task_records_2026-07-06/`.
- Historical full ledger snapshot: `docs/09_frozen/task_ledgers/TASK_LEDGER_T-000_TO_T-048_2026-07-06.md`.

## Active And Recent

| ID | Task | Status | Mode | Scope | Validation | Notes |
|---|---|---|---|---|---|---|
| T-049 | Repair active Markdown information architecture | completed | Quick | AGENTS/workflow/memory/task/design/archive docs | `git diff --check`; `node scripts/context-hygiene-check.mjs` | Archived stale active task records, old brief, old design prompt, external agent reports, and legacy workflow docs; installed indexed L0-L4 rules |
| T-048 | Customer new request wizard rework | completed | Standard | iOS customer request wizard | build, targeted tests, diff-check, simulator | Historical task record archived |
| T-047 | Customer request booked card layout and follow-ups | completed | Standard | iOS request cards, Home sync, feedback overlay | build/tests/diff-check/simulator per task | Historical task record archived |
| T-046 | Customer request handoff card fusion | completed | Standard | iOS request/booked handoff | build/tests/diff-check/simulator | Historical task record archived |
| T-045 | Customer request booking handoff | completed | Standard | iOS request-to-booking handoff | build/tests/diff-check/simulator | Historical task record archived |
| T-044 | Customer request cancellation | completed | Deep | Supabase RPC and iOS wiring | Supabase MCP checks, build/tests/diff-check/simulator | Historical task record archived |

## Rules

- Do not create a standalone task file by default for Micro/Quick docs-only work.
- Create a standalone task file when the user asks, the task is Standard/Deep, or a long-running task needs its own spec/checkpoint.
- Bugfixes and follow-up iterations get their own task ID when they change app behavior, backend behavior, validation infrastructure, or durable workflow state.
- A test run alone is not a task unless it changes the test system, records durable validation evidence, or the user requests it as a tracked task.
- Do not auto-start the next task.
