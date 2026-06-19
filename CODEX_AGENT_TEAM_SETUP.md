# CODEX_AGENT_TEAM_SETUP.md

## Purpose

This document is the second-stage workspace setup instruction for Codex.

The first initialization task has already created the base project documentation, memory structure, workflow folders, and initial scripts. This task extends that environment with a lightweight Codex agent team and serial subagent workflow.

This is an environment setup task only.

Codex must not implement app features in this run.

---

## Operating Mode

Codex must treat this run as:

```text
Task type: workspace / agent-team setup
Implementation scope: documentation and Codex configuration only
Application feature work: forbidden
Supabase schema work: forbidden
Swift source code changes: forbidden unless required only to fix broken script paths, and only after asking
Git commit: forbidden unless explicitly requested by the user
```

Primary goal:

```text
Create a lightweight, stable, serial Codex agent-team framework that helps future Codex runs:
1. plan one task at a time,
2. delegate focused investigation to subagents,
3. keep the main agent context clean,
4. write durable report files,
5. recover from context compression or interrupted sessions,
6. use Superpowers when useful without depending on it,
7. use Xcode, Supabase, GitHub, and MCP tools safely.
```

---

## Non-Negotiable Rules

1. Do not implement any iOS app feature.
2. Do not modify Swift source code for product behavior.
3. Do not create Supabase migrations.
4. Do not run remote Supabase commands.
5. Do not run destructive Git commands.
6. Do not overwrite existing project memory.
7. If a target file already exists, preserve useful existing content and merge carefully.
8. Keep this framework lightweight. Avoid creating excessive agents, excessive hooks, or overly complex automation.
9. Every future task must have exactly one primary objective.
10. Long-term project memory must live in repository files, not in the chat context.

---

## Expected Existing Structure

The previous initialization task should have created a structure similar to this:

```text
AGENTS.md
.codex/
docs/
  00_memory/
  01_product/
  02_architecture/
  03_backend/
  04_ios/
  05_workflow/
  06_tasks/
  07_decisions/
scripts/
```

If some folders do not exist, create them.

If existing files have different names, do not delete them. Add missing files and update the index documents.

---

## Files and Folders to Create or Update

Create or update the following:

```text
.codex/
  config.toml
  agents/
    context-librarian.toml
    task-planner.toml
    ios-code-mapper.toml
    supabase-contract-auditor.toml
    implementation-worker.toml
    build-validator.toml
    final-reviewer.toml

docs/
  00_memory/
    AGENT_TEAM_INDEX.md
    CONTEXT_RECOVERY_PROTOCOL.md

  05_workflow/
    AGENT_TEAM_WORKFLOW.md
    SUBAGENT_DISPATCH_PROTOCOL.md
    PLAN_FIRST_PROTOCOL.md
    TOOL_USAGE_POLICY.md
    SUPERPOWERS_USAGE_POLICY.md
    MCP_USAGE_POLICY.md
    INTERRUPTION_RECOVERY.md
    AGENT_REPORT_TEMPLATE.md
    TASK_PLAN_TEMPLATE.md
    FINAL_RUN_REPORT_TEMPLATE.md
    agent_reports/
      .gitkeep

  06_tasks/
    TASK_INTAKE_TEMPLATE.md
    TASK_EXECUTION_TEMPLATE.md
    PLAN_REVIEW_TEMPLATE.md

scripts/
  agent-preflight.sh
  task-start.sh
  task-finish.sh
```

Also update `AGENTS.md` with a short section pointing to the new agent team workflow.

Do not duplicate large content inside `AGENTS.md`. It should remain concise and link to the detailed workflow documents.

---

# Part 1 — Update `.codex/config.toml`

Open `.codex/config.toml`.

If it does not exist, create it.

Merge the following configuration carefully. Do not remove existing valid settings unless they clearly conflict with these rules.

