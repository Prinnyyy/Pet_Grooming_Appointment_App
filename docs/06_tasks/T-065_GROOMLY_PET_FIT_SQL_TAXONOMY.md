# T-065 - Groomly Pet-Fit SQL Taxonomy

## Status

Completed.

## Mode

Deep.

## User Request

Continue T-065 after T-064 completed the local Swift pet-fit taxonomy foundation.

## Primary Task

Add the SQL-side pet-fit taxonomy derivation foundation for later request-first matching evidence:

- breed group derivation
- weight-based size band derivation
- care flag derivation
- service-fit trait derivation
- request snapshot trait rows for future evidence and scoring tasks

## Out of Scope

- Replacing or extending `create_grooming_request`.
- Changing matching score or match reason behavior.
- Adding groomer claim tables, portfolio tags, structured reviews, evidence summary views, UI surfacing, or availability enforcement.
- Deploying the unrelated T-050 pet fixed taxonomy migration.
- Public groomer directory browsing, direct customer slot booking, AI/ML recommendations, payments, or calendar enforcement.

## Existing Mapping

- T-064 added the Swift source of truth in `GroomingRequestTaxonomy.swift`.
- T-065 mirrors that vocabulary in private SQL helpers under `app_private`.
- Current request snapshots already carry `breed`, `weight_lbs`, `temperament`, and `birthday` in `grooming_requests.pet_snapshot`.
- T-050 remains a local draft only, so T-065 must not depend on `app_private.pet_size_code_for_weight_lbs(...)` being deployed.

## Implementation Plan

1. Verify the SQL helpers do not exist yet with a read-only RED query.
2. Apply one reviewed Supabase MCP migration to the fresh project `lqmasbuqzvcvtawonjlb`.
3. Save the applied migration as a local mirror under `supabase/migrations/`.
4. Verify SQL mapping behavior, function privileges, migration metadata, and advisors.
5. Update backend contract, ledger, and durable memory after validation.

## Required Validation

- RED MCP SQL query showing `app_private.pet_fit_breed_group(...)` does not exist before migration.
- MCP `apply_migration` to `lqmasbuqzvcvtawonjlb`.
- MCP SQL behavior checks for Westie/terrier, poodle/curly coat, anxious/gentle handling, senior care, size band, and JSON snapshot trait rows.
- MCP SQL privilege metadata check confirming no `anon`/`authenticated` execute grant on the private helper functions.
- MCP security and performance advisors.
- `git diff --check`
- `./scripts/supabase-check.sh` if present/configured.

Simulator launch is skipped because T-065 is backend SQL only and has no visible app behavior change.

## Stop Condition

Stop and report if this requires matching RPC replacement, new public tables/views, iOS UI/repository changes, T-050 deployment, or any non-MCP database write.

## Progress

- RED query passed: `select app_private.pet_fit_breed_group('West Highland White Terrier');` failed with SQLSTATE `42883` because the function did not exist.

## Closeout

Status: completed

Changed files:

- `supabase/migrations/20260625003519_t065_pet_fit_sql_taxonomy.sql`
- `docs/06_tasks/T-065_GROOMLY_PET_FIT_SQL_TAXONOMY.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- RED MCP SQL query failed before migration because `app_private.pet_fit_breed_group(text)` did not exist.
- Supabase MCP `apply_migration` passed for `20260625003519_t065_pet_fit_sql_taxonomy` on `lqmasbuqzvcvtawonjlb`.
- MCP SQL behavior checks passed for Westie/terrier, poodle/curly coat, anxious/senior care flags, nail-trim no-coat behavior, size bands, trait-pair validation, and JSON snapshot trait rows.
- MCP function privilege check confirmed `anon` and `authenticated` have no execute privilege on T-065 private helper functions; `service_role` has execute.
- Security advisor returned only existing public controlled `SECURITY DEFINER` RPC warnings plus leaked-password protection, not new T-065 helper warnings.
- Performance advisor returned existing table/index INFOs, not new T-065 findings.
- `./scripts/supabase-check.sh`: passed
- `git diff --check`: passed

Simulator launch:

- skipped because T-065 is backend SQL only

Risks:

- T-065 does not change request distribution, match scores, match reasons, repositories, or UI. T-066+ evidence objects remain separate future tasks.
- T-050 remains a local draft only; T-065 uses its own size-band helper and does not deploy T-050 pet constraints.

Next:

- Do not start T-066 groomer claimed/portfolio evidence without a separate task file and explicit authorization.
