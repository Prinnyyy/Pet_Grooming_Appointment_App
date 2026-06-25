# Agent Team Workflow

## Purpose

This workflow defines how Codex should use the project agent team.

The system is intentionally lightweight. Subagents are used to isolate context-heavy investigation, not to create a large autonomous organization.

---

## Core Principles

1. One primary task per Codex run.
2. Select Quick, Standard, or Deep Mode using `LIGHTWEIGHT_EXECUTION_POLICY.md`.
3. Read only the minimum startup context.
4. Delegate only when delegation reduces uncertainty.
5. Never use more than one implementation worker.
6. Stay within the mode's validation and report budget.
7. Stop after the task.

---

## Default Flows

```text
Quick: scope → edit → targeted check if needed → brief report
Standard: scope → optional context/code map → one implementation worker → one build validator → optional diff review → report
Deep: scope → explicit plan → justified specialist audit(s) → one implementation worker → explicit validation/review → report
```

---

## When to Use Subagents

Use subagents only when:

- source ownership is unclear,
- backend contract may be involved,
- validation output needs isolation,
- Deep Mode risk needs an independent audit,
- a previous task was interrupted.

Do not use subagents when:

- the task is Quick Mode,
- the user already supplied a clear plan and repository context,
- the user asks for a quick answer,
- the cost of delegation exceeds the task complexity.

---

## Parallelism Rule

Parallelism is allowed only for read-only investigation.

Read-only investigation may run in parallel when both agents are justified:

```text
context_librarian + ios_code_mapper
context_librarian + supabase_contract_auditor
```

Not allowed:

```text
two implementation workers editing code at the same time
implementation while planning is incomplete
backend migration work while product flow is uncertain
```

---

## Implementation Rule

Only `implementation_worker` may perform code changes during a delegated task.

The main agent may make small documentation updates at the end, but it must not become a second implementation agent.

---

## Initialization Rule

Initialization tasks do not use TDD RED/GREEN loops or extensive test suites. They may add a minimal smoke test and make one build attempt. On failure, report the first real error and stop unless the user authorizes a follow-up.

## Memory Update Rule

At the end of a meaningful task, update:

```text
docs/00_memory/CURRENT_STATE.md
docs/00_memory/WORKLOG.md
```

Update `docs/07_decisions/DECISION_LOG.md` only if a durable decision changed.

---

## Completion Rule

The task is not complete until:

1. the selected mode and scope were respected,
2. budgeted validation ran or was explicitly unnecessary,
3. required durable state was updated,
4. the concise final report was written.