```toml
# Codex project configuration.
# Keep this file conservative. Most task-specific behavior should live in AGENTS.md and docs/05_workflow.

approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = false
writable_roots = ["."]

[agents]
# Lightweight subagent team.
# Keep parallelism limited to avoid token waste and unstable coordination.
max_threads = 4
max_depth = 1
job_max_runtime_seconds = 1200
```

If the project already has different `approval_policy`, `sandbox_mode`, or `[agents]` values, do not blindly overwrite them. Instead:

1. keep the safer value,
2. document any conflict in `docs/00_memory/AGENT_TEAM_INDEX.md`,
3. report it at the end.

---

# Part 2 — Create Custom Agent Definitions

Create `.codex/agents/` if missing.

Each custom agent below must be created as a `.toml` file.

Keep these agents minimal. The goal is not to create a large organization. The goal is to isolate noisy work from the main Codex context.

---

## 2.1 `.codex/agents/context-librarian.toml`

```toml
name = "context_librarian"
description = "Read-only agent that finds the minimum durable project context needed for one task."

model_reasoning_effort = "medium"
sandbox_mode = "read-only"

developer_instructions = """
You are the Context Librarian for this iOS app project.

Your purpose:
- Find the minimum durable project context required for the current task.
- Reduce main-agent context load.
- Prefer repository memory files over chat history.

Read in this priority order:
1. AGENTS.md
2. docs/00_memory/PROJECT_MEMORY.md
3. docs/00_memory/CURRENT_STATE.md
4. docs/00_memory/FEATURE_INDEX.md
5. docs/00_memory/AGENT_TEAM_INDEX.md
6. docs/07_decisions/DECISION_LOG.md
7. task-specific files under docs/06_tasks

Rules:
- Do not edit files.
- Do not inspect the entire codebase unless required.
- Do not propose broad refactors.
- Do not implement code.
- Return only task-relevant context.

Required report format:
1. Task understanding
2. Required memory files
3. Required product / architecture docs
4. Relevant decisions
5. Likely source areas
6. Context risks
7. Recommended next agent
"""
```

---

## 2.2 `.codex/agents/task-planner.toml`

```toml
name = "task_planner"
description = "Read-only planning agent that converts one primary task into a small, serial execution plan."

model_reasoning_effort = "high"
sandbox_mode = "read-only"

developer_instructions = """
You are the Task Planner for this iOS app project.

Your purpose:
- Convert a user-provided objective into one small, executable plan.
- Ensure the run has exactly one primary task.
- Split the work into investigation, implementation, validation, and memory update phases.
- Keep the plan lightweight and executable within one Codex run.

Rules:
- Do not edit files.
- Do not implement code.
- Do not expand the task into adjacent features.
- If the user request contains multiple major tasks, identify the first safe task and defer the rest.
- Prefer serial execution over parallel implementation.
- Use read-only subagents for investigation.
- Use only one implementation worker.

Required report format:
1. Primary task
2. Out of scope
3. Required subagents
4. Files likely involved
5. Implementation sequence
6. Validation sequence
7. Stop condition
8. Risk level: low / medium / high
"""
```

---

## 2.3 `.codex/agents/ios-code-mapper.toml`

```toml
name = "ios_code_mapper"
description = "Read-only Swift/iOS code mapper that identifies relevant app files and data flow."

model_reasoning_effort = "medium"
sandbox_mode = "read-only"

developer_instructions = """
You are the iOS Code Mapper for this SwiftUI app.

Your purpose:
- Map the smallest relevant iOS source area for one task.
- Identify SwiftUI views, view models, repositories, models, services, and app entry points involved.
- Prevent the implementation agent from reading or editing unrelated areas.

Rules:
- Do not edit files.
- Do not run destructive commands.
- Do not scan the entire codebase if targeted search is enough.
- Do not suggest large rewrites unless the current task cannot be completed safely without them.
- Prefer existing architecture over new abstractions.

Required report format:
1. Entry points
2. UI state ownership
3. Data flow
4. Repository/service boundaries
5. Files likely to edit
6. Files that should not be touched
7. Likely regression risks
"""
```

---

## 2.4 `.codex/agents/supabase-contract-auditor.toml`

