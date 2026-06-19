# AGENTS.md

## Project Mission

This repository is an iOS app project. Codex is the primary implementation agent.

The app should be built through small, verifiable tasks. Each Codex run must complete exactly one major task unless the user explicitly authorizes a broader run.

## Operating Principles

1. Single major task per run.
2. Read only the context needed for the task.
3. Preserve existing user work.
4. Prefer small patches over broad rewrites.
5. Use scripts for build/test checks instead of inventing commands.
6. Update project memory after every meaningful change.
7. Do not continue to the next task without user instruction.
8. If context appears stale or compressed, use `docs/00_memory/COMPRESSION_RECOVERY.md`.

## Required Startup Sequence for Every Codex Run

At the start of each run:

1. Read this `AGENTS.md`.
2. Read `docs/00_memory/PROJECT_MEMORY.md`.
3. Read `docs/00_memory/CURRENT_STATE.md`.
4. Read the active task file from `docs/06_tasks/`.
5. Read only the feature-specific docs linked from `docs/00_memory/FEATURE_INDEX.md`.
6. Check available Superpowers/plugin capabilities and use relevant ones.
7. Produce a short task plan before editing files.

## Required Completion Sequence for Every Codex Run

Before finishing:

1. Run relevant checks:
   - iOS task: `./scripts/ios-build.sh`
   - Test task: `./scripts/ios-test.sh`
   - Supabase task: `./scripts/supabase-check.sh`
   - General task: `./scripts/preflight.sh`
2. Update memory files:
   - `docs/00_memory/CURRENT_STATE.md`
   - `docs/00_memory/FEATURE_INDEX.md` if files or features changed
   - `docs/00_memory/WORKLOG.md`
   - `docs/00_memory/DECISION_LOG.md` if a design/architecture decision was made
3. Report:
   - Files changed
   - Behavior changed
   - Checks run and results
   - Risks
   - Recommended next task

## Context Budget Rules

Do not read the whole repository by default.

Use this order:
1. Memory index
2. Active task file
3. Relevant architecture/product/backend docs
4. Specific source files
5. Search only when necessary

Avoid:
- Loading unrelated screens
- Loading old generated logs
- Loading build artifacts
- Re-reading files already summarized in memory
- Continuing based on conversation memory alone

## Project Memory System

Long-term project memory lives in:

- `docs/00_memory/PROJECT_MEMORY.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/DECISION_LOG.md`
- `docs/00_memory/WORKLOG.md`
- `docs/00_memory/COMPRESSION_RECOVERY.md`

These files are the durable source of truth when conversation context is compressed, lost, or restarted.

## Agent Chain Model

Use serial role-based agents, not parallel uncontrolled edits.

The normal chain is:

1. Main Orchestrator
2. Context Librarian
3. Specialist Agent for the current task
4. Build/Test Agent
5. Documentation Scribe

Role cards are stored in `.codex/agents/`.

If the runtime supports native subagents, use the appropriate role card. If it does not, simulate the role by following the role card in the current Codex session or ask the user to start a separate Codex session with that role card.

## Tool Rules

Use MCP/tools only when they reduce risk or verify reality.

- Xcode/build tools: build, test, simulator checks.
- Supabase tools: schema inspection, migration validation, RLS/RPC verification.
- GitHub tools: issue/PR reading, branch status, diff review.
- Superpowers: planning, task decomposition, context compression recovery, code navigation, and structured verification when available.

Never use tools to make destructive remote changes without explicit user permission.

## Supabase Safety Rules

Unless explicitly authorized by the user:

- Do not reset remote databases.
- Do not repair migrations.
- Do not delete tables, buckets, policies, or functions.
- Do not bypass RLS.
- Do not embed service-role keys in app code.
- Do not invent schema facts; inspect or read migrations first.
- Do not create client-side fake success for production backend operations.

## iOS Safety Rules

- Keep SwiftUI views thin.
- Keep business logic outside views.
- Use repository/service boundaries.
- Preserve local demo mode if it exists.
- Surface errors to users.
- Avoid silent failures.
- Avoid new dependencies unless the user approves.
- Prefer typed models and explicit state transitions.

## Git Rules

- Check `git status` before editing.
- Do not overwrite user changes.
- Do not commit unless explicitly asked.
- Do not push unless explicitly asked.
- Keep changes scoped to one task.
- If interrupted, leave a handoff note in `docs/06_tasks/HANDOFF_TEMPLATE.md` format.

## Stop Conditions

Stop and report instead of improvising when:

- The active task is ambiguous.
- Required schema is unknown and cannot be safely inspected.
- Build fails after two targeted repair attempts.
- A destructive operation appears necessary.
- A file has user changes that conflict with the planned edit.
- The task grows beyond the original scope.
- The repository state differs significantly from memory docs.

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
