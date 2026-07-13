# Task Directory Guide

Use this directory for the active task ledger, templates, and task-specific artifacts. Start with `TASK_LEDGER.md` when selecting or checking task status.

## Primary Files

- `TASK_LEDGER.md`: the active/recent task-status and task-numbering record.
- `ROADMAP.md`: governed unresolved-direction index. It does not allocate task IDs or retain completed milestone history.
- `ROADMAP_EXECUTION_QUEUE.md`: deferred/blocked package queue derived from the roadmap. It does not allocate task IDs.
- `SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`: template for screenshot-driven Beckon UI work.
- `META_REVIEW_TEMPLATE.md`: template for weekly or every-10-tasks documentation-governance reviews.

## Task Families

Historical detailed task files for `T-001` through `T-088` and completed `WORKFLOW-*` policy tasks now live under `../09_frozen/task_records_2026-06-26/`.

Completed standalone plans, brand/address migration contracts, and pre-rotation roadmap snapshots live under `../09_frozen/completed_task_plans/`, dated `../09_frozen/superpowers_*/` families, and `../09_frozen/roadmaps/`. Current identity and address contracts live in `../01_product/BRAND_IDENTITY.md`, `../02_architecture/DATA_FLOW.md`, and their linked domain policies.

Use `TASK_LEDGER.md` as the merged active record for task families, status, checks, and notes. Use `ROADMAP.md` for milestone direction and candidate backlog; use `ROADMAP_EXECUTION_QUEUE.md` to choose an adoptable package when the user asks for roadmap work.
Older completed ledger rows are archived under `../09_frozen/task_ledgers/` when context hygiene thresholds are exceeded.
Old generic task templates are archived under `../09_frozen/task_templates/`; do not restore them unless a future workflow task proves they are needed.

## Task Artifacts

- `sql_reviews/`: reviewed SQL drafts attached to task records before or during backend migration work.
- Deployed and prepared migration mirrors live in `../../supabase/migrations/`, not in this directory.
- Historical detailed task records live under `../09_frozen/task_records_2026-06-26/`.

## Notes

- Current branch baseline is `codex/pet-fit-structure-cleanup` unless the user explicitly names another branch.
- Start new bugfix and iteration records from the next available task ID in `TASK_LEDGER.md`; do not add unrelated follow-up notes to archived task files.
- Do not infer task numbers from `ROADMAP.md` or external plans.
- Do not create individual `T-###_*.md` task files by default. Use `TASK_LEDGER.md` plus `docs/00_memory/WORKLOG.md` unless the user explicitly requests a standalone task spec.
- If a standalone spec is needed, keep it short and include primary task, out of scope, validation, stop condition, and closeout fields inline.
- Put temporary implementation plans/specs under `../superpowers/`, follow its task-artifact metadata contract, and let the unified closeout gate freeze completed files.
- Keep `TASK_LEDGER.md` compact. If it grows beyond the context hygiene threshold, keep active/blocked/recent rows here and archive older completed rows under `../09_frozen/task_ledgers/`.
- Run `node ../../scripts/context-hygiene-check.mjs` from this directory, or `node scripts/context-hygiene-check.mjs` from the repo root, after tasks that update durable coordination docs.
- Put non-Markdown task attachments in a named subfolder such as `sql_reviews/` so the main listing remains readable.
