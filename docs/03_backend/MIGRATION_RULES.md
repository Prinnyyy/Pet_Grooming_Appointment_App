# Migration Rules

Use this file for Supabase migration workflow. It is an operating protocol, not migration history.

Archived pre-trim version: `../09_frozen/backend_policies/MIGRATION_RULES_2026-07-02_PRE_INDEX_TRIM.md`.

## Current Boundary

- Authorized project: `Pet Groomer Marketplace`, ref `lqmasbuqzvcvtawonjlb`.
- Legacy project ref `swdiiyypysyxbnfrxxsv` is out of scope and must not be inspected or mutated.
- Local migration mirror: `../../supabase/migrations/`.
- Normal remote DDL path: installed `supabase` CLI with the linked project.
- Linked CLI baseline was verified on 2026-07-01: project list, migration list, and dry-run push succeeded sequentially.

## Principles

- Create migrations with `supabase migration new <name>`; never invent timestamped filenames by hand.
- Keep migrations small, task-scoped, append-only after application, and synchronized with backend policy docs.
- Never copy legacy project migrations or infer deployed schema from documentation.
- Review tables, constraints, indexes, grants, RLS policies, RPC security, Storage policies, and negative tests before remote apply.
- Linked Supabase CLI commands are single-flight operations. Do not run linked `migration list`, `db push`, `db query`, or advisors in parallel.
- Remote DDL, migration repair, seed execution, cleanup, destructive operations, and remote writes require explicit user approval.

## Standard Flow

1. Confirm the task's exact backend scope and exclude adjacent work.
2. Inspect relevant existing migrations and active backend policy docs.
3. Create a migration with `supabase migration new <name>`.
4. Draft and review one task-scoped SQL change locally.
5. Run `supabase migration list --linked`; previous local and remote versions must match.
6. Run `supabase db push --linked --dry-run`; it should show only the intended new migration.
7. Obtain explicit user approval for remote DDL.
8. Apply with `supabase db push --linked`.
9. Confirm with `supabase migration list --linked`.
10. Re-run `supabase db push --linked --dry-run`; it must return `Remote database is up to date.`
11. Verify metadata and positive/negative authorization cases with `supabase db query --linked`.
12. Run security/performance advisors when functions, views, RLS, or Storage policies changed.

`./scripts/supabase-check.sh` is a static repository check. It does not replace remote verification and must not mutate remote state.

## Credential Rules

- `SUPABASE_ACCESS_TOKEN=sbp_...`: CLI login / Management API token only.
- `SUPABASE_DB_PASSWORD`: remote Postgres password for relinking, CI/no-keychain work, or real DB-password failures.
- `SUPABASE_URL` plus `SUPABASE_PUBLISHABLE_KEY`: safe client configuration for authenticated user flows.
- `SUPABASE_SECRET_KEY=sb_secret_...`: server-side project secret key; not a CLI PAT, DB password, JWT, or Bearer token.
- `SUPABASE_SERVICE_ROLE_KEY=eyJ...`: legacy JWT-shaped service-role key for scripts that still send Bearer auth.

TestOps supports modern `sb_secret_...` credentials as `apikey`-only server credentials. Seed scripts still expect a JWT-shaped legacy service-role key.

Ignored local credential files may be inspected only after explicit user authorization for the current operation. Read secrets into process-local environment variables only; do not print, commit, log, or write them into tracked files.

## Recovery Rules

- If a linked CLI command reports `cli_login_postgres` or SASL/auth errors, stop concurrent Supabase work and run one sequential `supabase migration list --linked`.
- If sequential migration list succeeds and Local/Remote align, treat the earlier failure as transient CLI login-role contention.
- Use `supabase migration repair --linked` only after migration list proves real drift, each mismatched version is mapped to a known local canonical migration, and the user explicitly authorizes repair.
- MCP SQL is allowed only for read-only verification or explicitly tagged cleanup when CLI auth/env setup is the blocker. It is not a migration path.
- Never reset databases, weaken RLS, perform exploratory DDL, expose service-role keys, or mutate the legacy project.

Official note: new tables may not be automatically exposed to Data/GraphQL APIs; every migration task must verify grants separately from RLS.
