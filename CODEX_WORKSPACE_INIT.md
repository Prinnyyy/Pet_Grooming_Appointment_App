# Codex Workspace Initialization Plan for an iOS App Project

> Purpose: Give this file to Codex as the first initialization task inside the project root. Codex must create the workspace documentation, memory index, workflow rules, agent role cards, and validation script stubs before implementing any product feature.
>
> Scope: This task initializes the engineering environment only. It must not implement app features, database tables, migrations, UI screens, or business logic unless explicitly listed as documentation placeholders below.

---

## 0. Execution Contract for Codex

You are initializing a Codex-first iOS app engineering workspace.

Follow these rules exactly:

1. **Single task only**
   - This run is only for workspace initialization.
   - Do not implement app features.
   - Do not refactor existing app code.
   - Do not modify database logic.
   - Do not create real Supabase migrations unless the user explicitly asks later.

2. **Safe creation behavior**
   - Create missing directories and files listed below.
   - If a target file already exists, do not overwrite it silently.
   - If a file exists, append a short note to `docs/00_memory/WORKLOG.md` and create a `.new` version for the proposed replacement.
   - Preserve user work.

3. **Use the installed Superpowers plugin**
   - Before acting, check the available Superpowers/plugin capabilities using the installed interface.
   - Use relevant planning, context, memory, task, or code-navigation capabilities if available.
   - Do not assume exact Superpowers command names.
   - If the plugin is unavailable in this environment, continue with this Markdown plan and record that in `WORKLOG.md`.

4. **Context control**
   - Do not load the whole repository unless necessary.
   - Start from `AGENTS.md`, `docs/00_memory/PROJECT_MEMORY.md`, and the current task file.
   - Use targeted file reads, search, and summaries.
   - Keep all long-term facts in memory docs, not in conversation.

5. **After initialization**
   - Run a lightweight file-tree check.
   - Do not run a full build unless the app project already has a valid Xcode scheme and the script can detect it safely.
   - End with a concise report:
     - Files created
     - Files skipped because they already existed
     - Superpowers usage
     - Risks
     - Next recommended task

---

## 1. Directory Tree to Create

Create this structure from the repository root:

```text
.
├── AGENTS.md
├── .codex/
│   ├── config.toml
│   └── agents/
│       ├── README.md
│       ├── main-orchestrator.md
│       ├── context-librarian.md
│       ├── product-flow-mapper.md
│       ├── ios-ui-implementer.md
│       ├── swift-domain-repository-agent.md
│       ├── supabase-contract-agent.md
│       ├── build-test-agent.md
│       ├── bug-reproduction-agent.md
│       └── documentation-scribe.md
├── docs/
│   ├── README.md
│   ├── 00_memory/
│   │   ├── PROJECT_MEMORY.md
│   │   ├── CURRENT_STATE.md
│   │   ├── FEATURE_INDEX.md
│   │   ├── DECISION_LOG.md
│   │   ├── WORKLOG.md
│   │   └── COMPRESSION_RECOVERY.md
│   ├── 01_product/
│   │   ├── PRODUCT_BRIEF.md
│   │   ├── USER_ROLES.md
│   │   ├── NAVIGATION_AND_FLOWS.md
│   │   ├── DESIGN_SYSTEM.md
│   │   ├── SCREEN_INVENTORY.md
│   │   └── UX_RULES.md
│   ├── 02_architecture/
│   │   ├── ARCHITECTURE.md
│   │   ├── MODULE_BOUNDARIES.md
│   │   ├── DATA_FLOW.md
│   │   ├── ERROR_HANDLING.md
│   │   └── LOCAL_DEMO_MODE.md
│   ├── 03_backend/
│   │   ├── SUPABASE_CONTRACT.md
│   │   ├── RLS_RPC_POLICY.md
│   │   ├── STORAGE_POLICY.md
│   │   └── MIGRATION_RULES.md
│   ├── 04_ios/
│   │   ├── IOS_BUILD_AND_TESTING.md
│   │   ├── SWIFT_STYLE_GUIDE.md
│   │   ├── SWIFTUI_STATE_RULES.md
│   │   └── ACCESSIBILITY_CHECKLIST.md
│   ├── 05_workflow/
│   │   ├── CODEX_WORKFLOW.md
│   │   ├── CONTEXT_MANAGEMENT.md
│   │   ├── SERIAL_AGENT_CHAIN.md
│   │   ├── SUBAGENT_RULES.md
│   │   ├── TOOL_RULES.md
│   │   ├── GITHUB_RULES.md
│   │   └── STOP_CONDITIONS.md
│   ├── 06_tasks/
│   │   ├── TASK_LEDGER.md
│   │   ├── TASK_TEMPLATE.md
│   │   ├── HANDOFF_TEMPLATE.md
│   │   └── REVIEW_TEMPLATE.md
│   └── 07_decisions/
│       ├── ADR_TEMPLATE.md
│       └── README.md
└── scripts/
    ├── preflight.sh
    ├── ios-build.sh
    ├── ios-test.sh
    ├── supabase-check.sh
    └── repo-summary.sh
```

---

## 2. File Contents to Write

### `AGENTS.md`

```md
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
```

---

### `.codex/config.toml`

```toml
# Project-level Codex configuration.
# Keep this conservative. Change only with explicit user approval.

model = "gpt-5.5"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
writable_roots = ["."]
network_access = false

# Add MCP server configuration only after the user confirms local setup details.
# Use docs/05_workflow/TOOL_RULES.md as the operational contract.
```

---

### `.codex/agents/README.md`

