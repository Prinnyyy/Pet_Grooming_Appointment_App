# Agent Team Index

## Purpose

This file is the durable index for the Codex agent-team workflow.

It tells future Codex runs which agents exist, when to use them, and where their reports should be stored.

This file must be kept short. Detailed instructions live in `docs/05_workflow/`.

---

## Active Agent Team

| Agent | Mode | Use When | Writes Code |
|---|---|---|---|
| `context_librarian` | read-only | Need project memory and relevant docs | No |
| `task_planner` | read-only | Need to convert user request into one executable task | No |
| `ios_code_mapper` | read-only | Need to locate SwiftUI / iOS source areas | No |
| `supabase_contract_auditor` | read-only | Task may touch Supabase, auth, storage, RPC, RLS, or migrations | No |
| `implementation_worker` | workspace-write | Approved patch plan exists | Yes |
| `build_validator` | workspace-write | Need build/test validation | No by default |
| `final_reviewer` | read-only | Need final diff review | No |

---

## Default Serial Workflow

```text
User task
  ↓
Main agent scope check
  ↓
context_librarian
  ↓
task_planner
  ↓
ios_code_mapper
  ↓
supabase_contract_auditor if backend impact exists or is uncertain
  ↓
Main agent creates approved patch plan
  ↓
implementation_worker
  ↓
build_validator
  ↓
final_reviewer
  ↓
Main agent updates durable memory
  ↓
Final report to user
```

---

## Lightweight Rule

Do not spawn every agent for every task.

Use this default:

| Task Type | Required Agents |
|---|---|
| Documentation-only | `context_librarian`, optional `task_planner` |
| Small UI copy/style change | no subagent or `ios_code_mapper` only |
| SwiftUI feature work | `context_librarian`, `task_planner`, `ios_code_mapper`, `implementation_worker`, `build_validator`, `final_reviewer` |
| Supabase/backend-related | add `supabase_contract_auditor` |
| Build failure debugging | `build_validator`, optional `ios_code_mapper` |
| Large refactor request | `context_librarian`, `task_planner`, `ios_code_mapper`, `final_reviewer`; implementation must be split into smaller tasks |

---

## Report Storage

Every non-trivial task must create:

```text
docs/05_workflow/agent_reports/<TASK_ID>/
```

Each subagent report should be saved there.

Recommended files:

```text
00-task-intake.md
01-context-librarian.md
02-task-planner.md
03-ios-code-mapper.md
04-supabase-contract-auditor.md
05-approved-patch-plan.md
06-implementation-worker.md
07-build-validator.md
08-final-reviewer.md
09-final-run-report.md
```

---

## Stop Condition

After final review and memory update, stop.

Do not start the next feature.
Do not perform opportunistic cleanup.
Do not continue refactoring.
