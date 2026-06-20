# Plan-First Protocol

## Purpose

Planning depth follows the selected execution mode.

Planning prevents context drift, broad refactors, and interrupted half-implemented tasks.

---

## Planning by Mode

- Quick Mode: a short inline plan is enough.
- Standard Mode: use the user's clear plan or a concise main-agent plan. Do not spawn `task_planner` by default.
- Deep Mode: write an explicit approved patch plan before implementation.

Use `task_planner` only when the request is ambiguous, too large, high-risk, or lacks an implementation plan. If the user supplied a clear plan, do not spawn it. After one failure or timeout, record it and continue with a smaller safe plan; do not retry in the same run.

Deep plan-first is required when the task:

- touches Supabase,
- changes product flow,
- changes navigation,
- changes authentication or permissions,
- affects booking, offer, request, profile, review, payment, or media upload flows,
- involves build failures with unclear cause or a large refactor,
- is requested after context compression or restart.

---

## Plan Format

For Deep Mode, write:

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

For Standard Mode, the main agent may approve a concise plan without subagents.

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
