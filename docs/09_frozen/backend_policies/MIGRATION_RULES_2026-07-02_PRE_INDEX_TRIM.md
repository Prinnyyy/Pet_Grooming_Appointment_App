# Migration Rules

## Current State

The repository-local `supabase/migrations/` mirror exists for approved Supabase tasks. The authorized fresh project is managed through Supabase CLI. A local Supabase container runtime is required only for tasks that explicitly validate against a local stack.

T-128 repaired historical remote/local migration-version drift in `supabase_migrations.schema_migrations`: remote-only versions `20260622212214`, `20260624022107`, `20260625073709`, and `20260625080102` were reverted from migration history, and the local canonical versions `20260622142020`, `20260624021122`, `20260625073116`, and `20260625075813` were marked applied. `supabase migration list --linked` now shows every local version matched by remote, and `supabase db push --linked --dry-run` returns `Remote database is up to date.`

T-139 reconfirmed the local Supabase CLI credential state: `supabase projects list`, `supabase migration list --linked`, and `supabase db push --linked --dry-run` all succeed sequentially. The current machine does not need `SUPABASE_DB_PASSWORD` for normal linked CLI work because the saved linked database credential is already valid.

## Principles

- Make migrations small, ordered by the roadmap feature slice, and append-only after application.
- Never copy legacy project migrations or infer deployed schema from documentation.
- Use Supabase CLI for project inspection, migration application, SQL verification, migration history, and advisors. Prefer the installed `supabase` binary; do not use `npx supabase` or direct database tools unless a task explicitly documents that fallback.
- Treat linked Supabase CLI commands as single-flight operations. Do not run linked migration, push, query, or advisor commands in parallel.
- Draft and review the full task-scoped SQL locally before any authorized remote write.
- Keep tables, constraints, indexes, grants, RLS policies, functions, Storage policies, and `SUPABASE_CONTRACT.md` synchronized.
- Use explicit rollback/recovery reasoning for destructive or data-transforming changes; do not reset or repair a remote database without approval and root-cause evidence.

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
- Run `supabase migration list --linked` before remote migration work. The Local and Remote columns must match through the previous deployed migration before applying new work.
- Run `supabase db push --linked --dry-run` before remote DDL. The expected clean-state output is `Remote database is up to date.`; after adding a new approved migration, the dry-run should list only that new migration.
- Confirm user approval for remote DDL before running `supabase db push --linked`.
- Do not source `supabase_environment_variables` for CLI login. `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, and `SUPABASE_JWKS_URL` are not substitutes for the CLI PAT or saved linked database credential.

## After Creating a Migration

- Confirm the applied migration version/name through `supabase migration list --linked`.
- Re-run `supabase db push --linked --dry-run` after apply; it must return `Remote database is up to date.`
- Keep the exact CLI-created migration file under `supabase/migrations/`; never invent or renumber migration filenames after they are applied.
- Run `./scripts/supabase-check.sh` as a repository static check when configured.
- Test intended access and required negative cases with `supabase db query --linked` using separate user identities or equivalent transaction-local claims that roll back.
- Run `supabase db advisors --linked --type security` and `supabase db advisors --linked --type performance` for functions, views, RLS, and Storage.
- Update backend contract, feature index/current state when implementation state changes, and the task worklog.

## Remote Safety

- `supabase db push --linked` is the authorized remote migration path. Remote apply, reset, repair, destructive DDL, bucket deletion, and policy removal require explicit user authorization.
- `supabase migration repair --linked` is a recovery tool, not a normal deployment step. Use it only when `supabase migration list --linked` proves migration history drift, after mapping each mismatched version to a known local canonical migration and confirming the schema is already represented locally.
- Run linked Supabase CLI commands sequentially. Concurrent linked commands can race while initializing `cli_login_postgres`, invalidate another command's temporary login, and produce transient SASL/auth failures.
- If a linked command reports `cli_login_postgres` or SASL/auth failure, first stop all concurrent Supabase CLI work and run one sequential `supabase migration list --linked`. If Local and Remote still align, record the earlier error as transient CLI login-role contention rather than migration drift. Run `supabase migration repair --linked` only when sequential `migration list` proves a real history mismatch.
- The ignored local `supabase_api_key` and `supabase_environment_variables` files are allowed only for explicitly authorized credential inspection or remote seed/test/cleanup operations. Never print their values, store them in tracked docs/code, embed secret values in app configuration, or include them in artifacts.
- `sb_secret_...` and `sb_publishable_...` keys are not JWTs. Do not pass either as `Authorization: Bearer ...` and do not use either for `supabase login`. TestOps supports `sb_secret_...` through an `apikey`-only server credential path; seed scripts and any other scripts that still expect a legacy JWT-shaped service-role key must not receive `sb_secret_...`.
- `SUPABASE_ACCESS_TOKEN=sbp_...` is the CLI login token; `SUPABASE_DB_PASSWORD` is only for relinking or environments where the saved database password is unavailable.
- MCP SQL may be used for read-only verification and explicitly tagged cleanup when CLI auth/env setup is the blocker. It is not a normal migration path and must not be used for exploratory DDL.
- Do not use exploratory DDL through `supabase db query --linked`; prepare one reviewed migration and apply it once.
- Never expose secret/service-role credentials in migrations, seed data, app configuration, logs, or documentation.
- Seed data is for authorized local/test environments only and must not create a production bypass path.

Current Supabase note: new tables may not be automatically exposed to the Data/GraphQL API, so every migration task must verify grants separately from RLS. See the [official changelog entry](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically).