```md
# Codex Agent Role Cards

These files define role-based Codex behavior for serial agent workflows.

They are not independent source-of-truth documents. They are role prompts.

Use them in this order:

1. `main-orchestrator.md`
2. `context-librarian.md`
3. One specialist role
4. `build-test-agent.md`
5. `documentation-scribe.md`

If native subagents are available, pass the relevant role card to the subagent. If not, follow the role card manually inside the current Codex session or ask the user to start a fresh Codex session with the role card.
```

---

### `.codex/agents/main-orchestrator.md`

```md
# Main Orchestrator Agent

## Mission

Control task scope, select the correct specialist role, and prevent context overload.

## Responsibilities

- Read `AGENTS.md`.
- Read memory docs.
- Read the active task file.
- Decide which specialist role should handle the task.
- Keep the run limited to one major task.
- Refuse scope creep.
- Ensure final checks and memory updates are completed.

## Do Not

- Implement broad unrelated changes.
- Continue to a second task.
- Skip memory updates.
- Ignore stop conditions.

## Output

Before editing:
- Task summary
- Files likely needed
- Specialist role selected
- Validation plan

After editing:
- Files changed
- Checks run
- Memory updates
- Risks
- Next recommended task
```

---

### `.codex/agents/context-librarian.md`

```md
# Context Librarian Agent

## Mission

Load the minimum necessary context and maintain the long-term memory index.

## Responsibilities

- Read `PROJECT_MEMORY.md`.
- Read `FEATURE_INDEX.md`.
- Identify docs/source files relevant to the active task.
- Summarize only relevant context.
- Avoid loading unrelated files.
- Update memory after the task.

## Context Loading Order

1. `AGENTS.md`
2. `docs/00_memory/PROJECT_MEMORY.md`
3. `docs/00_memory/CURRENT_STATE.md`
4. Active task file
5. Feature-specific docs from `FEATURE_INDEX.md`
6. Target source files

## Do Not

- Dump full repository context.
- Read build artifacts.
- Read unrelated screens.
- Read secrets.
- Treat conversation memory as source of truth.
```

---

### `.codex/agents/product-flow-mapper.md`

```md
# Product Flow Mapper Agent

## Mission

Map user roles, screens, navigation, and product flows without implementing code.

## Use For

- Clarifying user journeys
- Creating screen inventories
- Checking feature consistency
- Updating product documentation

## Inputs

- `docs/01_product/PRODUCT_BRIEF.md`
- `docs/01_product/USER_ROLES.md`
- `docs/01_product/NAVIGATION_AND_FLOWS.md`
- `docs/01_product/SCREEN_INVENTORY.md`

## Output

- Updated product flow docs
- Open questions
- Feature boundary notes
- Implementation task candidates

## Do Not

- Write Swift code.
- Modify Supabase schema.
- Create UI files.
```

---

### `.codex/agents/ios-ui-implementer.md`

```md
# iOS UI Implementer Agent

## Mission

Implement one SwiftUI UI task with minimal context and strict boundaries.

## Responsibilities

- Modify only screens/components required by the active task.
- Keep views thin.
- Use existing design tokens/patterns.
- Preserve local demo behavior.
- Add empty/loading/error states where required.
- Run `./scripts/ios-build.sh`.

## Required Reads

- `docs/04_ios/SWIFT_STYLE_GUIDE.md`
- `docs/04_ios/SWIFTUI_STATE_RULES.md`
- `docs/01_product/DESIGN_SYSTEM.md`
- Relevant screen docs from `SCREEN_INVENTORY.md`

## Do Not

- Add business logic directly to views.
- Add dependencies without approval.
- Modify database logic unless the task explicitly requires it.
```

---

### `.codex/agents/swift-domain-repository-agent.md`

```md
# Swift Domain and Repository Agent

## Mission

Implement one domain/model/repository task while preserving architecture boundaries.

## Responsibilities

- Keep network calls inside repositories/services.
- Keep SwiftUI views independent from backend details.
- Add typed request/response models when needed.
- Preserve protocol abstractions.
- Avoid fake success in production modes.
- Run build/tests relevant to the change.

## Required Reads

- `docs/02_architecture/ARCHITECTURE.md`
- `docs/02_architecture/MODULE_BOUNDARIES.md`
- `docs/02_architecture/DATA_FLOW.md`
- `docs/03_backend/SUPABASE_CONTRACT.md`

## Do Not

- Let views directly call Supabase.
- Hide errors silently.
- Collapse local demo and production backend behavior into unsafe shortcuts.
```

---

### `.codex/agents/supabase-contract-agent.md`

```md
# Supabase Contract Agent

## Mission

Handle one Supabase-related documentation, migration, RLS, RPC, or storage task.

## Responsibilities

- Inspect existing migrations before proposing changes.
- Keep migrations append-only unless explicitly authorized.
- Prefer RPC for business mutations that require consistency.
- Verify RLS assumptions.
- Update `SUPABASE_CONTRACT.md`.
- Run `./scripts/supabase-check.sh`.

## Required Reads

- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`
- `docs/03_backend/STORAGE_POLICY.md`
- `docs/03_backend/MIGRATION_RULES.md`
- Existing `supabase/migrations/` files if present

## Do Not

- Reset databases without explicit user permission.
- Use service-role keys in client code.
- Delete or rewrite migrations silently.
- Invent schema facts.
```

---

### `.codex/agents/build-test-agent.md`

```md
# Build and Test Agent

## Mission

Run targeted validation and diagnose failures without broad rewrites.

## Responsibilities

- Run the correct script for the task.
- Capture the first meaningful error.
- Fix only errors caused by the current task.
- Stop after two focused repair attempts.
- Report unresolved failures clearly.

