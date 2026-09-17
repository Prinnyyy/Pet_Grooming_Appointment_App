# Development Guide

Read only the section relevant to the current operation. [AGENTS.md](../../AGENTS.md) is the entry; host instructions and explicit user scope prevail. This guide is model-independent and does not override required host skills.

## Task And Recovery

- An implementation, governed rule change or requested durable audit gets the next ID from [Current State](../00_memory/CURRENT_STATE.md). Read-only questions, isolated test runs and ordinary progress updates do not allocate IDs or require reports.
- Continue the adopted objective through implementation and required acceptance. Small steps, work packages and task IDs are not session boundaries. Keep unrelated findings out of the critical path; add an existing roadmap pointer only when the finding merits future work. Do not execute another goal automatically.
- Current State contains one JSON block: `next_task_id`, nullable `task`, `pending_tasks`, and nullable `last_completed` containing only `id`. Task records require `id`, `status`, `goal`, nullable `plan`, and `next_action`. Status is planned/active/paused/blocked; pending records cannot be active. IDs are unique and next ID exceeds all allocated IDs; never reuse a reserved ID.
- Each task may carry concise `authorization`, `blockers`, `preserve` string arrays and `verification` entries (`scope`, `command`, `basis`, `result`, `evidence`). Omit empty optional fields. Authorization records prior user scope; it grants nothing itself. Store pointers instead of duplicate logs, source copies or secrets.
- Before switching an unfinished task, move its record to pending, changing active to paused. Preserve its next action, authorization and evidence. Resume the same record/ID when requested; do not transfer one task's authorization to another. Read-only interruptions do not switch tasks.
- Update state at meaningful changes, before an intentional interruption, and at completion; not after every tool call. On recovery, inspect Git status/diff, the state record and the indicated plan/evidence only. Do not reconstruct archive/chat chains or require manual compaction. Respect host-managed context limits and leave a truthful checkpoint if forced to stop.
- After acceptance, clear the completed task record and replace `last_completed.id`. Git supplies branch, dirty state and completion hashes; query by the `T-###:` commit subject, not a self-referencing hash in Markdown. A missing commit or failed push remains explicit.

## Decisions And Stops

Use ordinary engineering judgment within adopted scope. Resolve document/code drift through the smallest relevant evidence; code does not automatically override product policy or security intent. Stop only for a user pause, a completed objective, an unsafe unresolved conflict, missing indispensable input/authorization, or an external condition that cannot be resolved safely.

Expected development RED is not a completion failure. Diagnose before retrying; each attempt needs new evidence or a relevant correction. Stop unchanged repetition, not after an arbitrary retry count. Report the actual failure, affected work and precise missing condition without pretending work continues in the background.

Record durable product/architecture/workflow decisions in [Decision Log](../07_decisions/DECISION_LOG.md). Governance changes stay separate from unrelated feature work and include affected consumers plus hygiene. No periodic task-count, weekly review or automatic archive gate remains. Review rules when actual friction, contradictions or user requests warrant it: identify the concrete failure, remove duplicated authority, check information preservation and keep only necessary validation.

## Validation

| Change | Required evidence |
|---|---|
| Read-only discussion | Verify only the facts being answered; no lifecycle/closeout gate. |
| Docs/rules | Relevant links and state; `node scripts/context-hygiene-check.mjs` and diff review. Changed checkers also need behavior tests. |
| Local client behavior | Focused tests; compilation changes need `./scripts/ios-build.sh`; interaction changes need appropriate runtime evidence. |
| Shared Store/repository/DesignSystem or integration | Relevant integrated/full regression via `./scripts/ios-test.sh`, plus runtime evidence required by the acceptance scope. |
| Backend/security | Verify affected current definitions and authorization, then relevant negative, concurrency, transaction and restoration evidence. Local tests do not prove remote deployment. |

Run `./scripts/preflight.sh` at applicable integration/completion nodes; it preserves local brand/UI/migration/function checks, not a remote validation substitute. Commands and overrides for iOS live in [Build And Testing](../04_ios/IOS_BUILD_AND_TESTING.md). Reuse passing results only when relevant code/configuration/environment and test coverage are unchanged. Report failures, skips, user-deferred visual validation and evidence limits separately. Never modify dates merely to pass a gate.

