# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-07-09

```text
Decision ID: D-009
Date: 2026-07-08
Decision: Record the T-163 through T-173 batch commits as a one-time historical exception.
Context: Commits `01c80e4` and `6d1da33` landed the docs-governance sequence in two user-authorized batches while the one-task-per-commit rule was being introduced and then hardened.
Consequences: Do not rewrite, amend, rebase, revert, or force-push those commits for formatting alone. From T-174 onward, commits must follow `T-xxx: <type>: <summary>` and should contain one primary task, including governance tasks.
Linked files: docs/05_workflow/GITHUB_RULES.md, docs/06_tasks/TASK_LEDGER.md
```
