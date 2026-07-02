# Lightweight Codex Task Prompt Template

```text
Task ID: <TASK_ID>
Mode: Quick / Standard / Deep

Primary task:
<one clear task>

Hard limits:
- Complete only this one task.
- Do not start adjacent features.
- Do not perform broad refactors.
- Do not use subagents.
- Do not run more than one validation attempt unless approved.
- Do not commit.
- Do not push.

Required workflow:
1. Read only task-relevant context.
2. Write a short plan.
3. Implement only the approved scope.
4. Run the appropriate validation once.
5. Review current diff briefly.
6. Update memory only if project state changed.
7. Write a concise closeout before `/compact`.
8. Stop.
```
