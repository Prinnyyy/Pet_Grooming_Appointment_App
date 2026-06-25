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
Date: 2026-06-20
Decision: Pin Supabase Swift to 2.46.0 and inject only authorized-project publishable configuration through an ignored local xcconfig.
Context: T-005 required a buildable client/session boundary while T-004 remained paused and the repository contained an unread credential-named file.
Options considered: Hard-code configuration; use the legacy anon key; read the local key file; or retrieve the modern publishable key from the authorized Supabase project and inject it outside tracked source.
Reason: Exact dependency locking and build-time injection keep client code reproducible, prevent secret/service-role exposure, and let clean checkouts fail visibly at runtime without blocking compilation.
Consequences: SwiftUI never owns SupabaseClient; AppComposition owns client construction; the session repository exposes only user ID snapshots and auth-state changes, never tokens. T-004 schema remains undeployed and must not be queried.
Linked files: ios/PetGroomerMarketplace/Config/, Core/Configuration/, Core/Infrastructure/Supabase/, Core/Repositories/AuthSessionRepository.swift, docs/06_tasks/T-005_IOS_SUPABASE_CLIENT_SESSION_BOUNDARY.md
```

```text
Date: 2026-06-25
Decision: Use Supabase CLI for every current and future Supabase task in this repository.
Context: Supabase CLI is installed, authenticated, and linked to the authorized `Pet Groomer Marketplace` project. The repository has a local migration mirror under `supabase/migrations/`.
Options considered: Use the installed Supabase CLI; mix CLI and MCP; or standardize on MCP.
Reason: One authenticated CLI execution path keeps remote target selection explicit and matches the repository-local migration workflow.
Consequences: Use the installed `supabase` binary, not `npx supabase`, for Supabase tasks. Apply reviewed remote DDL only with `supabase db push --linked` after user approval, verify with `supabase migration list --linked` and `supabase db query --linked`, run advisors with `supabase db advisors --linked`, and keep CLI-created migration files under `supabase/migrations/`. scripts/supabase-check.sh remains a static repository check only.
Linked files: docs/05_workflow/MCP_USAGE_POLICY.md, docs/03_backend/MIGRATION_RULES.md, docs/06_tasks/T-004_SUPABASE_PROFILE_FOUNDATION.md, docs/00_memory/CURRENT_STATE.md
```

```text
Date: 2026-06-19
Decision: Treat the existing non-Groomly Supabase project as a legacy project and create a separate new project for the fresh rebuild.
Context: The connected account already contains an older project. The user explicitly requires clean project isolation and placed an API key in the repository root for future authorized setup.
Options considered: Reuse or branch the legacy project; inspect and clean it; or create a new isolated project.
Reason: A new project prevents legacy schema, policies, data, migrations, and configuration from contaminating the fresh marketplace architecture.
Consequences: Ref swdiiyypysyxbnfrxxsv is forbidden as a migration or inspection target for this rebuild. The authorized replacement is `Pet Groomer Marketplace` ref `lqmasbuqzvcvtawonjlb` in `us-west-1`, created after confirmation of the reported US$0/month cost. The local supabase_api_key file remains unread and Git-ignored and must never enter app code or documentation content.
Linked files: docs/00_memory/CURRENT_STATE.md, docs/03_backend/SUPABASE_CONTRACT.md, docs/06_tasks/T-002_INCREMENTAL_BUILD_ROADMAP.md, docs/06_tasks/TASK_LEDGER.md
```

```text
Date: 2026-06-19
Decision: Use the Fresh Brief's open-request marketplace as the sole product model; allow fixtures only in previews/tests; default user media to private or authenticated-readable access; defer favorites until a complete product contract exists.
Context: Active product/architecture/backend files were placeholders and still described a runtime demo adapter and an obsolete provider model. The Fresh Brief lists favorites without fields, screens, behavior, or acceptance criteria.
Options considered: Preserve the templates; add runtime local repositories; expose media publicly by default; invent a favorites schema; or align documents to the implemented baseline and planned verified Supabase boundaries.
Reason: The aligned model prevents parallel sources of truth, fake production success, unnecessary public media, and unsupported schema design.
Consequences: Production composition will use real repositories only; fixtures remain preview/test-only; Storage access is least-privilege by default; favorites requires a separately authorized product task.
Linked files: Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md, docs/01_product/, docs/02_architecture/, docs/03_backend/, docs/06_tasks/T-002_INCREMENTAL_BUILD_ROADMAP.md
```
