# Tooling Policy

Owns: validation, tools, credentials, and remote-operation authorization.

## General Rules

- Use tools only to reduce task-relevant uncertainty, implement scope, or verify results.
- Prefer repository scripts and structured parsers over invented commands.
- Inspect before writing; edit only current-task files and preserve unrelated work.
- Never print, commit, or expose secrets or full private identifiers.
- Host-mandated skills and tool instructions take precedence over repository preferences. They do not expand task scope, authorize remote effects, or override user limits.
- Repository-disabled subagents remain disabled unless the user explicitly enables them.

## Validation Source Of Truth

| Mode | Completion validation |
|---|---|
| Micro | None by default. |
| Quick | `git diff --check` when files changed; add the focused docs/script test when the task changes governance or executable scripts. |
| Standard | `git diff --check`, focused tests for the touched domain when available, and one `./scripts/ios-build.sh` completion attempt. |
| Deep | State the validation plan before edits and run its narrow local/read-only gates before any separately authorized remote operation. |

Use full `./scripts/ios-test.sh` only for package/integration gates, shared Store/repository/DesignSystem changes used broadly, Deep tasks, or pre-release validation. UI tests are not default unless the task changes their contract or explicitly requires them.

### Development Versus Completion Failure

General context hygiene reports stale backend verification dates as warnings, not unrelated task blockers. Backend work that relies on those documents must run `CONTEXT_HYGIENE_REQUIRE_FRESH_BACKEND=1 node scripts/context-hygiene-check.mjs` before implementation or remote operations, except for the evidence-refresh inspection below, and retain that environment setting for numbered task closeout. Refresh evidence before updating verification dates; never change dates merely to pass. Missing, invalid, and future dates remain errors in every mode.

Evidence-refresh exception: stale dates do not block task-relevant local inspection or read-only linked checks whose purpose is to verify and refresh those documents. Confirm the authorized project and bounded inspection scope first; retain the credential, sequential CLI, and failure-stop rules below. This exception does not authorize SQL writes (including rollback-only test writes), migration apply/repair, deployment, or relaxed access controls. Record actual verification evidence and discrepancies; update only claims/dates supported by it, never mark an entire document freshly verified from a partial check. Then rerun strict hygiene before dependent implementation or remote mutations. Failed or incomplete inspection leaves the evidence gate unresolved; do not rerun the unchanged strict gate as a prerequisite to the inspection itself.

Expected RED from TDD, a focused diagnostic test, or a task-caused development compile failure is implementation evidence, not a completion-gate failure. Investigate and correct it within the same approved scope. Stop if it reveals unrelated baseline failure, missing authorization, uncertain source facts, or a second task.

Completion validation starts only after implementation is believed complete. On failure, report the first real error. One narrow correction and one rerun are allowed when the failure is directly task-caused and requires no scope or authorization change; otherwise stop rather than entering a retry loop.

## Simulator And Runtime

Launch Simulator when the user requests inspection, interaction/navigation changed, the acceptance criteria require runtime evidence, or static/build evidence cannot validate visible behavior. Docs-only, workflow-only, read-only, and backend-only tasks skip it.

When the user defers visual review to their own inspection, record Simulator validation as `user-deferred`; this is not a failure. A screenshot task still needs source mapping and build validation, but Simulator evidence is required only when requested or specified by acceptance criteria.

When runtime validation runs, sample recent task-relevant logs first, then severity/keyword matches, then narrow surrounding ranges. Expand only when necessary. Distinguish Beckon diagnostics from Apple/Simulator noise and record actionable findings.

## Supabase And TestOps

Use local repository facts first. Current backend authority is `../03_backend/SUPABASE_CONTRACT.md`; migration sequence and credential taxonomy live in `../03_backend/MIGRATION_RULES.md`; TestOps commands live in `../04_ios/testops/RUNBOOK.md`.

- Use the installed Supabase CLI, not `npx`, containers, direct DB tools, or migration-writing MCP fallbacks unless the task explicitly authorizes a documented fallback.
- Linked CLI operations are sequential; never run migration list, push, query, or advisors concurrently.
- Read-only linked checks may run only when task-relevant. Remote DDL, migration apply/repair, seed, cleanup, deploy, Storage mutation, TestOps execution writes, and destructive operations require explicit user approval.
- Never reset a database, weaken RLS, repair history speculatively, or place server secrets in iOS configuration.
- Read ignored credential files only with explicit authorization for that operation. Load secrets into process-local environment variables without logging them.
- Modern `sb_secret_...` and legacy JWT service-role behavior must follow the active backend/TestOps docs; never infer interchangeability.
- A linked auth/SASL failure is not permission to loop, repair, or switch writers. Follow the sequential recovery in `MIGRATION_RULES.md` and stop after its bounded check fails.

MCP/plugin tools are targeted fallbacks for task-relevant facts or planned validation. They do not authorize migration writes, exploratory DDL, or broad remote inspection. When tool output conflicts with repository truth, identify and resolve the conflict before writing.

## Authorization Matrix

| Operation | Authorization |
|---|---|
| Local reads/edits and mode-required local validation | Allowed within task scope. |
| Validated task-completion commit and push on the current work branch | Standing approval. |
| Incomplete checkpoint commit/push | Explicit user approval; conventions in `GITHUB_RULES.md`. |
| PR, merge/rebase/reset, force-push, tag, branch deletion, repository settings | Explicit user approval. |
| Supabase/TestOps/other non-Git remote write or destructive operation | Explicit user approval for the named operation. |
| Dependency, signing, entitlement, scheme, or capability change | Explicit approved task scope. |

If automatic completion push fails or is rejected, stop. Do not pull, rebase, merge, reset, force-push, or retry reconciliation automatically.