## Scripts

- General: `./scripts/preflight.sh`
- iOS build: `./scripts/ios-build.sh`
- iOS tests: `./scripts/ios-test.sh`
- Supabase contract: `./scripts/supabase-check.sh`

## Do Not

- Rewrite unrelated files to make the build pass.
- Hide failing tests.
- Remove tests without explicit user approval.
- Continue indefinitely.
```

---

### `.codex/agents/bug-reproduction-agent.md`

```md
# Bug Reproduction Agent

## Mission

Reproduce and isolate one reported bug before any fix is attempted.

## Responsibilities

- Restate the bug.
- Identify likely files.
- Create a minimal reproduction path.
- Check logs/build output when relevant.
- Propose a minimal fix plan.
- Hand off to the correct implementation role.

## Do Not

- Start broad refactoring.
- Fix multiple unrelated bugs.
- Guess without reading relevant files.
- Skip reproduction unless impossible.
```

---

### `.codex/agents/documentation-scribe.md`

```md
# Documentation Scribe Agent

## Mission

Keep durable project memory accurate after each task.

## Responsibilities

- Update `CURRENT_STATE.md`.
- Update `FEATURE_INDEX.md` when files/features change.
- Append one entry to `WORKLOG.md`.
- Add a decision to `DECISION_LOG.md` when architecture or product direction changes.
- Write a handoff note if work is incomplete.

## Do Not

- Rewrite history.
- Store huge diffs.
- Duplicate entire source files.
- Add uncertain claims as facts.
```

---

### `docs/README.md`

```md
# Project Documentation Index

This folder is the durable project memory and coordination layer for Codex.

Use it to avoid relying on long conversation context.

## Sections

- `00_memory/`: compressed long-term project memory and recovery files
- `01_product/`: product definition, user roles, flows, design system
- `02_architecture/`: iOS/client architecture and module boundaries
- `03_backend/`: Supabase schema, RLS, RPC, storage, migrations
- `04_ios/`: Swift, SwiftUI, build, testing, accessibility rules
- `05_workflow/`: Codex workflow, context management, tools, subagents
- `06_tasks/`: task ledger, task template, handoff notes, review template
- `07_decisions/`: ADRs and decision templates
```

---

### `docs/00_memory/PROJECT_MEMORY.md`

```md
# Project Memory

This is the highest-level durable memory file for Codex.

Keep this concise. It is an index, not a full project dump.

## Project Identity

- App type: iOS app.
- Platform: SwiftUI-first iOS project.
- Backend: Supabase if configured.
- Development model: Codex-first, single-task runs, serial agent chain.

## Product Summary

TODO: Add the current product summary in 5-10 bullets.

## Architecture Summary

TODO: Add the current architecture in 5-10 bullets.

## Backend Summary

TODO: Add Supabase tables, RPCs, RLS assumptions, and storage buckets when known.

## Active Development Priorities

1. TODO
2. TODO
3. TODO

## Permanent Constraints

- Single major task per Codex run.
- Preserve user work.
- Keep durable project memory updated.
- Do not rely on compressed conversation context.
- Use scripts for checks.
- Use Superpowers/plugin capabilities when available and relevant.

## Important Index Links

- Current state: `docs/00_memory/CURRENT_STATE.md`
- Feature index: `docs/00_memory/FEATURE_INDEX.md`
- Product flows: `docs/01_product/NAVIGATION_AND_FLOWS.md`
- Architecture: `docs/02_architecture/ARCHITECTURE.md`
- Backend contract: `docs/03_backend/SUPABASE_CONTRACT.md`
- Workflow: `docs/05_workflow/CODEX_WORKFLOW.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
```

---

### `docs/00_memory/CURRENT_STATE.md`

```md
# Current State

Update this after every meaningful task.

## Last Updated

- Date:
- Updated by:

## Current Branch

TODO

## Current Build Status

- Last build command:
- Result:
- Known failing checks:

## Current Product State

TODO

## Current iOS State

TODO

## Current Backend State

TODO

## Known Risks

- TODO

## Next Recommended Task

TODO
```

---

### `docs/00_memory/FEATURE_INDEX.md`

```md
# Feature Index

This file maps features to docs and source files.

Codex should use this file to find relevant context without loading the full repository.

| Feature | Product Docs | Architecture Docs | Backend Docs | iOS Files | Status | Notes |
|---|---|---|---|---|---|---|
| TODO | TODO | TODO | TODO | TODO | planned | TODO |
```

---

### `docs/00_memory/DECISION_LOG.md`

```md
# Decision Log

Use this for durable architecture/product decisions.

Do not store minor implementation details here.

## Format

```text
Date:
Decision:
Context:
Options considered:
Reason:
Consequences:
Linked files:
```

## Decisions

_No decisions recorded yet._
```

---

### `docs/00_memory/WORKLOG.md`

```md
# Worklog

Append one short entry after each Codex run.

## Format

```text
Date:
Task:
Files changed:
Checks:
Result:
Risks:
Next:
```

## Entries

_No entries yet._
```

---

### `docs/00_memory/COMPRESSION_RECOVERY.md`

```md
# Compression Recovery Protocol

Use this when conversation context is compressed, stale, missing, or contradictory.

## Recovery Steps

1. Stop relying on conversation memory.
2. Read `AGENTS.md`.
3. Read `PROJECT_MEMORY.md`.
4. Read `CURRENT_STATE.md`.
5. Read `FEATURE_INDEX.md`.
6. Read the active task file.
7. Use repository search only for files linked to the active task.
8. Produce a short recovered context summary.
9. Continue only if the task boundary is clear.

## Recovery Summary Template

```text
Recovered task:
Relevant docs:
Relevant source files:
Known constraints:
Unknowns:
Safe next action:
```

## Rules

- Do not infer current architecture from old conversation text.
- Do not load the whole repository.
- Do not continue if the active task is unknown.
- Ask for user direction if recovery cannot identify the task.
```

