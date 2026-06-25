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
| `task_planner` | read-only | Deep Mode or unclear/oversized/high-risk request without a clear plan | No |
| `ios_code_mapper` | read-only | Need to locate SwiftUI / iOS source areas | No |
| `supabase_contract_auditor` | read-only | Task may touch Supabase, auth, storage, RPC, RLS, or migrations | No |
| `implementation_worker` | workspace-write | Delegated implementation is clearly scoped | Yes |
| `build_validator` | workspace-write | Need build/test validation | No by default |
| `final_reviewer` | read-only | Need final diff review | No |

---

## Mode-Based Selection

| Mode | Default Agent Use |
|---|---|
| Quick | No subagents |
| Standard | Optional `context_librarian` and `ios_code_mapper`; one `implementation_worker`; one `build_validator`; optional current-diff `final_reviewer` |
| Deep | Add only justified `task_planner` or `supabase_contract_auditor`; still one implementation worker |

`task_planner` is not a default agent. Do not spawn it when the user supplied a clear plan. If it fails or times out once, record the failure and do not retry it in that run.

---

## Report Storage

Standard and Deep tasks may create a task report folder when durable handoff is useful:

```text
docs/05_workflow/agent_reports/<TASK_ID>/
```

Each dispatched agent writes only its own short report. Reports are limited to 30 lines by default. Quick Mode may omit intermediate reports.

Use only files for agents actually dispatched; do not create empty placeholders for the full chain.

```text
00-task-intake.md
09-final-run-report.md
```

---

## Stop Condition

After budgeted validation and required memory/report updates, stop.

Do not start the next feature.
Do not perform opportunistic cleanup.
Do not continue refactoring.
