# Serial Agent Chain

## Purpose

Use multiple focused agent roles without allowing uncontrolled parallel edits.

## Default Chain

```text
Main Orchestrator
↓
Context Librarian
↓
Specialist Agent
↓
Build/Test Agent
↓
Documentation Scribe
```

## Rules

- Only one specialist should edit code for a task.
- Subagents should handle simple, bounded work.
- Do not let multiple agents edit the same files simultaneously.
- Use fresh sessions for large context shifts.
- Use handoff notes between sessions.

## When to Start a Fresh Codex Session

Start fresh when:
- The previous session consumed too much context.
- A new specialist role is needed.
- The task is complete and a new task begins.
- The model seems to rely on stale assumptions.
- Build failures require isolated diagnosis.
