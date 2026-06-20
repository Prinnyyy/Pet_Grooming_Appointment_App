# Migration Rules

## Current State

There is no `supabase/` directory and no migration history. T-003 does not initialize Supabase or create SQL. T-004 is the first task allowed to establish local Supabase scaffolding.

## Principles

- Make migrations small, ordered by the roadmap feature slice, and append-only after application.
- Never copy legacy project migrations or infer deployed schema from documentation.
- Inspect the installed Supabase CLI with `--help` before using version-sensitive commands.
- Create and validate schema changes locally before any authorized remote action.
- Keep tables, constraints, indexes, grants, RLS policies, functions, Storage policies, and `SUPABASE_CONTRACT.md` synchronized.
- Use explicit rollback/recovery reasoning for destructive or data-transforming changes; do not reset or repair a remote database without approval.

## Required Migration Content

For each exposed table or function, the owning task must review:

- Primary/foreign keys, uniqueness, check constraints, timestamps, and deletion behavior.
- Indexes required by product queries, conflict checks, and RLS predicates.
- RLS enablement and operation-specific policies.
- Data API schema exposure and explicit table/function grants or revokes.
- RPC security mode, safe search path, and execute privileges.
- Storage bucket and `storage.objects` policies when the feature uploads files.
- Positive, cross-user negative, and direct-write restriction tests.

## Before Creating a Migration

- Read existing migrations and verified project metadata.
- Confirm the task's exact tables/functions and exclude adjacent roadmap features.
- Confirm Auth identity, ownership, role, RLS, grant, and RPC requirements.
- Review current Supabase changelog/docs for relevant breaking changes.
- Confirm whether a local Supabase environment and CLI version are available.

## After Creating a Migration

- Inspect the generated SQL rather than trusting generation output.
- Run the task's explicit local backend validation plan, including `./scripts/supabase-check.sh` when configured.
- Test intended access and required negative cases with separate user identities.
- Run available database/security advisors for functions, views, RLS, and Storage.
- Update backend contract, feature index/current state when implementation state changes, and the task worklog.

## Remote Safety

- Remote apply, reset, repair, destructive DDL, bucket deletion, and policy removal require explicit user authorization.
- Never expose secret/service-role credentials in migrations, seed data, app configuration, logs, or documentation.
- Seed data is for authorized local/test environments only and must not create a production bypass path.

Current Supabase note: new tables may not be automatically exposed to the Data/GraphQL API, so every migration task must verify grants separately from RLS. See the [official changelog entry](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically).
