# Code Review Fix Task Template

Use this template when a task starts from review findings rather than a new feature brief or screenshot. Keep the task bounded to the reviewed findings unless the user explicitly approves adjacent work.

Task ID: `<NEXT_TASK_ID>`

Mode: `Quick / Standard / Deep`

Date: `<YYYY-MM-DD>`

## User Request

Paste or summarize the user's request to fix code-review findings.

## Review Source

- Reviewer/source: `<person, tool, PR review, or user-provided review>`
- Reviewed branch/commit/scope: `<branch, commit, files, or unknown>`
- Review date: `<YYYY-MM-DD or unknown>`

## Primary Task

Fix only the accepted review findings listed below.

## Review Findings

| Finding ID | Priority | Finding | Evidence | Impact | Decision |
|---|---|---|---|---|---|
| `<P1-1>` | `P0 / P1 / P2 / P3` | `<short finding>` | `<file/line/review note>` | `<user or system impact>` | `fix / defer / reject with reason` |

Decision rules:

- `fix`: in scope for this task.
- `defer`: valid issue, but outside the approved scope or requires separate authorization.
- `reject with reason`: not a valid issue after code inspection; document why.

## Scope

In scope:

- Fix the findings marked `fix`.
- Preserve the existing product model, module boundaries, and repository/service ownership.
- Add or update targeted tests when behavior changes.

Out of scope:

- Adjacent features not required by the findings.
- Broad refactors.
- Remote writes, destructive database operations, or new dependencies unless explicitly approved.

## Fix Matrix

| Finding ID | Root Cause | Fix Summary | Primary Files | Tests/Checks | Status |
|---|---|---|---|---|---|
| `<P1-1>` | `<why it happened>` | `<what changed>` | `<files>` | `<validation>` | `pending / fixed / blocked` |

## Implementation Plan

1. Reproduce or write a focused failing check for each fixable behavior when practical.
2. Patch the smallest code path that owns the behavior.
3. Update contracts, docs, migrations, or memory only when the fix changes durable state.
4. Run the selected validation plan once by mode.
5. Record any skipped or blocked validation explicitly.

## Validation Plan

- `<targeted test or check>`
- `<build/lint/diff check>`
- `<simulator launch if app/UI-visible>`

Stop on the first required validation failure unless the user approves a follow-up.

## Remote Or External Actions

Record anything that would require explicit approval:

- Supabase remote migration apply: `yes/no`
- Remote data writes: `yes/no`
- Git commit/push/PR: `yes/no`
- Third-party service changes: `yes/no`

Approval status:

- `<approved / not approved / not needed>`

## Closeout

Status: `pending / completed / blocked`

Review finding outcomes:

| Finding ID | Outcome | Evidence |
|---|---|---|
| `<P1-1>` | `fixed / deferred / rejected / blocked` | `<files, tests, notes>` |

Changed files:

- pending

Validation:

- pending

Skipped or blocked checks:

- pending

Risks:

- pending

Next:

- pending
