# Context Recovery Protocol

Durable repository files are the source of truth when context is stale, compressed, interrupted, or restarted.

## Recovery Steps

1. Read `docs/00_memory/CURRENT_STATE.md`.
2. Read the active task file, if provided.
3. Run `git status --short`.
4. Run `git diff --stat`.
5. Identify partial changes that belong to the active task.
6. Determine the next smallest safe step.
7. Do not continue implementation until that step is clear.

Do not reconstruct old subagent state or read historical agent reports by default.
