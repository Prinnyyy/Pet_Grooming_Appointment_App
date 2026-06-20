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
Date: 2026-06-19
Decision: Treat the Supabase project currently visible through MCP as a legacy project and create a separate new project for the fresh rebuild.
Context: The connected account already contains an older project. The user explicitly requires clean project isolation and placed an API key in the repository root for future authorized setup.
Options considered: Reuse or branch the legacy project; inspect and clean it; or create a new isolated project.
Reason: A new project prevents legacy schema, policies, data, migrations, and configuration from contaminating the fresh marketplace architecture.
Consequences: Ref swdiiyypysyxbnfrxxsv is forbidden as a migration or inspection target for this rebuild. Project creation must use an explicitly selected organization and confirmed cost. The local supabase_api_key file remains unread and Git-ignored and must never enter app code or documentation content.
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
