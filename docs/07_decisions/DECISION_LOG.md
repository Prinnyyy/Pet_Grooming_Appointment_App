# Decision Log

Use this for durable architecture/product decisions.

Do not store minor implementation details here.

## Format

```text
Date:
Decision:
Context:
Options considered:
Reason:
Consequences:
Linked files:
```

## Decisions

```text
Date: 2026-07-01
Decision: Separate Supabase CLI credentials from project API keys in all local runbooks.
Context: The local Supabase CLI is already authenticated and linked: `supabase projects list`, `supabase migration list --linked`, and `supabase db push --linked --dry-run` all succeed sequentially. A new ignored `supabase_environment_variables` file contains project URL/publishable/secret-key values, and the existing `supabase_api_key` value is a modern `sb_secret_...` project secret key.
Options considered: Ask for `SUPABASE_DB_PASSWORD` anyway; use `sb_secret_...` as `SUPABASE_SERVICE_ROLE_KEY`; or document the exact credential roles and keep the current CLI link as the normal path.
Reason: Supabase CLI login uses a PAT (`sbp_...`) and the linked DB credential is already saved locally, while modern `sb_secret_...` keys are not JWTs and fail when scripts send them as `Authorization: Bearer ...`.
Consequences: Do not request `SUPABASE_DB_PASSWORD` unless relinking, CI/no-keychain work, or a real DB-password failure requires it. Do not use `supabase_api_key`, `SUPABASE_SECRET_KEY`, or `sb_secret_...` for `supabase login`, `SUPABASE_SERVICE_ROLE_KEY`, or Bearer auth. Existing seed/TestOps scripts still require a JWT-shaped legacy service-role key unless updated for modern secret-key `apikey` semantics. Linked CLI commands remain sequential only.
Linked files: docs/05_workflow/TOOLING_POLICY.md, docs/03_backend/MIGRATION_RULES.md, docs/03_backend/SUPABASE_CONTRACT.md, docs/04_ios/testops/RUNBOOK.md, docs/04_ios/testops/TEST_CASES.md
```

```text
Date: 2026-07-01
Decision: Treat linked Supabase CLI commands as single-flight operations and inspect ignored Supabase credential files only under explicit authorization.
Context: Linked Supabase CLI commands repeatedly hit transient `cli_login_postgres` SASL/auth failures when multiple linked commands ran concurrently. Separately, authorized remote TestOps execution needed elevated verification/cleanup credentials, but local ignored credential files were not yet classified by credential type.
Options considered: Keep the blanket "never read local secrets" rule; always use MCP SQL instead of CLI/elevated env; or permit ignored local credential inspection under a narrow explicit-authorization boundary while keeping CLI as the normal migration path.
Reason: The repository still needs one canonical migration path through the installed Supabase CLI, but linked CLI commands must not be parallelized. Remote validation/test cleanup also needs a safe credential-handling path that does not leak secrets into code, docs, artifacts, or logs, and must not assume a local secret file is a JWT service-role key.
Consequences: Run linked `migration list`, `db push`, `db query`, and `db advisors` sequentially only. On `cli_login_postgres`/SASL failure, stop concurrent CLI work and verify with one sequential `supabase migration list --linked` before diagnosing drift or using repair. Ignored Supabase credential files may be inspected only after explicit user authorization for the current operation, and only into ephemeral environment variables. The current `supabase_api_key` is `sb_secret_...`, not a JWT service-role key. MCP SQL remains a fallback for read-only verification and explicitly tagged cleanup, not a migration path.
Linked files: docs/05_workflow/TOOLING_POLICY.md, docs/03_backend/MIGRATION_RULES.md, docs/03_backend/SUPABASE_CONTRACT.md, docs/00_memory/CURRENT_STATE.md, docs/06_tasks/TASK_LEDGER.md
```

```text
Date: 2026-07-01
Decision: Treat repository-local Supabase migration filenames as the canonical migration history and use `supabase db push --linked` as the normal remote deployment path.
Context: Historical remote/local timestamp drift for T-044/T-060/T-071/T-072 left four remote-only versions and four local-only versions in migration history, causing `supabase db push --linked --dry-run` to fail even though the schema was already represented locally.
Options considered: Keep using reviewed SQL transactions plus targeted `migration repair`; rename local migration files to remote-only versions; or repair remote history to match the existing repository-local canonical files.
Reason: The repository is the durable source of truth for this branch. Repairing remote history to match the existing local files restores Supabase CLI's intended migration model without changing business schema.
Consequences: Future Supabase work must run `supabase migration list --linked` and `supabase db push --linked --dry-run` before remote apply, use user-authorized `supabase db push --linked` for deployment, and re-run dry-run afterward until it reports `Remote database is up to date.` `supabase migration repair --linked` is recovery-only and requires root-cause evidence plus explicit task authorization. Linked Supabase CLI commands must be run sequentially.
Linked files: docs/03_backend/MIGRATION_RULES.md, docs/05_workflow/TOOLING_POLICY.md, docs/03_backend/SUPABASE_CONTRACT.md, docs/00_memory/CURRENT_STATE.md, docs/06_tasks/TASK_LEDGER.md
```

