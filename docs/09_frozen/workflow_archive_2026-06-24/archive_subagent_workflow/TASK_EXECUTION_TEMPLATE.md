# Task Execution Template

Use this template when giving a future task to Codex.

```text
Task ID: <TASK_ID>

Mode: Quick / Standard / Deep

Primary task:
<one clear task>

Hard limits:
- Complete only this one primary task.
- Do not start adjacent features.
- Do not perform broad refactors.
- Do not modify files outside the stated task scope or plan.
- Stop after final report.

Required workflow:
1. Read AGENTS.md.
2. Read CURRENT_STATE.md, TASK_LEDGER.md if present, and this active intake.
3. Read additional docs/source only when directly needed.
4. Check Superpowers; use at most one relevant capability unless Deep Mode.
5. Do not spawn subagents in Quick Mode by default. In Standard/Deep, justify each selected agent.
6. Do not use task_planner when this prompt already supplies a clear plan.
7. Implement only the stated task with one implementation worker at most.
8. Apply this mode's explicit validation budget and stop on the first real failure.
9. Keep subagent reports to 30 lines and the final report concise.
10. Update required durable state and stop.

Validation budget:
- <exact commands or "none required">

Selected subagents and justification:
- <none by default>
```
