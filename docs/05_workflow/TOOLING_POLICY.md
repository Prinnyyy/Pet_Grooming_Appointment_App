# Tooling Policy

## General

- Prefer existing project scripts over invented commands.
- Use read-only commands while planning.
- Keep writes inside the active task scope.
- Do not read or log secrets.
- Do not add dependencies unless the user explicitly approves.

## Validation

- Docs/workflow-only: `git diff --check`; context hygiene when memory/ledger changed.
- Swift/Xcode/app behavior: `git diff --check` plus one `./scripts/ios-build.sh`.
- Tests: use `./scripts/ios-test.sh` or targeted `xcodebuild` only when relevant.
- Supabase/backend: state a plan first; use `./scripts/supabase-check.sh` for static local checks when relevant.

Stop on the first required validation failure unless the user approves a follow-up.

## Supabase

- Read local docs and migrations before assuming schema facts.
- Remote writes, migrations, seeds, cleanup, reset, repair, and destructive SQL require explicit user approval.
- Use the authorized fresh project only: `lqmasbuqzvcvtawonjlb`.
- Do not inspect or mutate the legacy project as a source of truth.
- Do not expose service-role keys, API keys, passwords, or local environment files.
- Scripts that need legacy JWT credentials and scripts that support `SUPABASE_SECRET_KEY=sb_secret_...` must document that difference locally before use.

## Git And GitHub

- `git status`, `git diff`, and `git log` are allowed.
- Commit, push, branch changes, reset, rebase, PR creation, merge, and repository-setting changes require explicit user approval.
- Stage only intended files. Never stage local credential-class files or generated artifacts by accident.

## Local Files To Avoid

Do not read, print, or commit:

- `supabase_api_key`
- `supabase_environment_variables`
- `ios/PetGroomerMarketplace/Config/Supabase.local.xcconfig`
- `supabase/.temp/**`
- generated artifacts under `artifacts/**`
