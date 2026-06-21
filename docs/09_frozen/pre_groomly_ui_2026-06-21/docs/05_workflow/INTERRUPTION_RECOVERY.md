# Interruption Recovery

Use this procedure after an interrupted session or context loss.

1. Read `AGENTS.md`.
2. Read `docs/00_memory/CURRENT_STATE.md`.
3. Read `docs/06_tasks/TASK_LEDGER.md` if present.
4. Read the active task file, if provided.
5. Run `git status --short`.
6. Run `git diff --stat`.
7. Look for the latest task closeout, debug checkpoint, or handoff note.
8. Identify partial changes and separate them from unrelated user work.
9. Choose the next smallest safe step.
10. Continue only when the scope and next step are clear.

Do not reconstruct archived subagent state, load old report chains, repeat completed validation automatically, or revert changes without explicit user approval.

If recovery happens after `/compact`, trust checked-in state and task files over the compressed transcript. If the next safe step is unclear, stop and ask the user.