```toml
name = "supabase_contract_auditor"
description = "Read-only Supabase auditor for schema, RPC, RLS, storage, and migration risks."

model_reasoning_effort = "high"
sandbox_mode = "read-only"

developer_instructions = """
You are the Supabase Contract Auditor for this iOS app project.

Your purpose:
- Protect database contract integrity.
- Verify whether a task touches Supabase schema, RPCs, RLS policies, storage buckets, auth assumptions, or migrations.
- Prevent accidental client-side bypass of server-side business rules.

Rules:
- Do not edit migrations.
- Do not create migrations.
- Do not run remote Supabase commands.
- Do not weaken RLS.
- Do not recommend direct client writes for protected business mutations.
- Treat RPC and RLS boundaries as high-risk.
- If the task does not touch Supabase, say so clearly and keep the report short.

Required report format:
1. Backend impact: yes / no / uncertain
2. Tables involved
3. RPCs involved
4. RLS assumptions
5. Storage assumptions
6. Migration impact
7. Forbidden operations
8. Required validation
"""
```

---

## 2.5 `.codex/agents/implementation-worker.toml`

```toml
name = "implementation_worker"
description = "Single-task implementation agent that applies only an approved patch plan."

model_reasoning_effort = "medium"
sandbox_mode = "workspace-write"

developer_instructions = """
You are the Implementation Worker for this iOS app project.

Your purpose:
- Apply one approved patch plan.
- Keep implementation focused, small, and reversible.
- Avoid context expansion.

Rules:
- Implement only the approved plan.
- Do not perform broad refactors.
- Do not start adjacent features.
- Do not create new dependencies unless explicitly approved.
- Do not change Supabase migrations unless the approved plan explicitly requires it.
- Do not alter project memory except implementation notes requested by the main agent.
- Preserve local demo mode if it exists.
- Preserve Supabase mode if it exists.
- If the approved plan is insufficient or unsafe, stop and report the blocker instead of improvising.

Required report format:
1. Files changed
2. Behavior changed
3. Assumptions made
4. Validation performed
5. Remaining risks
6. Follow-up needed
"""
```

---

## 2.6 `.codex/agents/build-validator.toml`

```toml
name = "build_validator"
description = "Validation agent that runs build/test scripts and summarizes failures without broad patching."

model_reasoning_effort = "medium"
sandbox_mode = "workspace-write"

developer_instructions = """
You are the Build Validator for this iOS app project.

Your purpose:
- Run the project's approved validation scripts.
- Summarize failures clearly.
- Avoid turning validation into a second implementation phase.

Rules:
- Prefer scripts over manually invented commands.
- Use scripts/agent-preflight.sh, scripts/ios-build.sh, scripts/ios-test.sh, or other documented scripts if present.
- Do not patch code unless explicitly instructed by the main agent.
- If build output is long, summarize the first real compiler error and likely owning file.
- Distinguish between environment failure and code failure.
- Do not run remote destructive commands.

Required report format:
1. Commands run
2. Result: pass / fail / not run
3. First real error
4. Likely owner file
5. Environment issues
6. Recommended next action
"""
```

---

## 2.7 `.codex/agents/final-reviewer.toml`

```toml
name = "final_reviewer"
description = "Read-only final reviewer that checks the task diff for regressions and scope violations."

model_reasoning_effort = "high"
sandbox_mode = "read-only"

developer_instructions = """
You are the Final Reviewer for this iOS app project.

Your purpose:
- Review only the final diff for the current task.
- Identify blocking issues before the main agent reports completion.
- Protect architecture, product flow, backend contract, and validation integrity.

Rules:
- Do not edit files.
- Do not review unrelated historical code unless needed to understand the diff.
- Do not request style-only changes unless they hide correctness risk.
- Do not expand scope.
- Focus on task correctness, regressions, boundaries, and validation.

Required report format:
1. Scope check
2. Blocking issues
3. Non-blocking risks
4. Architecture concerns
5. Backend contract concerns
6. Validation concerns
7. Safe-to-commit verdict: yes / no / conditional
"""
```

