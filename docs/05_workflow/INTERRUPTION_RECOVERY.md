# Interruption Recovery

Use this procedure after an interrupted session or context loss.

1. Read `docs/00_memory/CURRENT_STATE.md`.
2. Read the active task file, if provided.
3. Run `git status --short`.
4. Run `git diff --stat`.
5. Identify partial changes and separate them from unrelated user work.
6. Choose the next smallest safe step.
7. Continue only when the scope and next step are clear.

Do not reconstruct archived subagent state, load old report chains, repeat completed validation automatically, or revert changes without explicit user approval.

If the next safe step is unclear, stop and ask the user.
