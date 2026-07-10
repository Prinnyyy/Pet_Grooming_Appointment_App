# Meta Review Template

Use this template for a periodic documentation-governance review.

## Trigger

Run one meta-review task every 10 completed tasks or once per week, whichever comes first. Assign a normal `T-###` from `TASK_LEDGER.md`; do not treat the review as background maintenance.

When the tenth task closes, `context-hygiene-check.mjs` permits that closeout only if `CURRENT_STATE.md` explicitly reserves the immediate next task for the required periodic meta-review. The reserved task must run next. An unscheduled tenth-task gap or any gap greater than ten still fails.

## Scope

- Active Markdown structure, links, budgets, and `.rgignore` behavior.
- `CURRENT_STATE.md`, `TASK_LEDGER.md`, `WORKLOG.md`, `ROADMAP.md`, and `FEATURE_INDEX.md` consistency.
- `Last verified` markers and migration mirror count checked by context hygiene.
- Root/external-agent Markdown that should be frozen or ignored.
- New repeated rule friction that belongs in workflow docs or `DECISION_LOG.md`.

## Required Checks

```sh
git status --short
git diff --check
node scripts/context-hygiene-check.mjs
```

Add targeted `rg` checks for the specific concern being audited.

## Closeout

Record only current facts and actions taken. If no changes are needed, add a compact ledger/worklog closeout and do not expand durable memory.

Update `docs/00_memory/CURRENT_STATE.md` with:

```text
- Last meta-review: T-### on YYYY-MM-DD.
```
