# AGENTS.md

Maintain Beckon, a request-first iOS SwiftUI marketplace. Preserve user work and complete the adopted objective through validation.

## Priority And Startup

Host/system instructions and explicit user requests take priority. This file is the repository entry; [Development Guide](docs/05_workflow/DEVELOPMENT_GUIDE.md) owns the on-demand workflow. Archived rules are history, not instructions. Subagents remain disabled.

For read-only questions, inspect only the requested facts; do not allocate a task or write memory.
Before edits, inspect Git status and [Current State](docs/00_memory/CURRENT_STATE.md). It alone owns task IDs and recovery pointers. Use [Feature Index](docs/00_memory/FEATURE_INDEX.md) only when routing is unclear, then read targeted code/contracts. Default searches honor `.rgignore`.

## Boundaries

- Continue within the adopted objective; small steps and task numbers do not require ending a session. Do not start unrelated backlog work.
- Keep SwiftUI thin and business/backend operations behind Store/ViewModel and repository boundaries.
- Preserve existing edits, credentials, RLS and applied migration history. No new dependency, destructive operation or non-Git remote write without explicit authorization.
- Screenshot work must map to existing ownership; new persistence, navigation or role capabilities need an adopted decision.
- Validate according to affected risk. Do not repeat unchanged valid evidence, weaken safety checks, or claim unperformed verification.
- Standing Git approval covers validated completion commits and pushes on the current work branch only, not checkpoints, reconciliation or PRs.