---

### `docs/01_product/PRODUCT_BRIEF.md`

```md
# Product Brief

## One-Sentence Product Definition

TODO: Define the app in one sentence.

## Target Users

- Customer:
- Service provider:
- Admin/moderator if applicable:

## Core Jobs To Be Done

1. TODO
2. TODO
3. TODO

## Non-Goals

- TODO

## MVP Scope

- TODO

## Later Scope

- TODO

## Product Constraints

- Keep flows simple.
- Avoid adding screens without updating `SCREEN_INVENTORY.md`.
- Avoid adding backend states without updating `SUPABASE_CONTRACT.md`.
```

---

### `docs/01_product/USER_ROLES.md`

```md
# User Roles

## Roles

| Role | Description | Permissions | Primary Screens |
|---|---|---|---|
| Customer | TODO | TODO | TODO |
| Service Provider | TODO | TODO | TODO |
| Admin | Optional | TODO | TODO |

## Role Rules

- Do not mix role-specific permissions in UI-only logic.
- Backend permissions must be enforced by RLS/RPC when Supabase is used.
- Local demo mode may simulate permissions but must not hide production requirements.
```

---

### `docs/01_product/NAVIGATION_AND_FLOWS.md`

```md
# Navigation and Product Flows

## Navigation Map

TODO: Add high-level navigation.

## Core Flow Template

```text
Entry screen:
User action:
System response:
Backend mutation:
Success state:
Error state:
Follow-up screen:
```

## Flows

### Flow 1: TODO

- Entry:
- Steps:
- Success:
- Error:
- Related source files:
```

---

### `docs/01_product/DESIGN_SYSTEM.md`

```md
# Design System

This file prevents UI drift.

## Visual Direction

TODO: Define the desired visual style.

## Design Principles

- Simple screens.
- Clear hierarchy.
- Friendly but not cluttered.
- Consistent spacing.
- Clear loading, empty, and error states.
- Avoid marketplace clutter unless intentionally designed.

## Tokens

### Spacing

TODO

### Typography

TODO

### Color Usage

TODO

### Components

| Component | Purpose | States | Notes |
|---|---|---|---|
| PrimaryButton | TODO | normal/loading/disabled | TODO |
| Card | TODO | normal/selected/error | TODO |

## Rules for Codex

- Do not invent a new visual style per screen.
- Reuse existing components when available.
- Update this file when adding reusable UI patterns.
```

---

### `docs/01_product/SCREEN_INVENTORY.md`

```md
# Screen Inventory

Map every screen to its purpose, data source, and state owner.

| Screen | Purpose | User Role | Data Source | State Owner | Source File | Status |
|---|---|---|---|---|---|---|
| TODO | TODO | TODO | TODO | TODO | TODO | planned |
```

---

### `docs/01_product/UX_RULES.md`

```md
# UX Rules

## General

- Every async action needs loading feedback.
- Every failed backend action needs visible error feedback.
- Every empty list needs an empty state.
- Avoid forcing users to understand backend states.
- Avoid deep navigation for primary actions.

## Forms

- Validate required fields before submission.
- Preserve user input after recoverable errors.
- Show clear confirmation after success.

## Marketplace/Booking-Style Flows

- Avoid duplicate submissions.
- Disable submit buttons while requests are in flight.
- Make status transitions explicit.
- Do not show impossible actions for the current state.
```

---

### `docs/02_architecture/ARCHITECTURE.md`

```md
# Architecture

## Target Architecture

TODO: Fill with actual architecture after project inspection.

Recommended default:

```text
SwiftUI Views
↓
View Models / UI State Coordinators
↓
Use Cases / Domain Services
↓
Repositories
↓
Backend Adapters / Local Demo Adapters
↓
Supabase or local data
```

## Rules

- Views should not own business rules.
- Views should not directly call Supabase.
- Repositories should hide backend implementation details.
- Domain models should not be shaped only by UI convenience.
- Local demo mode must remain intentionally separate from production backend behavior.

## Update Policy

Update this file whenever:
- A new module is added.
- A new data boundary is introduced.
- A major flow changes.
- Backend/client responsibilities change.
```

---

### `docs/02_architecture/MODULE_BOUNDARIES.md`

```md
# Module Boundaries

## Layers

| Layer | Allowed Responsibilities | Forbidden Responsibilities |
|---|---|---|
| View | Layout, user interaction, simple UI state | Backend calls, business rules |
| ViewModel/Coordinator | UI state, input validation, calling use cases | Direct database policy decisions |
| Use Case/Service | Business operations | UI layout |
| Repository | Data access boundary | UI state |
| Backend Adapter | Supabase/local implementation | Product decisions |

## Dependency Direction

Higher layers may depend on lower abstractions.

Lower layers must not import UI-specific logic.
```

---

### `docs/02_architecture/DATA_FLOW.md`

```md
# Data Flow

## Read Flow

```text
View -> ViewModel -> Repository -> Backend/Local Adapter -> Repository -> ViewModel -> View
```

## Mutation Flow

```text
View action -> ViewModel validation -> Use Case/Repository -> Backend RPC or local equivalent -> state refresh -> UI result
```

## Rules

- Do not mutate production backend state directly from views.
- Prefer explicit refresh after important mutations.
- Do not fake success in production backend mode.
- Keep local demo data clearly marked.
```

---

