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