---

# Part 3 — Update `AGENTS.md`

Open `AGENTS.md`.

Add a concise section similar to the following. Do not paste all agent definitions into `AGENTS.md`.

```md
## Codex Agent Team Workflow

This project uses a lightweight Codex agent-team workflow for complex tasks.

Default pattern:
1. Main Codex agent receives one primary task.
2. Main agent checks the project memory and task scope.
3. Main agent may spawn read-only subagents for context, code mapping, planning, and backend contract review.
4. Only one implementation worker may edit code for a task.
5. Build validation and final review happen after implementation.
6. Main agent updates durable memory files at the end of the run.

Detailed protocols:
- docs/05_workflow/AGENT_TEAM_WORKFLOW.md
- docs/05_workflow/SUBAGENT_DISPATCH_PROTOCOL.md
- docs/05_workflow/PLAN_FIRST_PROTOCOL.md
- docs/05_workflow/TOOL_USAGE_POLICY.md
- docs/05_workflow/SUPERPOWERS_USAGE_POLICY.md
- docs/05_workflow/INTERRUPTION_RECOVERY.md

Hard rule:
Every Codex run must complete at most one primary task.
```

---

# Part 4 — Create Agent Team Memory Index

Create or update `docs/00_memory/AGENT_TEAM_INDEX.md`.

```md
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
```

---

# Part 5 — Create Context Recovery Protocol

Create or update `docs/00_memory/CONTEXT_RECOVERY_PROTOCOL.md`.

```md
# Context Recovery Protocol

## Purpose

This protocol is used when Codex context is compressed, lost, interrupted, or restarted.

Durable repository memory is the source of truth.

---

## Recovery Order

When starting or resuming a task, read these files first:

1. `AGENTS.md`
2. `docs/00_memory/PROJECT_MEMORY.md`
3. `docs/00_memory/CURRENT_STATE.md`
4. `docs/00_memory/AGENT_TEAM_INDEX.md`
5. `docs/00_memory/FEATURE_INDEX.md`
6. `docs/07_decisions/DECISION_LOG.md`
7. Active task file under `docs/06_tasks/`
8. Existing reports under `docs/05_workflow/agent_reports/<TASK_ID>/`

Do not read the whole codebase before checking these files.

---

## Interrupted Task Recovery

If a task was interrupted:

1. Find the latest task ID in `docs/05_workflow/agent_reports/`.
2. Read `00-task-intake.md` and `09-final-run-report.md` if present.
3. Check Git status.
4. Check Git diff.
5. Determine whether the previous run:
   - did not start implementation,
   - partially changed files,
   - completed implementation but did not validate,
   - completed validation but did not update memory,
   - completed fully.
6. Continue from the safest next step.
7. Do not assume completion without validating the diff and build state.

---

## Context Compression Safety

If the main agent notices that context may be stale or compressed:

1. Stop implementation.
2. Re-read this recovery protocol.
3. Re-read the active task reports.
4. Re-state the current task, scope, and stop condition.
5. Continue only if the next action is clear.

---

## Durable Memory Rule

Anything important for future runs must be written to repository memory, not left only in chat.

Minimum memory updates after each meaningful task:

- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `docs/07_decisions/DECISION_LOG.md` if a durable architecture/product decision changed
```

---

# Part 6 — Create Main Workflow Documents

Create or update `docs/05_workflow/AGENT_TEAM_WORKFLOW.md`.

```md
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
```

---

## `docs/05_workflow/SUBAGENT_DISPATCH_PROTOCOL.md`

```md
# Subagent Dispatch Protocol

## Purpose

This protocol tells the main Codex agent how to assign work to subagents and how to read their output.

---

## Dispatch Requirements

For every non-trivial task, the main agent must create:

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

## Report File Rule

Every dispatched subagent must write a report file.

Reports must be short and structured.

Subagent reports are durable handoff artifacts, not essays.

---

## Main Agent Readback Rule

Before creating an implementation plan, the main agent must read all report files in:

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
```

