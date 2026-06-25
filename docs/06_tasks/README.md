# Task Directory Guide

Use this directory for task records, templates, and task-specific artifacts. Start with `TASK_LEDGER.md` when selecting or checking task status.

## Primary Files

- `TASK_LEDGER.md`: compact status list for all tracked tasks.
- `TASK_INTAKE_TEMPLATE.md`: template for defining a new task.
- `LIGHTWEIGHT_TASK_PROMPT_TEMPLATE.md`: template for lightweight task prompts.
- `SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`: template for screenshot-driven Groomly UI work.
- `HANDOFF_TEMPLATE.md`: checkpoint handoff template.
- `REVIEW_TEMPLATE.md`: review template.

## Task Families

- `T-001` through `T-022`: MVP foundation, backend, iOS, booking, chat, reviews, and hardening.
- `T-023*` through `T-035`: completed and archived Groomly UI foundation sequence.
- `T-036` through `T-062`: screenshot-driven Groomly UI and stability refinements.
- `T-063` through `T-074`: pet-fit matching contract, taxonomy, SQL helpers, groomer/review evidence input, evidence summary, backend match scoring, iOS fit-reason surfacing, availability enforcement, availability-aware matching, low-confidence claim/portfolio match signals, and customer offer match evidence surfacing.
- `WORKFLOW-*`: workflow policy tasks.

## Task Artifacts

- `sql_reviews/`: reviewed SQL drafts attached to task records before or during backend migration work.
- Deployed and prepared migration mirrors live in `../../supabase/migrations/`, not in this directory.
- Historical frozen task snapshots live under `../09_frozen/`.

## Notes

- Keep new task closeouts as individual `T-###_*.md` files at this directory root unless a future task explicitly introduces a new task-family archive.
- Do not move completed task docs just to reduce the root listing; task IDs are easier to scan when they stay in one chronological folder.
- Put non-Markdown task attachments in a named subfolder such as `sql_reviews/` so the main listing remains readable.
