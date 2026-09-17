# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-07-09

```text
Decision ID: D-008
Date: 2026-07-08
Decision: Treat `main` commit `2fddf7b` as reviewed and superseded by this branch's governance architecture.
Context: The commit exists only on `main`/`origin/main`, is not an ancestor of `codex/pet-fit-structure-cleanup`, and resets docs to a T-049/T-050-era architecture.
Consequences: Do not merge `2fddf7b` into this branch. Future `main` reconciliation should carry this branch's governed docs forward or cherry-pick only explicitly reviewed non-stale changes.
Linked files: docs/05_workflow/GITHUB_RULES.md, docs/00_memory/CURRENT_STATE.md, docs/06_tasks/TASK_LEDGER.md
```
