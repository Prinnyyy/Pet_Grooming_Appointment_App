# Agent Team Workflow

## Purpose

This workflow defines how Codex should use the project agent team.

The system is intentionally lightweight. Subagents are used to isolate context-heavy investigation, not to create a large autonomous organization.

---

## Core Principles

1. One primary task per Codex run.
2. Read durable memory before reading broad source areas.
3. Use read-only agents for investigation.
4. Use one implementation worker for code changes.
5. Validate through scripts.
6. Review final diff.
7. Update durable memory.
8. Stop.

---

## Default Flow

```text
Task intake
  ↓
Scope check
  ↓
Context gathering
  ↓
Task planning
  ↓
Code mapping
  ↓
Backend contract audit when needed
  ↓
Approved patch plan
  ↓
Single implementation phase
  ↓
Build/test validation
  ↓
Final diff review
  ↓
Memory update
  ↓
Final report
```

---

## When to Use Subagents

Use subagents when:

- the task touches multiple files,
- source ownership is unclear,
- backend contract may be involved,
- build/test output may be noisy,
- the task is likely to consume too much main context,
- the user asks for planning before execution,
- a previous task was interrupted.

Do not use subagents when:

- the task changes only one obvious line,
- the change is documentation-only and local,
- the user asks for a quick answer,
- the cost of delegation exceeds the task complexity.

---

## Parallelism Rule

Parallelism is allowed only for read-only investigation.

Allowed:

```text
context_librarian + ios_code_mapper
context_librarian + supabase_contract_auditor
build_validator + final_reviewer only after implementation is complete and diff is stable
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

1. the approved patch plan was followed,
2. build/test validation was attempted or explicitly skipped with reason,
3. final review completed,
4. durable memory updated,
5. final run report written.
