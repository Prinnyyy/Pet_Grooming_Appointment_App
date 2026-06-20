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

Mode budget:

- Quick Mode: no MCP by default.
- Standard Mode: use one only when local context cannot answer a task-relevant question or it directly performs budgeted validation.
- Deep Mode: use targeted MCP tools for explicitly planned backend/platform investigation.

Do not use MCP merely because it is available, and do not let it add scope or validation steps.

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

Supabase MCP is the exclusive project interface for every Supabase task. Do not install or invoke the Supabase CLI, `npx supabase`, a local Supabase container stack, or direct database tooling for this repository.

Use Supabase MCP for:

- organization, cost, and project operations,
- current documentation lookup,
- project, migration, table, extension, RPC, policy, and Storage inspection,
- reviewed migrations through `apply_migration`,
- focused SQL verification through `execute_sql`,
- security and performance advisors.

Migration workflow:

1. Draft and review one task-scoped SQL change locally.
2. Obtain explicit user approval for the remote DDL.
3. Apply the reviewed SQL only with MCP `apply_migration` against the authorized project ref.
4. Confirm the recorded version/name with MCP migration inspection.
5. Store an exact repository-local mirror using the version reported by MCP; never invent or renumber remote migration history.
6. Validate deployed metadata, positive/negative authorization cases, and advisors through MCP.

`./scripts/supabase-check.sh` is a repository static check only. It does not replace MCP verification and must not invoke a CLI or remote database directly.

Do not use for:

- destructive schema changes,
- RLS weakening,
- migration repair,
- secret inspection.

Remote Supabase writes, including non-destructive DDL, require explicit user approval. The MCP OAuth connection is the execution identity; local credential files must not be read or used when MCP can perform the task.

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