---

## `docs/05_workflow/PLAN_FIRST_PROTOCOL.md`

```md
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
```

---

## `docs/05_workflow/TOOL_USAGE_POLICY.md`

```md
# Tool Usage Policy

## Purpose

This policy defines how Codex should use local tools, scripts, Xcode, Supabase, GitHub, and MCP tools.

---

## General Tool Rules

1. Prefer existing project scripts over invented shell commands.
2. Prefer read-only commands during planning.
3. Use write commands only during implementation.
4. Avoid destructive commands.
5. Do not use network access unless the task explicitly requires it and the user approves.
6. Do not read secrets.
7. Do not log secrets.
8. Document any command failure in the agent report.

---

## Xcode / iOS Rules

Prefer scripts:

```text
scripts/ios-build.sh
scripts/ios-test.sh
scripts/agent-preflight.sh
```

If Xcode MCP is available, it may be used for:

- listing schemes,
- selecting simulator,
- building,
- testing,
- reading structured build errors.

Rules:

- Do not manually invent new build commands if scripts exist.
- Do not change project signing settings unless explicitly requested.
- Do not modify Xcode project files casually.
- If build fails due to environment or simulator availability, report it as environment failure, not code failure.

---

## Supabase Rules

During planning:

- read local docs,
- read local migrations,
- inspect repository code paths,
- avoid remote commands.

During implementation:

- do not create migrations unless explicitly planned,
- do not weaken RLS,
- do not bypass RPC for protected mutations,
- do not fake Supabase success in app code.

Allowed by default:

```text
read local files
inspect migration SQL
inspect repository code
run local non-destructive validation scripts
```

Not allowed by default:

```text
supabase db reset
supabase migration repair
remote production writes
manual production schema edits
weakening RLS
logging service role keys
```

---

## Git / GitHub Rules

Allowed by default:

```text
git status
git diff
git log --oneline
git branch --show-current
```

Requires explicit user approval:

```text
git commit
git push
git reset
git rebase
gh pr create
gh pr merge
```

If GitHub MCP is available, it may be used for:

- reading issues,
- reading pull requests,
- summarizing diffs,
- checking CI status.

Do not create PRs or push branches unless the user explicitly requests it.

---

## File Editing Rules

Implementation worker may edit only files listed in the approved patch plan.

If a new file must be added, the implementation worker must state why.

If a file outside the approved list must be edited, stop and update the plan first.
```

---

## `docs/05_workflow/SUPERPOWERS_USAGE_POLICY.md`

```md
# Superpowers Usage Policy

## Purpose

Superpowers may provide useful workflows, skills, commands, or project guidance.

This project should use Superpowers when helpful, but must not depend on Superpowers being available.

---

## Required Behavior

At the start of every non-trivial Codex run:

1. Check whether Superpowers is installed and available.
2. Check whether it provides a relevant capability for the task.
3. Use the relevant capability if it improves planning, navigation, validation, or review.
4. Continue without blocking if Superpowers is unavailable.
5. Report which Superpowers capability was used, or state that none was used.

---

## Suitable Uses

Superpowers is suitable for:

- task decomposition,
- planning,
- codebase navigation,
- context management,
- validation workflows,
- review workflows,
- reusable project procedures.

---

## Unsuitable Uses

Do not use Superpowers to:

- bypass project rules,
- skip durable report files,
- replace approved validation scripts,
- perform broad refactors without plan,
- access secrets,
- run destructive operations.

---

## Reporting Format

Each final run report must include:

```md
## Superpowers Usage

- Available: yes / no / unknown
- Capability used: ...
- Purpose: ...
- Result: ...
```

If no capability was used:

```md
## Superpowers Usage

- Available: unknown
- Capability used: none
- Reason: no relevant capability was required for this task
```
```

---

## `docs/05_workflow/MCP_USAGE_POLICY.md`

