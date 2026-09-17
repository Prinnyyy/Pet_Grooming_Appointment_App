# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-07-09

```text
Decision ID: D-012
Date: 2026-07-08
Decision: Reduce active Markdown before raising the 32k total budget.
Context: After T-178, active Markdown was about 92% of the 32k limit, and the watch-items review found no single giant file. The risk is slow long-tail growth across many indexes.
Consequences: T-179 lowers rolling windows to 8 worklog entries and 12 ledger rows, tightens old decision/structure budgets, and trims active indexes first. A one-time increase to 36,000 words is allowed only if two consecutive meta-reviews both find total active Markdown above 90% and no safe reduction item remains.
Linked files: scripts/context-hygiene-check.mjs, docs/00_memory/WORKLOG.md, docs/06_tasks/TASK_LEDGER.md, docs/10_project_structure/README.md
```
