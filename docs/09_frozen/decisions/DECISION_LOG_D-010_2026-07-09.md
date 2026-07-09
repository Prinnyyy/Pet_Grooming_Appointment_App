# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-07-09

```text
Decision ID: D-010
Date: 2026-07-08
Decision: Track meta-review cadence by completed-task distance, not wall-clock age.
Context: The review plan requires a marker for "every 10 completed tasks or weekly" so hygiene can catch missed governance reviews. Calendar-only failures would turn red while the project is idle.
Consequences: `CURRENT_STATE.md` records `Last meta-review: T-### on YYYY-MM-DD.` Context hygiene fails when the marker is missing or 10+ completed tasks behind the latest completed task. Weekly cadence remains a human reminder in `META_REVIEW_TEMPLATE.md`.
Linked files: docs/00_memory/CURRENT_STATE.md, docs/06_tasks/META_REVIEW_TEMPLATE.md, scripts/context-hygiene-check.mjs
```