```md
# MCP Usage Policy

## Purpose

This file defines safe use of MCP tools for the project.

MCP tools are useful but can expand scope quickly. Use them only when they reduce uncertainty or improve validation.

---

## General Rules

1. Prefer local repository files first.
2. Use MCP tools only for task-relevant information.
3. Do not use MCP tools to browse unrelated context.
4. Do not use MCP write actions unless explicitly authorized.
5. If MCP output conflicts with repository files, identify the conflict and prefer repository source unless the repository is stale.

---

## Xcode MCP

Use when available for:

- discovering schemes,
- selecting simulators,
- running build/test,
- collecting structured build errors.

Do not use to alter signing, capabilities, entitlements, or project structure unless explicitly planned.

---

## Supabase MCP

Use when available for:

- reading local/remote schema metadata,
- checking table/RPC/policy existence,
- validating assumptions.

Do not use for:

- production writes,
- destructive schema changes,
- RLS weakening,
- migration repair,
- secret inspection.

Remote Supabase changes require explicit user approval.

---

## GitHub MCP

Use when available for:

- reading issues,
- reading PRs,
- reading CI status,
- summarizing remote diffs.

Do not use for:

- pushing branches,
- merging PRs,
- changing repository settings,
- modifying secrets,
- deleting branches.

---

## Escalation Rule

If an MCP tool is needed for a high-risk write action, stop and ask the user.
```

---

## `docs/05_workflow/INTERRUPTION_RECOVERY.md`

```md
# Interruption Recovery

## Purpose

This protocol reduces damage from Codex usage limits, interrupted runs, context compression, or accidental session closure.

---

## Before Starting Implementation

Every non-trivial task must have:

```text
docs/05_workflow/agent_reports/<TASK_ID>/00-task-intake.md
docs/05_workflow/agent_reports/<TASK_ID>/05-approved-patch-plan.md
```

If implementation is interrupted, these files define what the task was supposed to do.

---

## During Implementation

Implementation worker should keep changes small.

If the task has more than 5 likely files to edit, split it into smaller tasks unless the files are tightly coupled.

---

## After Interruption

On restart:

1. Read `docs/00_memory/CONTEXT_RECOVERY_PROTOCOL.md`.
2. Find the active task ID.
3. Read all report files for the active task.
4. Run `git status`.
5. Run `git diff`.
6. Determine whether changes are safe to continue.
7. Validate before making additional edits.

---

## Partial Change Handling

If partial implementation exists:

- do not continue blindly,
- compare diff against approved patch plan,
- revert only with explicit user approval,
- prefer completing the smallest safe validation step first.

---

## Stop Early Rule

If running out of time, token budget, or task clarity:

1. stop adding new changes,
2. write current status to the active report folder,
3. update `CURRENT_STATE.md` if appropriate,
4. report remaining work clearly.
```

---

# Part 7 — Create Templates

## `docs/05_workflow/AGENT_REPORT_TEMPLATE.md`

```md
# Agent Report Template

Task ID: `<TASK_ID>`

Agent: `<agent_name>`

Mode: `read-only / workspace-write`

Date: `<YYYY-MM-DD>`

---

## Summary

Briefly summarize the result in 3-6 lines.

---

## Files Inspected

- `path/to/file`

---

## Files Changed

- `path/to/file`
- None

---

## Findings

1. ...
2. ...
3. ...

---

## Risks

- ...

---

## Recommendation to Main Agent

State the next safe action.
```

---

## `docs/05_workflow/TASK_PLAN_TEMPLATE.md`

```md
# Task Plan

Task ID: `<TASK_ID>`

Date: `<YYYY-MM-DD>`

---

## Primary Objective

One task only.

---

## Out of Scope

- ...
- ...

---

## Required Agents

- `context_librarian`
- `task_planner`
- `ios_code_mapper`
- `supabase_contract_auditor` if needed
- `implementation_worker`
- `build_validator`
- `final_reviewer`

---

## Files Allowed to Edit

- ...

---

## Files Not Allowed to Edit

- ...

---

## Implementation Steps

1. ...
2. ...
3. ...

---

## Validation Steps

1. ...
2. ...

---

## Stop Condition

Stop after this specific result is achieved.

---

## Risk Level

`low / medium / high`
```

