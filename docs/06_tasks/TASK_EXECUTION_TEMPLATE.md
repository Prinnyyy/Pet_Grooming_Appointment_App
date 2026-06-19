# Task Execution Template

Use this template when giving a future task to Codex.

```text
Task ID: <TASK_ID>

Primary task:
<one clear task>

Hard limits:
- Complete only this one primary task.
- Do not start adjacent features.
- Do not perform broad refactors.
- Do not modify files outside the approved patch plan.
- Stop after final report.

Required workflow:
1. Read AGENTS.md.
2. Read docs/00_memory/AGENT_TEAM_INDEX.md.
3. Read docs/05_workflow/AGENT_TEAM_WORKFLOW.md.
4. Check Superpowers availability and use relevant capabilities if helpful.
5. Create docs/05_workflow/agent_reports/<TASK_ID>/00-task-intake.md.
6. Spawn only the required subagents for this task.
7. Each subagent must write a report file.
8. Read all subagent reports.
9. Create docs/05_workflow/agent_reports/<TASK_ID>/05-approved-patch-plan.md.
10. Implement only the approved plan.
11. Validate using project scripts.
12. Run final review.
13. Update durable memory.
14. Write final run report.
```
