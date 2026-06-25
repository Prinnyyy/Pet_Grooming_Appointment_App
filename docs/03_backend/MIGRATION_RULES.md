# Migration Rules

## Current State

The repository-local `supabase/migrations/` mirror exists for approved Supabase tasks. The authorized fresh project is managed through Supabase CLI. A local Supabase container runtime is required only for tasks that explicitly validate against a local stack.

## Principles

- Make migrations small, ordered by the roadmap feature slice, and append-only after application.
- Never copy legacy project migrations or infer deployed schema from documentation.
- Use Supabase CLI for project inspection, migration application, SQL verification, migration history, and advisors. Prefer the installed `supabase` binary; do not use `npx supabase` or direct database tools unless a task explicitly documents that fallback.
- Draft and review the full task-scoped SQL locally before any authorized remote write.
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
- Confirm the authorized linked project ref with `supabase projects list` or `supabase migration list --linked`, and explicitly exclude every legacy ref.
- Create new migration files with `supabase migration new <name>`; never invent timestamped filenames by hand.
- Confirm user approval for remote DDL before running `supabase db push --linked`.

## After Creating a Migration

- Confirm the applied migration version/name through `supabase migration list --linked`.
- Keep the exact CLI-created migration file under `supabase/migrations/`; never invent, renumber, or repair remote history.
- Run `./scripts/supabase-check.sh` as a repository static check when configured.
- Test intended access and required negative cases with `supabase db query --linked` using separate user identities or equivalent transaction-local claims that roll back.
- Run `supabase db advisors --linked --type security` and `supabase db advisors --linked --type performance` for functions, views, RLS, and Storage.
- Update backend contract, feature index/current state when implementation state changes, and the task worklog.

## Remote Safety

- `supabase db push --linked` is the authorized remote migration path. Remote apply, reset, repair, destructive DDL, bucket deletion, and policy removal require explicit user authorization.
- Do not use exploratory DDL through `supabase db query --linked`; prepare one reviewed migration and apply it once.
- Never expose secret/service-role credentials in migrations, seed data, app configuration, logs, or documentation.
- Seed data is for authorized local/test environments only and must not create a production bypass path.

Current Supabase note: new tables may not be automatically exposed to the Data/GraphQL API, so every migration task must verify grants separately from RLS. See the [official changelog entry](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically).