---

## `docs/05_workflow/FINAL_RUN_REPORT_TEMPLATE.md`

```md
# Final Run Report

Task ID: `<TASK_ID>`

Date: `<YYYY-MM-DD>`

---

## Primary Task

...

---

## Scope Completed

- ...

---

## Files Changed

- ...

---

## Validation

- Preflight: pass / fail / not run
- Build: pass / fail / not run
- Tests: pass / fail / not run

---

## Subagents Used

| Agent | Used | Report |
|---|---|---|
| context_librarian | yes/no | path |
| task_planner | yes/no | path |
| ios_code_mapper | yes/no | path |
| supabase_contract_auditor | yes/no | path |
| implementation_worker | yes/no | path |
| build_validator | yes/no | path |
| final_reviewer | yes/no | path |

---

## Superpowers Usage

- Available: yes / no / unknown
- Capability used: ...
- Purpose: ...
- Result: ...

---

## Final Reviewer Verdict

safe / conditional / unsafe

---

## Remaining Risks

- ...

---

## Next Recommended Task

Only one next task.
```

---

## `docs/06_tasks/TASK_INTAKE_TEMPLATE.md`

```md
# Task Intake

Task ID: `<TASK_ID>`

Date: `<YYYY-MM-DD>`

---

## User Request

Paste or summarize the user request.

---

## Primary Task

Define exactly one primary task.

---

## Out of Scope

- ...
- ...

---

## Expected Output

- ...

---

## Required Validation

- ...

---

## Risk Level

`low / medium / high`

---

## Stop Condition

Define where Codex must stop.
```

---

## `docs/06_tasks/TASK_EXECUTION_TEMPLATE.md`

```md
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
```

---

## `docs/06_tasks/PLAN_REVIEW_TEMPLATE.md`

```md
# Plan Review Template

Use this template before implementation when the user wants to review the plan.

---

## Plan Summary

...

---

## Task Boundary

Primary task:

...

Out of scope:

...

---

## Agent Assignments

| Phase | Agent | Purpose |
|---|---|---|
| Context | context_librarian | ... |
| Planning | task_planner | ... |
| Code map | ios_code_mapper | ... |
| Backend audit | supabase_contract_auditor | ... |
| Implementation | implementation_worker | ... |
| Validation | build_validator | ... |
| Review | final_reviewer | ... |

---

## Files Expected to Change

- ...

---

## Validation Expected

- ...

---

## Risk Assessment

`low / medium / high`

---

## User Decision Needed

Proceed / revise / split task
```

---

# Part 8 — Create Helper Scripts

Create scripts if missing. If similar scripts already exist, merge or leave existing scripts and add missing ones.

Make them executable if possible.

---

## `scripts/agent-preflight.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== Agent Preflight =="

echo "-- Required files --"
test -f AGENTS.md || { echo "Missing AGENTS.md"; exit 1; }
test -f docs/00_memory/AGENT_TEAM_INDEX.md || { echo "Missing AGENT_TEAM_INDEX.md"; exit 1; }
test -f docs/05_workflow/AGENT_TEAM_WORKFLOW.md || { echo "Missing AGENT_TEAM_WORKFLOW.md"; exit 1; }
test -f docs/05_workflow/SUBAGENT_DISPATCH_PROTOCOL.md || { echo "Missing SUBAGENT_DISPATCH_PROTOCOL.md"; exit 1; }
test -f docs/05_workflow/PLAN_FIRST_PROTOCOL.md || { echo "Missing PLAN_FIRST_PROTOCOL.md"; exit 1; }

