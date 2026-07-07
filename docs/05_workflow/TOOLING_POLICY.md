# Tooling Policy

Use tools only when they reduce uncertainty, implement the requested scope, or verify the result.

## General Rules

1. Prefer existing repository scripts over invented commands.
2. Prefer read-only inspection before writes.
3. Keep file edits inside the active task scope.
4. Do not read or expose secrets.
5. Do not use destructive commands unless the user explicitly requests that operation.
6. Do not make remote writes without explicit user approval.
7. Do not add validation merely because a tool is available.

## Validation

- Micro Mode: no validation by default.
- Quick Mode: docs/workflow edits usually run `git diff --check`.
- Standard Mode: Swift, Xcode, app behavior, or visible UI changes run `git diff --check` and one `./scripts/ios-build.sh` attempt.
- Deep Mode: state a validation plan before implementation and make one planned validation attempt unless the user approves more.
- UI tests are not default.
- Unit tests are not default for initialization tasks.

If a required build, test, or diff check fails, report the first real error and stop unless the user approves a follow-up.

## File Editing

Edit only files required by the active task. If scope must expand, stop and update the plan before editing.

Review `git status` before edits and preserve unrelated user work.

## iOS and Xcode

Use documented scripts when validation is required:

- `./scripts/ios-build.sh`
- `./scripts/ios-test.sh`

Do not alter signing, capabilities, entitlements, schemes, project structure, or simulator assumptions unless explicitly planned.

## Supabase

Supabase CLI is the default interface for Supabase work. Use the installed `supabase` binary against the authorized linked project. Do not use `npx supabase`, local containers, direct database tools, or MCP migration writes unless a task explicitly documents that fallback.

Current local CLI readiness, verified on 2026-07-01:

- `supabase projects list` succeeds and shows `Pet Groomer Marketplace` / `lqmasbuqzvcvtawonjlb` as the linked active project.
- `supabase migration list --linked` succeeds and shows local/remote migrations aligned through `20260701050012`.
- `supabase db push --linked --dry-run` succeeds with `Remote database is up to date.`
- `SUPABASE_DB_PASSWORD` is not needed for normal local CLI work while the saved linked database credential remains valid. It is needed only for relinking, CI/no-keychain environments, or a real database-password auth failure.

Supabase credential taxonomy:

- `SUPABASE_ACCESS_TOKEN` / Dashboard PAT (`sbp_...`) is for `supabase login` and Management API access only. It is not a project API key and must not be committed.
- `SUPABASE_DB_PASSWORD` is the remote Postgres password used by `supabase link` or CI-style linked DB operations when the saved credential is unavailable.
- `SUPABASE_URL` plus `SUPABASE_PUBLISHABLE_KEY` are safe client configuration for the iOS app and authenticated user flows. The publishable key is public but still must be managed through ignored local config.
- `SUPABASE_SECRET_KEY` / `sb_secret_...` is a server-side project secret key. It is not a CLI login token, not a Postgres password, and not a JWT service-role key. Do not place it in `Authorization: Bearer ...`. TestOps supports it as an `apikey`-only server credential; scripts that have not been updated for `sb_secret_...` still need a legacy JWT-shaped service-role key.
- `SUPABASE_SERVICE_ROLE_KEY` can be a legacy JWT-shaped service-role key for scripts that send Bearer auth. In TestOps only, it may also contain a modern `sb_secret_...` server credential; TestOps detects that shape and sends it as `apikey` without an Authorization header. Seed scripts still expect the legacy JWT-shaped service-role key.

Linked Supabase CLI commands are single-flight operations. Do not run linked `supabase migration list`, `supabase db push`, `supabase db query`, or `supabase db advisors` in `multi_tool_use.parallel`, background jobs, separate terminals, or any other concurrent form. The CLI initializes a temporary `cli_login_postgres` role; concurrent linked commands can invalidate each other's temporary password and produce transient SASL/auth failures.

Migration workflow:

1. Create the migration with `supabase migration new <name>`.
2. Draft and review one task-scoped SQL change locally.
3. Run `supabase migration list --linked`; previous local and remote versions must match before applying new work.
4. Run `supabase db push --linked --dry-run`; it should show only the intended new migration, or `Remote database is up to date.` when there is nothing to apply.
5. Obtain explicit user approval for remote DDL.
6. Apply reviewed SQL only with `supabase db push --linked`.
7. Confirm version/name with `supabase migration list --linked`.
8. Re-run `supabase db push --linked --dry-run`; it must return `Remote database is up to date.`
9. Validate metadata and positive/negative authorization cases with `supabase db query --linked`.
10. Run advisors with `supabase db advisors --linked --type security` and `supabase db advisors --linked --type performance`.

`./scripts/supabase-check.sh` is a static repository check. It does not replace remote verification and must not mutate remote state.

Never reset databases, weaken RLS, repair migration history, expose service-role keys, or make remote schema/Storage writes without explicit task authorization. `supabase migration repair --linked` is permitted only as a documented recovery step after `migration list` proves drift and each mismatched version is mapped to a known local canonical migration.

Ignored local credential files include `supabase_api_key`, `supabase_environment_variables`, and `ios/PetGroomerMarketplace/Config/Supabase.local.xcconfig`. They may be inspected only after explicit user authorization for the specific operation. Read secrets into process-local environment variables only; do not print them, write them into tracked files, pass them through verbose logs, or embed secret keys in iOS app configuration. Current local `supabase_api_key` content has been identified as `sb_secret_...`; do not use it as a CLI PAT, DB password, or JWT service-role key. TestOps may use it only through the modern `apikey`-only server credential path.

If a linked CLI command fails with `cli_login_postgres` or SASL/auth errors, do not retry in a loop and do not run `migration repair`. Stop parallel Supabase work, wait briefly, then run exactly one sequential `supabase migration list --linked`. If that succeeds and shows aligned Local/Remote versions, treat the earlier failure as transient CLI login-role contention. If it fails twice sequentially, capture the first error, check `supabase --version`, and switch to the documented MCP/SQL fallback only for read-only verification or explicitly tagged cleanup.

MCP SQL is allowed for read-only verification and explicitly tagged cleanup when CLI auth/env setup is the blocker. MCP must not be used to apply migrations, repair migration history, or perform exploratory DDL unless a task explicitly authorizes that fallback and records the reason.

## MCP and Plugin Tools

Prefer local repository files first. Use MCP or plugin tools only for task-relevant facts or planned validation.

- Quick Mode: no MCP by default.
- Standard Mode: use MCP only when local context cannot answer a task-relevant question or it performs the planned validation.
- Deep Mode: use targeted MCP for explicitly planned backend/platform investigation.

If tool output conflicts with repository files, identify the conflict and prefer repository files unless they are demonstrably stale.

## Git and GitHub

Read-only commands such as `git status`, `git diff`, and `git log` are allowed.

Commit, push, reset, rebase, PR creation, merge, branch deletion, and repository-setting changes require explicit user approval.

Commit-message, branch, PR, tag, and `main` reconciliation conventions live in `GITHUB_RULES.md`.

When committing or pushing, include a concise traceability record in the user-facing closeout: what changed, why it changed, validation run, known risks, branch, and commit/push result.

## Superpowers

Superpowers is optional.

- Use at most one directly relevant capability when it is clearly useful.
- Skip Superpowers when no capability directly helps the current task.
- Do not let Superpowers expand task scope.
- Do not add subagents, extra reviews, validation loops, branches, commits, pushes, or PR workflows merely because a skill exists.

Repository instructions and explicit user limits remain authoritative.
