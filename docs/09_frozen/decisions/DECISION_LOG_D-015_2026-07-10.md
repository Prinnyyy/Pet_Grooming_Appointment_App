# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-07-10

```text
Decision ID: D-015
Date: 2026-07-09
Decision: Replace the active Markdown 85% cleanup trigger with structural context-budget tooling.
Context: D-012 allowed a one-time total-limit increase only after repeated high-water reviews found no safe reduction path. T-181/T-182 showed the 85% warning had become a recurring closeout target instead of a useful signal, and the adopted redesign pairs the 36k limit with default per-file budgets, mechanical rotation, and a 95% structural-review warning.
Consequences: Context hygiene reports actual active Markdown percentage against 36k, fails only above the hard limit, applies a 650-word default to unlisted active Markdown, and checks fixed ledger/worklog/decision windows. `scripts/context-rotate.mjs` handles deterministic archive rotation; Batch B must align workflow text in a separate rule-change task.
Linked files: scripts/context-hygiene-check.mjs, scripts/context-hygiene-policy.mjs, scripts/context-rotate.mjs, tests/docs/
```
