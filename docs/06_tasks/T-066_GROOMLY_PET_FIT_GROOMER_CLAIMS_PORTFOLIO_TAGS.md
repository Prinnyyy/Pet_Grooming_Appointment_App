# T-066 - Groomly Pet-Fit Groomer Claims and Portfolio Tags

## Status

Completed.

## Mode

Deep.

## User Request

Execute T-066 after T-065 deployed the SQL pet-fit taxonomy helpers.

## Primary Task

Add backend-only pet-fit evidence input tables for later matching work:

- groomer-owned low-confidence fit claims
- optional pet-fit tags attached to existing groomer portfolio photos

## Out of Scope

- Changing request distribution or `create_grooming_request`.
- Changing match scores or match reasons.
- Adding structured reviews, evidence summary views, iOS UI, repositories, or matching display.
- Adding Storage policies or changing portfolio object upload paths.
- Treating self-claimed specialties as verified expertise.

## Existing Mapping

- T-065 provides `app_private.pet_fit_valid_trait_pair(text, text)` and the shared SQL trait vocabulary.
- `groomer_portfolio_photos` already stores owner-scoped portfolio metadata and authenticated reads for active groomers.
- T-066 keeps both new tables behind explicit Data API grants plus RLS.

## Implementation Plan

1. Run a RED MCP SQL query proving the new claim table is absent.
2. Apply one reviewed Supabase MCP migration to `lqmasbuqzvcvtawonjlb`.
3. Mirror the applied migration locally under `supabase/migrations/`.
4. Verify table shape, grants, RLS policies, trait constraints, owner management, active-groomer reads, cross-user denial, and rollback residue.
5. Update backend contract, RLS policy docs, ledger, and durable memory after validation.

## Required Validation

- RED MCP SQL query showing `public.groomer_fit_claims` does not exist before migration.
- MCP `apply_migration` to `lqmasbuqzvcvtawonjlb`.
- MCP metadata checks for both tables, grants, RLS, policies, constraints, indexes, and migration listing.
- Rollback-only MCP behavior checks:
  - groomer owner can insert/update/delete own claims;
  - owner can insert/delete tags for own portfolio photos;
  - authenticated users can read active claims/tags for active groomers;
  - inactive claims are hidden from other authenticated users;
  - cross-user direct mutation is denied;
  - invalid trait pairs are rejected;
  - rollback leaves zero validation rows.
- MCP advisor checks.
- `./scripts/supabase-check.sh`
- `git diff --check`

Simulator launch is skipped because T-066 is backend SQL only and has no visible app behavior change.

## Stop Condition

Stop and report if this requires matching RPC replacement, evidence summary views, iOS UI/repository changes, Storage policy changes, or non-MCP database writes.

## Progress

- RED query passed: `select count(*) from public.groomer_fit_claims;` failed with SQLSTATE `42P01` because the table did not exist.
- Supabase MCP `apply_migration` passed for `20260625005226_t066_groomer_fit_claims_portfolio_tags` on `lqmasbuqzvcvtawonjlb`.
- Local migration mirror was aligned to `supabase/migrations/20260625005226_t066_groomer_fit_claims_portfolio_tags.sql`.
- Metadata checks passed for migration listing, table existence, RLS enabled, column-scoped authenticated grants, policies, constraints, indexes, triggers, and `anon` lacking pet-fit helper function execute.
- Rollback-only behavior validation failed on the first owner insert with SQLSTATE `42501`: authenticated DML triggered `groomer_fit_claims_trait_check`, which called `app_private.pet_fit_valid_trait_pair(...)`; that helper then called `app_private.pet_fit_normalized_text(...)`, but `authenticated` lacks `USAGE` on schema `app_private`.
- Residue check after the failed behavior batch returned zero T-066 validation auth users, profiles, claims, and tags.
- User approved continuing the task. RED reproduction confirmed the same `42501` failure before the corrective migration.
- Corrective migration `20260625010421_t066_fix_claim_tag_trait_checks` replaced both trait CHECK constraints with explicit canonical trait enumerations and revoked authenticated execute on `app_private.pet_fit_normalized_text(text)` and `app_private.pet_fit_valid_trait_pair(text, text)`.
- Rollback-only behavior validation then passed for owner claim/tag writes, active-groomer reads, inactive-groomer hiding, cross-user mutation denial, invalid trait rejection, owner deletes, and zero persisted validation rows.
- Performance advisor then reported T-066 multiple-permissive-policy WARNs and an unindexed composite tag foreign key INFO.
- Corrective migration `20260625010716_t066_merge_select_policies_and_index_tag_fk` merged each table's SELECT policies and added `groomer_portfolio_fit_tags_photo_groomer_idx`.
- Final rollback-only behavior validation still passed after policy merge.