```text
Date: 2026-06-20
Decision: Pin Supabase Swift to 2.46.0 and inject only authorized-project publishable configuration through an ignored local xcconfig.
Context: T-005 required a buildable client/session boundary while T-004 remained paused and the repository contained an unread credential-named file.
Options considered: Hard-code configuration; use the legacy anon key; read the local key file; or retrieve the modern publishable key from the authorized Supabase project and inject it outside tracked source.
Reason: Exact dependency locking and build-time injection keep client code reproducible, prevent secret/service-role exposure, and let clean checkouts fail visibly at runtime without blocking compilation.
Consequences: SwiftUI never owns SupabaseClient; AppComposition owns client construction; the session repository exposes only user ID snapshots and auth-state changes, never tokens. T-004 schema remains undeployed and must not be queried.
Linked files: ios/PetGroomerMarketplace/Config/, Core/Configuration/, Core/Infrastructure/Supabase/, Core/Repositories/AuthSessionRepository.swift, docs/09_frozen/task_records_2026-06-26/T-005_IOS_SUPABASE_CLIENT_SESSION_BOUNDARY.md
```

```text
Date: 2026-06-25
Decision: Use Supabase CLI for every current and future Supabase task in this repository.
Context: Supabase CLI is installed, authenticated, and linked to the authorized `Pet Groomer Marketplace` project. The repository has a local migration mirror under `supabase/migrations/`.
Options considered: Use the installed Supabase CLI; mix CLI and MCP; or standardize on MCP.
Reason: One authenticated CLI execution path keeps remote target selection explicit and matches the repository-local migration workflow.
Consequences: Use the installed `supabase` binary, not `npx supabase`, for Supabase tasks. Apply reviewed remote DDL only with `supabase db push --linked` after user approval, verify with `supabase migration list --linked` and `supabase db query --linked`, run advisors with `supabase db advisors --linked`, and keep CLI-created migration files under `supabase/migrations/`. Linked CLI commands must not be parallelized. scripts/supabase-check.sh remains a static repository check only.
Linked files: docs/05_workflow/TOOLING_POLICY.md, docs/03_backend/MIGRATION_RULES.md, docs/09_frozen/task_records_2026-06-26/T-004_SUPABASE_PROFILE_FOUNDATION.md, docs/00_memory/CURRENT_STATE.md
```

```text
Date: 2026-06-19
Decision: Treat the existing non-Groomly Supabase project as a legacy project and create a separate new project for the fresh rebuild.
Context: The connected account already contains an older project. The user explicitly requires clean project isolation and placed an API key in the repository root for future authorized setup.
Options considered: Reuse or branch the legacy project; inspect and clean it; or create a new isolated project.
Reason: A new project prevents legacy schema, policies, data, migrations, and configuration from contaminating the fresh marketplace architecture.
Consequences: Ref swdiiyypysyxbnfrxxsv is forbidden as a migration or inspection target for this rebuild. The authorized replacement is `Pet Groomer Marketplace` ref `lqmasbuqzvcvtawonjlb` in `us-west-1`, created after confirmation of the reported US$0/month cost. The local `supabase_api_key` file is Git-ignored and may be read only under the explicit-authorization rules recorded on 2026-07-01; it must never enter app code or documentation content.
Linked files: docs/00_memory/CURRENT_STATE.md, docs/03_backend/SUPABASE_CONTRACT.md, docs/09_frozen/task_records_2026-06-26/T-002_INCREMENTAL_BUILD_ROADMAP.md, docs/06_tasks/TASK_LEDGER.md
```

```text
Date: 2026-06-19
Decision: Use the Fresh Brief's open-request marketplace as the sole product model; allow fixtures only in previews/tests; default user media to private or authenticated-readable access; defer favorites until a complete product contract exists.
Context: Active product/architecture/backend files were placeholders and still described a runtime demo adapter and an obsolete provider model. The Fresh Brief lists favorites without fields, screens, behavior, or acceptance criteria.
Options considered: Preserve the templates; add runtime local repositories; expose media publicly by default; invent a favorites schema; or align documents to the implemented baseline and planned verified Supabase boundaries.
Reason: The aligned model prevents parallel sources of truth, fake production success, unnecessary public media, and unsupported schema design.
Consequences: Production composition will use real repositories only; fixtures remain preview/test-only; Storage access is least-privilege by default; favorites requires a separately authorized product task.
Linked files: Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md, docs/01_product/, docs/02_architecture/, docs/03_backend/, docs/09_frozen/task_records_2026-06-26/T-002_INCREMENTAL_BUILD_ROADMAP.md
```
