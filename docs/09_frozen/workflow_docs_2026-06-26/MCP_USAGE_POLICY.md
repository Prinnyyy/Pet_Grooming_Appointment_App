# MCP Usage Policy

## Purpose

MCP tools are useful but can expand scope quickly. Use them only when they reduce uncertainty or improve validation.

## General Rules

- Prefer local repository files first.
- Use MCP only for task-relevant facts or budgeted validation.
- Do not browse unrelated context.
- Do not perform MCP writes without explicit authorization.
- If MCP output conflicts with repository files, identify the conflict and prefer repository files unless they are stale.

Mode budget:

- Quick: no MCP by default.
- Standard: use MCP only when local context cannot answer a task-relevant question or it performs the planned validation.
- Deep: use targeted MCP for explicitly planned backend/platform investigation.

## Xcode MCP

Allowed for scheme/simulator discovery, build/test execution, and structured build errors. Do not alter signing, capabilities, entitlements, or project structure unless explicitly planned.

## Supabase CLI

Supabase CLI is the default interface for every Supabase task. Use the installed `supabase` binary against the authorized linked project. Do not use `npx supabase`, local containers, or direct database tooling unless a task explicitly documents that fallback.

Use Supabase CLI for project inspection, migrations, focused SQL verification, Storage/RLS/policy checks, and advisors.

Migration workflow:

1. Create the migration with `supabase migration new <name>`.
2. Draft and review one task-scoped SQL change locally.
3. Obtain explicit user approval for the remote DDL.
4. Apply reviewed SQL only with `supabase db push --linked` against the authorized project ref.
5. Confirm the recorded version/name with `supabase migration list --linked`.
6. Validate metadata and positive/negative authorization cases with `supabase db query --linked`.
7. Run advisors with `supabase db advisors --linked --type security` and `supabase db advisors --linked --type performance`.

`./scripts/supabase-check.sh` is a repository static check only. It does not replace Supabase CLI remote verification and must not mutate a remote database.

Never use Supabase CLI for destructive schema changes, RLS weakening, migration repair, or secret inspection without explicit task authorization. Remote Supabase writes require explicit user approval. Do not read local credential files when the CLI or Dashboard can provide the required non-secret project fact.

## GitHub MCP

Use for reading issues, PRs, CI status, and remote diffs. Do not push branches, merge PRs, change repository settings, modify secrets, or delete branches.

## Escalation Rule

If an MCP tool is needed for a high-risk write action, stop and ask the user.