## Closeout

Status: completed

Changed files:

- `supabase/migrations/20260625005226_t066_groomer_fit_claims_portfolio_tags.sql`
- `supabase/migrations/20260625010421_t066_fix_claim_tag_trait_checks.sql`
- `supabase/migrations/20260625010716_t066_merge_select_policies_and_index_tag_fk.sql`
- `docs/06_tasks/T-066_GROOMLY_PET_FIT_GROOMER_CLAIMS_PORTFOLIO_TAGS.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- RED MCP SQL query failed before the first migration because `public.groomer_fit_claims` did not exist.
- Supabase MCP `apply_migration` passed for `20260625005226_t066_groomer_fit_claims_portfolio_tags`.
- MCP metadata checks confirmed both tables exist with RLS enabled, explicit authenticated/service_role grants, no anon table grants, canonical trait constraints, unique constraints, foreign keys, indexes, updated_at triggers, and one policy per operation after the final corrective migration.
- RED reproduction after the first migration failed with SQLSTATE `42501`, proving the authenticated CHECK helper schema-permission issue before correction.
- Supabase MCP `apply_migration` passed for corrective migration `20260625010421_t066_fix_claim_tag_trait_checks`.
- MCP checks confirmed the T-066 trait CHECK constraints no longer depend on `app_private`, while `anon` and `authenticated` again lack execute privilege on the two T-065 pet-fit helper functions and `service_role` keeps execute.
- Rollback-only behavior validation passed for owner claim insert/update/delete, owner portfolio tag insert/update/delete, active-groomer reads, inactive-groomer hiding, cross-user mutation denial, invalid trait rejection, and zero persisted validation rows.
- Supabase MCP `apply_migration` passed for advisor corrective migration `20260625010716_t066_merge_select_policies_and_index_tag_fk`.
- Final policy/index checks confirmed one SELECT policy per T-066 table and a covering index for `groomer_portfolio_fit_tags(portfolio_photo_id, groomer_id)`.
- Final MCP security advisor returned only existing controlled public SECURITY DEFINER RPC warnings plus leaked-password protection; no new T-066 security finding.
- Final MCP performance advisor no longer reported T-066 multiple-permissive-policy WARNs or the tag foreign-key missing-index INFO. It reported existing historical INFOs plus an expected unused-index INFO for the new tag foreign-key index before production traffic.
- Final residue check returned zero T-066 validation auth users, profiles, claims, and tags.
- `./scripts/supabase-check.sh`: passed.
- `git diff --check`: passed.

Simulator launch:

- skipped because T-066 is backend SQL only and has no visible app behavior change.

Risks:

- T-066 does not change request distribution, match scores, match reasons, public evidence summaries, repositories, iOS UI, or Storage policies.
- Groomer self-claimed fit claims remain low-confidence input only and are not proof of expertise.
- Portfolio fit tags are metadata attached to existing portfolio-photo rows; they do not expose private Storage objects by themselves.

Next:

- Do not start T-067 structured review evidence without a separate task file and explicit backend authorization.
