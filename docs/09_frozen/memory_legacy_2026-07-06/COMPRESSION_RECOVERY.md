# Compression Recovery Protocol

If conversation context is compressed, stale, or missing:

1. Stop relying on conversation memory.
2. Read `AGENTS.md`.
3. Read `CURRENT_STATE.md`.
4. Read the active task file, if provided.
5. Run `git status --short` and `git diff --stat`.
6. Identify the smallest safe next step.
7. Continue only when the task boundary is clear.

Do not load the whole repository or reconstruct archived subagent reports.
