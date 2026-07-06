# Subagent Dispatch Protocol

## Purpose

This protocol tells the main Codex agent how to assign work to subagents and how to read their output.

---

## Dispatch Threshold

Quick Mode uses no subagents by default. Standard and Deep Mode dispatch only agents whose output will change the implementation or validation decision.

When dispatching, create:

```text
docs/05_workflow/agent_reports/<TASK_ID>/
```

Then create:

```text
00-task-intake.md
```

The task intake must define:

1. task ID,
2. user objective,
3. primary task,
4. explicit out-of-scope items,
5. expected validation,
6. stop condition.

---

## Standard Dispatch Prompt

Use this pattern when spawning a subagent:

```text
You are <agent_name>.

Task ID: <TASK_ID>

Primary task:
<one clear task>

Scope:
<allowed scope>

Out of scope:
<forbidden scope>

Read:
<minimum files to read>

Write report to:
docs/05_workflow/agent_reports/<TASK_ID>/<number>-<agent-name>.md

Return a concise summary to the main agent.
Do not do anything outside your role.
```

---

## Selection Rules

- `context_librarian`: only when relevant context is unclear.
- `ios_code_mapper`: only when iOS ownership/data flow is unclear.
- `supabase_contract_auditor`: only when backend impact exists or is uncertain.
- `task_planner`: only for ambiguous, oversized, high-risk, or unplanned work; never when the user supplied a clear plan.
- `implementation_worker`: at most one per task.
- `build_validator`: one budgeted validation phase.
- `final_reviewer`: optional, current diff only.

If `task_planner` fails or times out once, write one failure note and continue with a smaller safe plan. Do not retry it in the same run.

## Report File Rule

Every dispatched subagent must write a report file.

Reports must be short, structured, and no more than 30 lines by default.

Subagent reports are durable handoff artifacts, not essays.

---

## Main Agent Readback Rule

Read only reports produced for the current task and needed for the next decision. Do not load unused or historical reports by default.

```text
docs/05_workflow/agent_reports/<TASK_ID>/
```

The main agent must not rely only on chat summaries.

---

## Conflict Handling

If subagents disagree:

1. identify the conflict,
2. prefer repository source over memory,
3. prefer safer architecture over faster implementation,
4. if backend contract is involved, require explicit Supabase validation,
5. if still uncertain, produce a smaller plan that avoids the uncertain area.

---

## Failure Handling

If a subagent fails or cannot access a tool:

1. write a failure note in its report file if possible,
2. continue with a smaller plan if safe,
3. do not pretend the missing report exists,
4. include the failure in the final run report.
