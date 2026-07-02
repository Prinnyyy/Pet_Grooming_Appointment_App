# Subagent Rules

## Purpose

Subagents reduce main-agent context usage by handling small, bounded tasks.

## Good Subagent Tasks

- Summarize one feature area.
- Inspect one file group.
- Reproduce one bug.
- Check one backend contract.
- Run one build/test command and summarize error.
- Update documentation after a completed task.
- Map one screen's state/data dependencies.

## Bad Subagent Tasks

- Build the whole app.
- Redesign the architecture.
- Touch many unrelated modules.
- Make product decisions.
- Modify backend and UI at the same time.
- Continue automatically to the next task.

## Subagent Output Format

Every subagent must return:

```text
Task:
Files inspected:
Findings:
Files changed, if any:
Risks:
Recommended next action:
```

## Subagent Safety

- Subagents should be read-only unless the task explicitly allows edits.
- Subagents should not commit.
- Subagents should not push.
- Subagents should not modify secrets.