### `docs/02_architecture/ERROR_HANDLING.md`

```md
# Error Handling

## Principles

- Fail visibly.
- Preserve recoverable user input.
- Do not silently swallow backend errors.
- Log enough information for debugging.
- Show user-safe messages in UI.

## Error Categories

| Category | Example | Handling |
|---|---|---|
| Validation | Missing required field | Inline message |
| Network | Timeout | Retry option or visible error |
| Permission | RLS denied | User-safe permission message |
| Conflict | Duplicate action | Refresh state and show explanation |
| Unknown | Unexpected response | Generic error + log |

## Rules for Codex

When adding async behavior, include:
- loading state
- success state
- error state
- duplicate submission protection
```

---

### `docs/02_architecture/LOCAL_DEMO_MODE.md`

```md
# Local Demo Mode

## Purpose

Local demo mode allows UI/product development without depending on a live backend.

## Rules

- Local demo mode must be clearly separated from production backend mode.
- Local demo success must not hide missing production implementation.
- Local demo data should be deterministic enough for testing.
- If a production backend operation is unimplemented, mark it explicitly.

## Required Documentation

For each feature:

| Feature | Local Demo Behavior | Production Behavior | Gap |
|---|---|---|---|
| TODO | TODO | TODO | TODO |
```

---

### `docs/03_backend/SUPABASE_CONTRACT.md`

```md
# Supabase Contract

This is the source of truth for backend expectations.

Do not invent schema facts. Inspect migrations or Supabase metadata before updating.

## Tables

| Table | Purpose | Key Columns | RLS Summary | Notes |
|---|---|---|---|---|
| TODO | TODO | TODO | TODO | TODO |

## RPC Functions

| Function | Purpose | Inputs | Returns | Security Notes |
|---|---|---|---|---|
| TODO | TODO | TODO | TODO | TODO |

## Storage Buckets

| Bucket | Purpose | Access Rules | Notes |
|---|---|---|---|
| TODO | TODO | TODO | TODO |

## Client Rules

- Client code must not use service-role keys.
- Client code must not bypass RLS.
- Business-critical multi-step mutations should use RPC.
- Update this file when migrations, RPC, policies, or storage rules change.
```

---

### `docs/03_backend/RLS_RPC_POLICY.md`

```md
# RLS and RPC Policy

## RLS Principles

- RLS is the permission boundary.
- UI visibility is not security.
- Policies must match user roles.
- Test permission assumptions when possible.

## RPC Principles

Use RPC for:
- multi-step mutations
- status transitions
- operations requiring conflict protection
- operations that must be atomic
- operations where client-side sequencing could create inconsistent data

## Rules for Codex

- Do not create direct client mutations for business-critical transitions without checking this file.
- Do not change policies without documenting the reason.
- Do not mark an operation complete until production behavior is implemented or explicitly documented as pending.
```

---

### `docs/03_backend/STORAGE_POLICY.md`

```md
# Supabase Storage Policy

## Buckets

| Bucket | Purpose | Public/Private | Upload Rules | Read Rules |
|---|---|---|---|---|
| TODO | TODO | TODO | TODO | TODO |

## Rules

- Do not store secrets in storage.
- Validate file type and size where applicable.
- Keep user-owned uploads scoped by user identity when possible.
- Document signed URL behavior if used.
```

---

### `docs/03_backend/MIGRATION_RULES.md`

```md
# Migration Rules

## Principles

- Migrations are append-only by default.
- Do not rewrite applied migrations unless explicitly authorized.
- Keep schema changes small and named clearly.
- Update `SUPABASE_CONTRACT.md` after schema changes.
- Add RLS/policy documentation for permission-sensitive changes.

## Migration Checklist

Before creating a migration:

- [ ] Read existing migrations.
- [ ] Confirm the target schema change.
- [ ] Confirm whether RLS is affected.
- [ ] Confirm whether RPC is needed.
- [ ] Confirm whether app code depends on the change.

After creating a migration:

- [ ] Update backend docs.
- [ ] Run `./scripts/supabase-check.sh`.
- [ ] Update memory docs.
```

---

### `docs/04_ios/IOS_BUILD_AND_TESTING.md`

```md
# iOS Build and Testing

## Build Script

Use:

```bash
./scripts/ios-build.sh
```

## Test Script

Use:

```bash
./scripts/ios-test.sh
```

## Scheme

TODO: Fill after inspecting the Xcode project.

## Simulator

TODO: Fill after inspecting available simulators.

## Rules

- Do not invent xcodebuild commands when scripts exist.
- If scripts need project-specific values, update the script once.
- If build fails, fix only failures related to the current task.
- Stop after two focused repair attempts and report.
```

---

### `docs/04_ios/SWIFT_STYLE_GUIDE.md`

```md
# Swift Style Guide

## General

- Prefer clear names over clever names.
- Use explicit types where they improve readability.
- Keep files focused.
- Avoid large view files when extracting components would clarify intent.
- Avoid new dependencies unless approved.

## Async

- Use structured concurrency when appropriate.
- Avoid untracked background work.
- Handle cancellation when relevant.
- Keep UI updates on the main actor.

## Models

- Prefer typed models over loosely shaped dictionaries.
- Keep DTO/backend models separate from domain models when the difference matters.

## Error Handling

- Avoid `try?` unless failure is intentionally ignored and documented.
- Avoid silent catch blocks.
- Return user-safe errors to UI layers.
```

---

### `docs/04_ios/SWIFTUI_STATE_RULES.md`

