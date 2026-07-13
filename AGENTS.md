# AGENTS.md

## Mission

Maintain the Beckon iOS SwiftUI repository through small, reversible changes. Complete one primary `T-###` task per session and preserve user work.

## Rule Priority

Apply instructions in this order: host/system, explicit user request, this file, the owner workflow file below, then active project facts. Host-required tools or skills may shape execution but do not expand scope or grant remote authorization.

Archived agent-team, subagent, workflow, task, and report files are historical only. Do not use them unless the user explicitly re-enables that material.

## Workflow Owners

- `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`: task lifecycle, mode, scope, closeout, and meta-review scheduling.
- `docs/05_workflow/CONTEXT_AND_RECOVERY.md`: context access, recovery, compaction, and structural hygiene.
- `docs/05_workflow/TOOLING_POLICY.md`: validation, tools, credentials, Simulator policy, Supabase, and remote authorization.
- `docs/05_workflow/GITHUB_RULES.md`: commit, branch, push, PR, tag, and reconciliation conventions.
- `docs/05_workflow/STOP_CONDITIONS.md`: stop-and-report matrix.

Do not duplicate an owner rule in another active workflow file; link to its owner.

## Minimal Startup

1. Read this file.
2. Run `git status --short` before edits and preserve unrelated work.
3. Read targeted top sections of `docs/00_memory/CURRENT_STATE.md` only when branch, validation, risks, or recovery matter.
4. Read targeted top rows of `docs/06_tasks/TASK_LEDGER.md` only when assigning or updating task status.
5. After classifying the task, add at most one domain index before targeted rules/code.

Default searches honor `.rgignore`. Never use a broad glob that re-includes frozen, seed, export, or heavy UI material. Root/external-agent Markdown is review input, not current fact.

## Hard Gates

- Use the ledger's next task ID for new implementation, bugfix, or governed workflow work.
- One task per session. A due meta-review is reserved as the next task and runs in a fresh session, never automatically after another task.
- Rule-file changes are standalone tasks with a decision-log entry and context hygiene.
- Keep SwiftUI presentation thin; business logic stays in Store/ViewModel/repository boundaries. Backend access stays behind repositories/services.
- Screenshot work maps every module to existing app ownership before editing. New persistence, schema, RLS/RPC, Storage, navigation, role capability, or deferred behavior requires a separate decision.
- Do not invent backend facts, expose secrets, perform destructive operations, add dependencies, create PRs, or make non-Git remote writes without explicit approval.
- Subagents remain disabled unless the user explicitly enables them.

## Completion

Follow the owner files for validation, closeout, context hygiene, and Git. Standing approval covers validated task-completion commits and pushes on the current work branch only; it does not cover incomplete checkpoint commits or other remote operations.

When Markdown moves or disappears, update every active index, link, source-of-truth note, and ignore/search rule in the same task. On interruption or stale context, recover through `CONTEXT_AND_RECOVERY.md` rather than history reconstruction.
