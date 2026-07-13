# Meta Review Template

Use this template for a periodic documentation-governance review.

## Trigger

Run one meta-review task every 10 completed tasks or once per week, whichever comes first. Assign a normal `T-###` from `TASK_LEDGER.md`; do not treat the review as background maintenance.

When the tenth task closes, `context-hygiene-check.mjs` permits that closeout only if `CURRENT_STATE.md` explicitly reserves the immediate next task for the required periodic meta-review. The reserved task must run next. An unscheduled tenth-task gap or any gap greater than ten still fails.

The triggering task finishes its own validation, closeout, commit, and push, reserves the immediate next ID, and ends the session. The reserved meta-review runs next only in a fresh session after user continuation/request. It never starts automatically in the triggering task's context.

## Scope

- Active Markdown structure, links, budgets, and `.rgignore` behavior.
- `CURRENT_STATE.md`, `TASK_LEDGER.md`, `WORKLOG.md`, `ROADMAP.md`, and `FEATURE_INDEX.md` consistency.
- `Last verified` markers and migration mirror count checked by context hygiene.
- Root/external-agent Markdown that should be frozen or ignored.
- New repeated rule friction that belongs in workflow docs or `DECISION_LOG.md`.

## Required Checks

Use Quick workflow-rule validation from `../05_workflow/TOOLING_POLICY.md`, run context hygiene, and add targeted `rg` checks for the specific governance concern.

## Closeout

Record only current facts and actions taken. If no changes are needed, add a compact ledger/worklog closeout and do not expand durable memory.

Update `docs/00_memory/CURRENT_STATE.md` with:

```text
- Last meta-review: T-### on YYYY-MM-DD.
```

After the meta-review passes hygiene and its commit/push completes, write a compact recovery checkpoint and invoke host compaction. If no callable compaction control exists, emit an explicit `/compact` handoff and stop without starting the next implementation task. Never claim the conversation was compacted when the host did not expose that operation.