```md
# SwiftUI State Rules

## Principles

- Views render state.
- ViewModels coordinate UI state and actions.
- Repositories handle data boundaries.
- Business rules should not live in view layout code.

## State Checklist

For async actions:

- [ ] idle
- [ ] loading
- [ ] success
- [ ] error
- [ ] duplicate submit protection

## Rules

- Use `@State` for local view-only state.
- Use `@StateObject` for owned observable objects.
- Use `@ObservedObject` or environment injection for externally owned objects.
- Avoid global mutable state unless justified.
```

---

### `docs/04_ios/ACCESSIBILITY_CHECKLIST.md`

```md
# Accessibility Checklist

For UI changes, check:

- [ ] Buttons have meaningful labels.
- [ ] Images have accessibility labels or are marked decorative.
- [ ] Text remains readable with Dynamic Type.
- [ ] Color is not the only state signal.
- [ ] Tap targets are reasonably sized.
- [ ] Loading and error states are accessible.
```

---

### `docs/05_workflow/CODEX_WORKFLOW.md`

```md
# Codex Workflow

## Standard Run

1. Read startup context.
2. Check Superpowers/plugin capabilities.
3. Confirm one active task.
4. Select specialist role.
5. Inspect only relevant files.
6. Make minimal changes.
7. Run relevant checks.
8. Update memory.
9. Report results.
10. Stop.

## Task Size Rule

A Codex task should normally fit one of these categories:

- One screen improvement
- One repository method
- One backend RPC/migration
- One bug reproduction and fix
- One documentation update
- One build/test repair

If a task touches product flow, backend contract, and multiple screens, split it.

## Interruption Safety

Every task must leave the repository in a recoverable state.

If interrupted:
- Current changes should be small.
- Active files should be clear.
- Handoff notes should be possible from diff + `WORKLOG.md`.
```

---

### `docs/05_workflow/CONTEXT_MANAGEMENT.md`

```md
# Context Management

## Goal

Prevent degraded decisions after long sessions, context compression, or interrupted runs.

## Durable Context Files

Use these instead of relying on conversation context:

- `PROJECT_MEMORY.md`: stable index
- `CURRENT_STATE.md`: latest known app state
- `FEATURE_INDEX.md`: feature-to-file map
- `DECISION_LOG.md`: architecture/product decisions
- `WORKLOG.md`: chronological task log
- `COMPRESSION_RECOVERY.md`: recovery procedure

## Context Pack Pattern

For each major feature, create a compact context pack when needed:

```text
docs/00_memory/context_packs/<feature-name>.md
```

A context pack should contain:
- Feature purpose
- Relevant source files
- Relevant backend objects
- Current known behavior
- Known bugs
- Open questions

## What Not To Store

Do not store:
- Full source files
- Huge diffs
- Generated build logs
- Secrets
- Temporary speculation
- Unverified assumptions

## When to Update Memory

Update memory after:
- New feature behavior
- New screen
- New backend contract
- New architecture decision
- Important bug fix
- Build/test status change
```

---

### `docs/05_workflow/SERIAL_AGENT_CHAIN.md`

```md
# Serial Agent Chain

## Purpose

Use multiple focused agent roles without allowing uncontrolled parallel edits.

## Default Chain

```text
Main Orchestrator
↓
Context Librarian
↓
Specialist Agent
↓
Build/Test Agent
↓
Documentation Scribe
```

## Rules

- Only one specialist should edit code for a task.
- Subagents should handle simple, bounded work.
- Do not let multiple agents edit the same files simultaneously.
- Use fresh sessions for large context shifts.
- Use handoff notes between sessions.

## When to Start a Fresh Codex Session

Start fresh when:
- The previous session consumed too much context.
- A new specialist role is needed.
- The task is complete and a new task begins.
- The model seems to rely on stale assumptions.
- Build failures require isolated diagnosis.
```

---

### `docs/05_workflow/SUBAGENT_RULES.md`

```md
# Subagent Rules

## Purpose

Subagents reduce main-agent context usage by handling small, bounded tasks.

## Good Subagent Tasks

- Summarize one feature area.
- Inspect one file group.
- Reproduce one bug.
- Check one backend contract.
- Run one build/test command and summarize error.
- Update documentation after a completed task.
- Map one screen's state/data dependencies.

## Bad Subagent Tasks

- Build the whole app.
- Redesign the architecture.
- Touch many unrelated modules.
- Make product decisions.
- Modify backend and UI at the same time.
- Continue automatically to the next task.

## Subagent Output Format

Every subagent must return:

```text
Task:
Files inspected:
Findings:
Files changed, if any:
Risks:
Recommended next action:
```

## Subagent Safety

- Subagents should be read-only unless the task explicitly allows edits.
- Subagents should not commit.
- Subagents should not push.
- Subagents should not modify secrets.
```

---

### `docs/05_workflow/TOOL_RULES.md`

```md
# Tool Rules

## General Tool Policy

Use tools to verify reality, not to create uncontrolled side effects.

Before using a tool:
1. State why it is needed.
2. Use the least destructive operation.
3. Prefer read-only inspection first.
4. Record important findings in memory docs.

## Superpowers Plugin

The Superpowers plugin is installed and should be used when relevant.

Use it for:
- planning
- task decomposition
- context management
- code navigation
- verification
- memory/handoff workflow
- skills that match the current task

Rules:
- Check available Superpowers capabilities at the start of a run.
- Do not assume exact command names.
- Do not let plugin output override repository source of truth.
- If a Superpowers workflow conflicts with `AGENTS.md`, follow `AGENTS.md`.

## Xcode / Build MCP

Use for:
- detecting project/scheme/simulator
- building
- testing
- simulator actions if relevant

Rules:
- Prefer project scripts when available.
- Do not change signing, bundle ID, or deployment settings unless the task requires it.
- Do not create new schemes without explicit approval.

## Supabase MCP

Use for:
- inspecting schema
- verifying migrations
- checking RLS/RPC assumptions
- reading metadata needed for backend tasks

Rules:
- Read before writing.
- Do not reset remote DB.
- Do not repair migrations without approval.
- Do not expose secrets.
- Document any confirmed schema facts in `SUPABASE_CONTRACT.md`.

## GitHub MCP

Use for:
- reading issues
- reading pull requests
- summarizing diffs
- linking tasks to issues

Rules:
- Do not push without approval.
- Do not close issues without approval.
- Do not modify repository settings.
- Keep work on a branch when requested.

## Filesystem/Search

Use:
- `rg`/search for targeted file discovery
- narrow file reads
- scripts for validation

Avoid:
- full repository dumps
- build artifacts
- secrets
- unrelated generated files
```

