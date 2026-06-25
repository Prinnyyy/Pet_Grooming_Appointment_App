# T-067 - Groomly Pet-Fit Structured Reviews

## Status

Completed.

## Mode

Deep.

## User Request

Execute T-067.

## Primary Task

Extend completed-booking reviews with structured pet-fit outcomes while preserving the existing `rating` and `content` review contract.

## Out of Scope

- Adding the T-068 evidence summary view.
- Changing request distribution, `request_matches.match_score`, or `request_matches.match_reason`.
- Changing iOS review UI, repositories, stores, or models.
- Adding public groomer directory browsing, direct customer slot booking, ML/AI recommendation behavior, payments, or availability enforcement.
- Changing review editing/deletion, moderation, disputes, or Storage policies.

## Existing Mapping

- T-021 owns `public.reviews` and the controlled `create_review` RPC.
- T-065 defines the shared pet-fit trait vocabulary.
- T-066 showed that authenticated table constraints must not depend on private `app_private` helper execution. T-067 uses table-local trait checks.
- T-068 will derive summaries from completed bookings, `reviews`, and T-067 structured outcome rows.

## Implementation Plan

1. Run a RED remote query proving `public.review_pet_fit_outcomes` and the four-argument `create_review` signature are absent.
2. Apply one reviewed Supabase migration to `lqmasbuqzvcvtawonjlb`.
3. Mirror the applied migration locally under `supabase/migrations/`.
4. Verify old review creation still works without structured outcomes.
5. Verify structured outcomes can be created through `create_review`, invalid traits/outcomes are rejected, duplicate outcome traits are rejected, participant RLS can read rows, non-participants cannot read rows, direct authenticated DML is denied, and validation rows are cleaned up.
6. Run Supabase advisor/static checks plus `git diff --check`.
7. Update backend contract, RLS policy docs, ledger, and durable memory after validation.

## Required Validation

- RED remote SQL query showing `public.review_pet_fit_outcomes` is absent and only the old three-argument `create_review` signature exists.
- Supabase migration application to `lqmasbuqzvcvtawonjlb`.
- Remote metadata checks for table shape, grants, RLS, policies, constraints, indexes, function signature, and function grants.
- Rollback-only behavior checks:
  - booked customer can create a review with no structured outcomes using the existing argument set;
  - booked customer can create a review with valid structured outcomes;
  - invalid trait pairs are rejected;
  - invalid outcome values are rejected;
  - duplicate outcome traits in one review are rejected;
  - customer and groomer participants can select outcome rows through RLS;
  - non-participants cannot select outcome rows;
  - direct authenticated insert/update/delete on outcome rows is denied;
  - rollback leaves zero validation rows.
- Supabase security and performance advisor checks.
- `./scripts/supabase-check.sh`
- `git diff --check`

Simulator launch is skipped because T-067 is backend SQL only and has no visible app behavior change.

## Stop Condition

Stop and report if this requires matching RPC replacement, evidence summary views, iOS UI/repository changes, Storage policy changes, review editing/deletion behavior, or non-approved remote writes outside the T-067 migration.

## Progress

- RED query passed through the Supabase MCP after the CLI query hung during login-role initialization: `public.review_pet_fit_outcomes` did not exist, `public.create_review(uuid, integer, text)` existed, and `public.create_review(uuid, integer, text, jsonb)` did not exist.
- Supabase CLI `db push --linked --yes` hung during login-role initialization and was interrupted before applying changes.
- Remote migration application passed through Supabase MCP as `20260625050422_t067_structured_review_outcomes`.
- Local migration mirror was renamed to `supabase/migrations/20260625050422_t067_structured_review_outcomes.sql` to match remote migration history.
- Metadata checks passed for table existence, columns, constraints, indexes, RLS, grants, one SELECT policy, the new `create_review` signature, empty function search path, and function execute grants.
- Rollback-only behavior validation passed for old review calls, valid structured outcomes, invalid trait rejection, invalid outcome rejection, duplicate outcome rejection, customer/groomer participant SELECT, non-participant invisibility, direct authenticated insert/update/delete denial, and zero persisted validation rows.

## Closeout

Status: completed

Changed files:

- `supabase/migrations/20260625050422_t067_structured_review_outcomes.sql`
- `docs/06_tasks/T-067_GROOMLY_PET_FIT_STRUCTURED_REVIEWS.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- RED remote SQL query showed `public.review_pet_fit_outcomes` absent, old `create_review(uuid, integer, text)` present, and new `create_review(uuid, integer, text, jsonb)` absent before migration.
- `supabase db push --linked --yes`: blocked during `Initialising login role...`; interrupted before remote changes.
- Supabase MCP migration application passed for `20260625050422_t067_structured_review_outcomes`.
- Remote metadata checks confirmed `review_pet_fit_outcomes` exists with RLS enabled, no anon grant, authenticated SELECT only, service_role DML grants, expected constraints/indexes, one participant SELECT policy, and one `create_review` function with optional `p_pet_fit_outcomes jsonb`.
- Rollback-only behavior checks passed for old three-argument review creation, valid structured outcome creation, invalid trait rejection, invalid outcome rejection, duplicate outcome rejection, customer/groomer participant reads, non-participant invisibility, direct authenticated insert/update/delete denial, and zero persisted validation rows.
- Supabase security advisor returned expected controlled public `SECURITY DEFINER` RPC warnings, now including the T-067 `create_review` signature, plus existing leaked-password protection.
- Supabase performance advisor returned existing INFOs plus expected unused-index INFOs for the new T-067 indexes before traffic.
- `./scripts/supabase-check.sh`: passed.
- `git diff --check`: passed.

Simulator launch:

- skipped because T-067 is backend SQL only and has no visible app behavior change.

Risks:

- T-067 does not change request distribution, match scores, match reasons, evidence summary views, iOS UI/repositories, or Storage policies.
- Structured outcomes are available only when callers pass the optional JSON payload to `create_review`; current iOS review UI still submits rating/content only.
- T-068 remains required before customers or groomers can read aggregated evidence summaries grouped by groomer and trait.

Next:

- Do not start T-068 evidence summary without a separate task file and explicit backend authorization.
