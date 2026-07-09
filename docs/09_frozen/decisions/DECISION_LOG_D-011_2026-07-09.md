# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-07-09

```text
Decision ID: D-011
Date: 2026-07-08
Decision: Keep branch baseline as a single active fact in CURRENT_STATE.
Context: `AGENTS.md`, `TASK_LEDGER.md`, and `CURRENT_STATE.md` all named the branch baseline, but hygiene checked only the latter two.
Consequences: `AGENTS.md` now points to `CURRENT_STATE.md` for branch baseline. `TASK_LEDGER.md` keeps its task-numbering baseline and remains checked against CURRENT_STATE by hygiene. Claude's entry map includes ROADMAP, Git rules, and this decision log for planning and rule review.
Linked files: AGENTS.md, CLAUDE.md, docs/00_memory/CURRENT_STATE.md, docs/06_tasks/TASK_LEDGER.md, docs/07_decisions/DECISION_LOG.md
```