---

### `docs/05_workflow/GITHUB_RULES.md`

```md
# GitHub Rules

## Branching

Recommended branch format:

```text
codex/<short-task-name>
```

## Commit Policy

Do not commit unless the user asks.

If asked to commit:
- Keep one task per commit.
- Use a clear message.
- Include docs updates when relevant.

## PR Policy

Do not open or update PRs unless explicitly asked.

## Issue Policy

If using GitHub issues:
- Link task files to issue IDs.
- Do not close issues automatically.
- Summarize work and risks before asking for review.
```

---

### `docs/05_workflow/STOP_CONDITIONS.md`

```md
# Stop Conditions

Codex must stop and report when any condition occurs.

## Scope Stop

- The task requires more than one major feature.
- The task begins to affect unrelated screens/modules.
- The task requires a product decision not documented.

## Safety Stop

- A destructive database operation appears necessary.
- Secrets are required.
- Remote state is uncertain.
- User changes would be overwritten.

## Technical Stop

- Build fails after two focused repair attempts.
- Required scheme/simulator cannot be detected.
- Supabase schema cannot be verified.
- Tests fail for reasons unrelated to the current task.

## Context Stop

- Conversation context conflicts with memory docs.
- Memory docs are missing critical project facts.
- Current code differs greatly from documented architecture.

## Required Stop Report

```text
Stop reason:
What was attempted:
What was found:
Files touched:
Safe next options:
User decision needed:
```
```

---

### `docs/06_tasks/TASK_LEDGER.md`

```md
# Task Ledger

Track tasks here so Codex does not continue automatically.

| ID | Task | Status | Owner Role | Files/Docs | Checks | Notes |
|---|---|---|---|---|---|---|
| T-000 | Initialize Codex workspace docs | in_progress | Main Orchestrator | docs/, .codex/, scripts/ | preflight | Current task |
```

---

### `docs/06_tasks/TASK_TEMPLATE.md`

```md
# Task Template

## Task ID

T-XXX

## Title

TODO

## Single Main Goal

TODO: One sentence only.

## Non-Goals

- TODO
- TODO

## Required Context

- `AGENTS.md`
- TODO

## Likely Files

- TODO

## Agent Role

Choose one:

- Main Orchestrator
- Context Librarian
- Product Flow Mapper
- iOS UI Implementer
- Swift Domain and Repository Agent
- Supabase Contract Agent
- Build and Test Agent
- Bug Reproduction Agent
- Documentation Scribe

## Tool Plan

- Superpowers:
- Xcode/build:
- Supabase:
- GitHub:

## Acceptance Criteria

- [ ] TODO
- [ ] Relevant checks pass
- [ ] Memory docs updated

## Stop Conditions

- TODO
```

---

### `docs/06_tasks/HANDOFF_TEMPLATE.md`

```md
# Handoff Template

Use this when work is interrupted or moved to another Codex session.

## Task

TODO

## Current Status

TODO

## Files Changed

- TODO

## Files Inspected

- TODO

## Decisions Made

- TODO

## Checks Run

- TODO

## Failing Checks

- TODO

## Known Risks

- TODO

## Next Safe Action

TODO
```

---

### `docs/06_tasks/REVIEW_TEMPLATE.md`

```md
# Review Template

Use this for internal Codex review before reporting completion.

## Scope Check

- [ ] Only one major task was completed.
- [ ] No unrelated refactor was introduced.
- [ ] Existing user changes were preserved.

## Architecture Check

- [ ] Module boundaries preserved.
- [ ] Views remain thin.
- [ ] Backend access remains behind repositories/services.
- [ ] Local demo mode preserved if applicable.

## Backend Check

- [ ] Supabase contract updated if needed.
- [ ] RLS/RPC assumptions documented if needed.
- [ ] No destructive operation performed.
- [ ] No secrets exposed.

## iOS Check

- [ ] Build script run if code changed.
- [ ] Tests run if relevant.
- [ ] Loading/error/empty states handled when relevant.
- [ ] Accessibility considered for UI changes.

## Memory Check

- [ ] `CURRENT_STATE.md` updated.
- [ ] `FEATURE_INDEX.md` updated if needed.
- [ ] `WORKLOG.md` appended.
- [ ] `DECISION_LOG.md` updated if needed.
```

---

### `docs/07_decisions/ADR_TEMPLATE.md`

```md
# ADR Template

# ADR-XXX: Title

## Status

Proposed / Accepted / Rejected / Superseded

## Date

YYYY-MM-DD

## Context

What problem are we solving?

## Decision

What did we decide?

## Alternatives Considered

1. Option A
2. Option B
3. Option C

## Consequences

Positive:
- TODO

Negative:
- TODO

## Linked Files

- TODO
```

---

