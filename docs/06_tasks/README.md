# Task Directory Guide

Use this directory for the active task ledger, templates, and task-specific artifacts. Start with `TASK_LEDGER.md` when selecting or checking task status.

## Primary Files

- `TASK_LEDGER.md`: the single active task-status and task-numbering record.
- `TASK_INTAKE_TEMPLATE.md`: template for defining a new task.
- `LIGHTWEIGHT_TASK_PROMPT_TEMPLATE.md`: template for lightweight task prompts.
- `SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`: template for screenshot-driven Groomly UI work.
- `HANDOFF_TEMPLATE.md`: checkpoint handoff template.
- `REVIEW_TEMPLATE.md`: review template.

## Task Families

Historical detailed task files for `T-001` through `T-088` and completed `WORKFLOW-*` policy tasks now live under `../09_frozen/task_records_2026-06-26/`.

Use `TASK_LEDGER.md` as the merged active record for task families, status, checks, and notes.

## Task Artifacts

- `sql_reviews/`: reviewed SQL drafts attached to task records before or during backend migration work.
- Deployed and prepared migration mirrors live in `../../supabase/migrations/`, not in this directory.
- Historical detailed task records live under `../09_frozen/task_records_2026-06-26/`.

## Notes

- Current branch baseline is `codex/pet-fit-structure-cleanup` unless the user explicitly names another branch.
- Start new bugfix and iteration records from the next available task ID in `TASK_LEDGER.md`; do not add unrelated follow-up notes to archived task files.
- Do not create individual `T-###_*.md` task files by default. Use `TASK_LEDGER.md` plus `docs/00_memory/WORKLOG.md` unless the user explicitly requests a standalone task spec.
- Put non-Markdown task attachments in a named subfolder such as `sql_reviews/` so the main listing remains readable.
