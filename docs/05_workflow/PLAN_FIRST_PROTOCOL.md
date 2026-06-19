# Plan-First Protocol

## Purpose

This project requires planning before implementation for any non-trivial change.

Planning prevents context drift, broad refactors, and interrupted half-implemented tasks.

---

## When Plan-First Is Required

Plan-first is required when the task:

- touches more than one source file,
- touches Supabase,
- changes product flow,
- changes navigation,
- changes authentication or permissions,
- affects booking, offer, request, profile, review, payment, or media upload flows,
- involves build failures with unclear cause,
- is requested after context compression or restart.

---

## Plan Format

Before implementation, write:

```text
docs/05_workflow/agent_reports/<TASK_ID>/05-approved-patch-plan.md
```

Use this format:

```md
# Approved Patch Plan

## Task ID

...

## Primary Objective

...

## Out of Scope

...

## Files Allowed to Edit

- ...

## Files Not Allowed to Edit

- ...

## Implementation Steps

1. ...
2. ...
3. ...

## Validation Steps

1. ...
2. ...

## Stop Condition

...

## Risk Level

low / medium / high
```

---

## Plan Size Limit

The implementation plan must fit one Codex run.

If the plan is too large, split it into smaller task files under:

```text
docs/06_tasks/
```

Do not start implementation until the first task is small enough.

---

## Plan Approval

For normal runs, the main agent may approve its own plan after reading subagent reports.

For high-risk runs, the main agent must stop and ask the user before implementation.

High-risk means:

- database schema change,
- RLS policy change,
- auth flow change,
- destructive migration,
- large refactor,
- dependency replacement,
- conflicting product requirements,
- unclear source of truth.