### `docs/07_decisions/README.md`

```md
# Architecture Decision Records

Use ADRs for important architecture and product decisions.

Do not create ADRs for minor implementation details.
```

---

## 3. Script Contents to Write

After writing scripts, make them executable:

```bash
chmod +x scripts/*.sh
```

### `scripts/preflight.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== Preflight =="

echo "-- Git status --"
git status --short || true

echo "-- Required docs --"
required_files=(
  "AGENTS.md"
  "docs/00_memory/PROJECT_MEMORY.md"
  "docs/00_memory/CURRENT_STATE.md"
  "docs/00_memory/FEATURE_INDEX.md"
  "docs/06_tasks/TASK_LEDGER.md"
  "docs/05_workflow/CODEX_WORKFLOW.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file"
    exit 1
  fi
done

echo "-- Secret scan hints --"
if find . -maxdepth 3 -type f \( -name ".env" -o -name ".env.*" \) | grep -q .; then
  echo "Warning: .env files exist. Do not read or expose secrets."
fi

echo "Preflight passed."
```

---

### `scripts/ios-build.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== iOS Build =="

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode or run this on macOS with Xcode available."
  exit 1
fi

project_file="$(find . -maxdepth 3 -name "*.xcodeproj" | head -n 1 || true)"
workspace_file="$(find . -maxdepth 3 -name "*.xcworkspace" | head -n 1 || true)"

if [[ -z "$project_file" && -z "$workspace_file" ]]; then
  echo "No .xcodeproj or .xcworkspace found within maxdepth 3."
  exit 1
fi

echo "Detected project: ${project_file:-none}"
echo "Detected workspace: ${workspace_file:-none}"

echo "This script needs project-specific scheme configuration."
echo "Update docs/04_ios/IOS_BUILD_AND_TESTING.md and this script after inspecting schemes."

if [[ -n "${CODEX_IOS_SCHEME:-}" ]]; then
  scheme="$CODEX_IOS_SCHEME"
else
  echo "CODEX_IOS_SCHEME is not set. Refusing to guess scheme."
  exit 1
fi

destination="${CODEX_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"

if [[ -n "$workspace_file" ]]; then
  xcodebuild -workspace "$workspace_file" -scheme "$scheme" -destination "$destination" build
else
  xcodebuild -project "$project_file" -scheme "$scheme" -destination "$destination" build
fi
```

---

### `scripts/ios-test.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== iOS Test =="

if [[ -z "${CODEX_IOS_SCHEME:-}" ]]; then
  echo "CODEX_IOS_SCHEME is not set. Refusing to guess scheme."
  exit 1
fi

project_file="$(find . -maxdepth 3 -name "*.xcodeproj" | head -n 1 || true)"
workspace_file="$(find . -maxdepth 3 -name "*.xcworkspace" | head -n 1 || true)"
destination="${CODEX_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"

if [[ -n "$workspace_file" ]]; then
  xcodebuild -workspace "$workspace_file" -scheme "$CODEX_IOS_SCHEME" -destination "$destination" test
elif [[ -n "$project_file" ]]; then
  xcodebuild -project "$project_file" -scheme "$CODEX_IOS_SCHEME" -destination "$destination" test
else
  echo "No .xcodeproj or .xcworkspace found."
  exit 1
fi
```

---

### `scripts/supabase-check.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== Supabase Contract Check =="

if [[ ! -d "supabase" ]]; then
  echo "No supabase directory found. Skipping Supabase checks."
  exit 0
fi

if [[ -d "supabase/migrations" ]]; then
  echo "Migrations directory found."
else
  echo "Warning: supabase directory exists but migrations directory is missing."
fi

echo "-- Checking for service-role key exposure patterns --"
if grep -R "service_role\|SUPABASE_SERVICE_ROLE" . \
  --exclude-dir=.git \
  --exclude-dir=DerivedData \
  --exclude="*.md" >/tmp/codex_supabase_secret_scan.txt 2>/dev/null; then
  echo "Potential service-role key reference found outside markdown. Inspect before continuing:"
  cat /tmp/codex_supabase_secret_scan.txt
  exit 1
fi

echo "-- Checking for backend contract doc --"
if [[ ! -f "docs/03_backend/SUPABASE_CONTRACT.md" ]]; then
  echo "Missing docs/03_backend/SUPABASE_CONTRACT.md"
  exit 1
fi

echo "Supabase contract check passed."
```

---

### `scripts/repo-summary.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== Repository Summary =="

echo "-- Git --"
git status --short || true

echo "-- Top-level files --"
find . -maxdepth 2 \
  -not -path "./.git/*" \
  -not -path "./DerivedData/*" \
  -print | sort | head -n 200

echo "-- Xcode projects --"
find . -maxdepth 4 \( -name "*.xcodeproj" -o -name "*.xcworkspace" \) -print

echo "-- Supabase --"
find supabase -maxdepth 3 -type f 2>/dev/null | sort | head -n 100 || true
```

---

## 4. Initialization Validation

After creating files, run:

```bash
./scripts/preflight.sh
```

Then report:

```text
Workspace initialization complete.

Created:
- ...

Skipped because existing:
- ...

Superpowers/plugin usage:
- ...

Validation:
- ./scripts/preflight.sh: pass/fail

Risks:
- ...

Next recommended task:
- Inspect Xcode project scheme and update CODEX_IOS_SCHEME instructions.
```

---

## 5. Do Not Proceed Beyond This Initialization

After finishing this initialization task, stop.

Do not:
- implement app features
- edit Swift files
- create Supabase migrations
- redesign screens
- create GitHub issues
- commit or push

Wait for the next explicit user task.