Simulator is sufficient for the adopted local app scope. Physical hardware, signing, store release and APNs deployment are not local completion gates. Run Simulator for changed interaction or required runtime acceptance, not documentation. Keep Xcode writers serial. Sample task-relevant logs before expanding; distinguish app diagnostics from toolchain noise.

## Backend And Credentials

Read the [Backend Contract](../03_backend/SUPABASE_CONTRACT.md) and affected definitions only when needed; [Migration Rules](../03_backend/MIGRATION_RULES.md) owns credential taxonomy and linked CLI recovery, [TestOps Runbook](../04_ios/testops/RUNBOOK.md) owns test commands.

- Beckon is the authorized project; the legacy project is excluded. Project identification does not authorize writes.
- Use installed Supabase CLI; linked commands are sequential. No alternate writers, containers or speculative migration repair as a workaround without explicit scoped authorization.
- Remote DDL, migrations, deploys, seeds, cleanup, Storage writes, account mutations and destructive operations require explicit user authorization. Preserve RLS/grants and immutable applied migrations. Restore authorized test data and prove cleanup.
- Read ignored credentials only when explicitly authorized for that operation. Load them into process-local environment without logging or committing them; never put server credentials in iOS. Modern secret keys and JWT service-role keys are not interchangeable.
- Auth/SASL failures require the bounded read-only diagnosis in Migration Rules, not repeated writes or an automatic switch of writer.

## Git And User Work

Work on the current user-selected branch; new branches use `codex/` only when needed within authorized scope. Do not merge the reviewed superseded main-only commit `2fddf7b`, switch branches or reconcile merely because another branch appears newer. Canonical remote is `Prinnyyy/Pet_Grooming_Appointment_App`.

Inspect unstaged/staged differences and keep existing user changes. Use named files/hunks, never blanket stage/reset/stash. For a governed rewrite of dirty material, preserve the actual pre-edit content; HEAD is not its backup. Restore only task-owned changes, retaining later user edits. Roll back coupled rules/checkers together; published corrections are forward commits, never history rewriting.

After the whole objective passes required acceptance, standing approval permits a scoped completion commit and push on the current work branch. Subject: `T-###: <type>: <specific summary>`; types feat/fix/docs/chore/test/migration. Include that objective's implementation, tests and necessary state. Check staged diff and push only the committed branch. On push rejection/failure, report it; do not automatically pull, rebase, merge, force-push or retry reconciliation.

Incomplete checkpoint commits/pushes, PRs, tags, merges/rebases/resets, branch deletion and repository settings need explicit approval. Dependencies, signing, schemes, entitlements and new capabilities also require adopted scope. A paused task can have a local state checkpoint without a Git checkpoint commit.

## Documentation And Search

[Docs Index](../README.md) routes domain contracts; [Feature Index](../00_memory/FEATURE_INDEX.md) routes code. Stable facts belong there, not in task status. [Roadmap](../06_tasks/ROADMAP.md) holds unadopted/deferred product directions. Worklog/ledger and superseded workflow snapshots are historical, not daily write targets.

Keep completed plans/evidence at stable paths; no automatic rotation, backlinks rewrite or per-task report is required. [Task Artifacts](../superpowers/README.md) describes plan metadata. Real links in active navigation must resolve after moves. Backtick examples and historical path tables are not executable references.

Hygiene is read-only: default checks core/state and changed/untracked visible Markdown, plus the current plan and changed task artifacts even when search-hidden. `--full` adds all visible docs; deletes/search-boundary changes widen inspection to catch unchanged backlinks. `--json` emits `ok`, `errors`, `warnings`, `checkedFiles`; exits are 0 success, 1 invalid content/path, 2 invocation/environment failure. It requires existing Node, Git and rg, not new dependencies. Run full checks at final integration or when link/search scope changes, not after every step.

Search exclusions do not grant permission. Current plans must be safe repository Markdown; pending plans are existence-checked until resumed. Never load frozen/seed/export/heavy UI, credentials or external symlink targets through a plan pointer. Inspect named historical evidence only for an explicit recovery/comparison purpose outside the general checker. Link checks do not recursively read targets or assert that backend/product claims are correct; those require domain review.
