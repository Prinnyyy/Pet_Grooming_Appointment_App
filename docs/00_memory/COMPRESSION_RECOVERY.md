# Compression Recovery Protocol

Use this when conversation context is compressed, stale, missing, or contradictory.

## Recovery Steps

1. Stop relying on conversation memory.
2. Read `AGENTS.md`.
3. Read `PROJECT_MEMORY.md`.
4. Read `CURRENT_STATE.md`.
5. Read `FEATURE_INDEX.md`.
6. Read the active task file.
7. Use repository search only for files linked to the active task.
8. Produce a short recovered context summary.
9. Continue only if the task boundary is clear.

## Recovery Summary Template

```text
Recovered task:
Relevant docs:
Relevant source files:
Known constraints:
Unknowns:
Safe next action:
```

## Rules

- Do not infer current architecture from old conversation text.
- Do not load the whole repository.
- Do not continue if the active task is unknown.
- Ask for user direction if recovery cannot identify the task.