echo "-- Codex agent definitions --"
test -d .codex/agents || { echo "Missing .codex/agents"; exit 1; }
ls .codex/agents/*.toml >/dev/null 2>&1 || { echo "No .codex/agents/*.toml files found"; exit 1; }

echo "-- Report folder --"
mkdir -p docs/05_workflow/agent_reports

echo "-- Git status --"
git status --short || true

echo "Agent preflight passed."
```

---

## `scripts/task-start.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

TASK_ID="${1:-}"

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: scripts/task-start.sh <TASK_ID>"
  exit 1
fi

REPORT_DIR="docs/05_workflow/agent_reports/$TASK_ID"

mkdir -p "$REPORT_DIR"

if [[ ! -f "$REPORT_DIR/00-task-intake.md" ]]; then
  cat > "$REPORT_DIR/00-task-intake.md" <<EOF
# Task Intake

Task ID: \`$TASK_ID\`

Date: $(date +%Y-%m-%d)

---

## User Request

TBD

---

## Primary Task

TBD

---

## Out of Scope

- TBD

---

## Expected Output

- TBD

---

## Required Validation

- TBD

---

## Stop Condition

TBD
EOF
fi

echo "Task report folder ready: $REPORT_DIR"
```

---

## `scripts/task-finish.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

TASK_ID="${1:-}"

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: scripts/task-finish.sh <TASK_ID>"
  exit 1
fi

REPORT_DIR="docs/05_workflow/agent_reports/$TASK_ID"

if [[ ! -d "$REPORT_DIR" ]]; then
  echo "Missing task report folder: $REPORT_DIR"
  exit 1
fi

echo "== Task Finish Check =="
echo "Task ID: $TASK_ID"

echo "-- Reports --"
find "$REPORT_DIR" -maxdepth 1 -type f -name "*.md" | sort

echo "-- Git status --"
git status --short || true

echo "-- Required final report --"
if [[ ! -f "$REPORT_DIR/09-final-run-report.md" ]]; then
  echo "Warning: missing $REPORT_DIR/09-final-run-report.md"
else
  echo "Final run report exists."
fi
```

---

# Part 9 — Final Verification

After creating/updating files:

1. Run:

```bash
chmod +x scripts/agent-preflight.sh scripts/task-start.sh scripts/task-finish.sh
```

2. Run:

```bash
scripts/agent-preflight.sh
```

3. Do not run app build unless existing initialization explicitly requires it. This task is not app implementation.

4. Write a setup report to:

```text
docs/05_workflow/agent_reports/SETUP-AGENT-TEAM/09-final-run-report.md
```

Use this format:

```md
# Final Run Report

Task ID: `SETUP-AGENT-TEAM`

## Primary Task

Set up lightweight Codex agent team and subagent workflow.

## Files Created or Updated

- ...

## Existing Files Preserved

- ...

## Config Conflicts

- none / ...

## Validation

- agent-preflight: pass / fail

## Superpowers Usage

- Available: yes / no / unknown
- Capability used: ...
- Result: ...

## Remaining Risks

- ...

## Next Recommended Task

Prepare the project implementation plan from the user's app project file.
```

---

# Part 10 — Final Response to User

When finished, report only:

1. files created or updated,
2. whether preflight passed,
3. any config conflicts,
4. next recommended Codex prompt.

Do not start implementation.

Do not create an app plan in this run.

Do not modify product features.

---

# Suggested Next User Prompt After This Setup

After this setup is complete, the user may provide the actual generated project plan and ask Codex to create a plan.

The next prompt should look like:

```text
Read AGENTS.md and the agent team workflow.

Task ID: PLAN-APP-FOUNDATION-001

Primary task:
Read the project plan I provide and create an implementation plan only.

Hard limits:
- Do not implement code.
- Do not create migrations.
- Do not modify Swift source files.
- Produce a staged plan with small tasks.
- Each task must have exactly one primary objective.
- Identify which subagents should be used for each stage.
- Keep the plan lightweight and suitable for interrupted Codex runs.

Use:
- docs/05_workflow/AGENT_TEAM_WORKFLOW.md
- docs/05_workflow/PLAN_FIRST_PROTOCOL.md
- docs/06_tasks/PLAN_REVIEW_TEMPLATE.md
- Superpowers if useful and available.

Output:
1. staged implementation roadmap,
2. first executable task,
3. required subagents,
4. validation strategy,
5. risks,
6. stop condition.
```
