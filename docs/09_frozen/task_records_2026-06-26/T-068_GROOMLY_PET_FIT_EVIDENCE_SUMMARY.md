# T-068 - Groomly Pet-Fit Evidence Summary

## Status

Completed.

## Mode

Deep.

## User Request

Execute T-068.

## Primary Task

Add a read-only pet-fit evidence summary grouped by groomer and canonical trait. The summary is derived from completed bookings and structured review outcomes, and remains separate from request distribution scoring.

## Out of Scope

- Changing `create_grooming_request`, `request_matches.match_score`, or `request_matches.match_reason`.
- Adding iOS models, repositories, stores, or UI surfacing.
- Adding public groomer-directory browsing, direct customer slot booking, ML/AI recommendation behavior, payments, or availability enforcement.
- Making groomer claims or portfolio tags count as evidence-backed outcomes.
- Adding direct client mutation paths for evidence summaries.

## Existing Mapping

- T-065 defines the shared pet-fit trait vocabulary.
- T-067 writes structured review outcomes through `create_review`.
- Completed bookings are stored in `public.bookings` and request pet snapshots are stored in `public.grooming_requests`.
- T-069 will update request matching score/reason generation later; T-068 only creates the read surface.

## Implementation Plan

1. Run a RED remote query proving `public.groomer_pet_fit_evidence_summary` is absent.
2. Create local Supabase migrations for a read-only `security_invoker`/`security_barrier` view and corrective view grant tightening.
3. Apply the migrations to project `lqmasbuqzvcvtawonjlb`.
4. Verify metadata, grants, and view options.
5. Run rollback-only behavior checks for completed-booking trait aggregation, structured review outcome counts, participant-scoped reads, non-participant hiding, anon denial, and direct write denial.
6. Run Supabase advisor/static checks plus `git diff --check`.
7. Update backend contract, RLS policy docs, task ledger, and durable memory after validation.

## Required Validation

- RED remote SQL query showing `public.groomer_pet_fit_evidence_summary` is absent.
- Supabase migration application to `lqmasbuqzvcvtawonjlb`.
- Remote metadata checks for view existence, columns, grants, and `security_invoker`/`security_barrier` options.
- Rollback-only behavior checks:
  - completed bookings create grouped trait evidence rows;
  - positive and negative structured review outcomes are counted by groomer/trait;
  - booking customers can read complete participant-scoped aggregate rows;
  - booked groomers can read review-outcome aggregate rows under existing request RLS;
  - non-participants cannot read rows;
  - `anon` cannot read the view;
  - authenticated clients cannot insert/update/delete through the view;
  - rollback leaves zero validation rows.
- Supabase security and performance advisor checks.
- `./scripts/supabase-check.sh`
- `git diff --check`

Simulator launch is skipped because T-068 is backend SQL only and has no visible app behavior change.

## Stop Condition

Stop and report if this requires replacing matching RPCs, changing iOS code, changing Storage policies, exposing customer/pet booking details outside aggregate counts, or remote writes outside the T-068 migrations.

## Progress

- RED remote query passed before implementation: `public.groomer_pet_fit_evidence_summary` was absent while T-066/T-067 input tables and the T-065 snapshot helper existed.
- Remote migration application passed through Supabase MCP as `20260625061431_t068_pet_fit_evidence_summary`.
- A corrective grant-tightening migration was applied as `20260625061526_t068_limit_evidence_summary_grants` after metadata checks showed default service-role DML-like grants on the aggregate view.
- Metadata checks passed for view existence, 11 expected columns, `security_invoker=true`, `security_barrier=true`, authenticated SELECT grant, service_role SELECT grant, and no anon grant.
- Rollback-only behavior validation passed for full aggregate counts, grouped completed-booking traits, customer participant full aggregate reads, groomer review-outcome aggregate reads, nonparticipant invisibility, anon SELECT denial, direct authenticated insert/update/delete denial, and zero persisted validation rows.

## Closeout

Status: completed

Changed files:

- `supabase/migrations/20260625061431_t068_pet_fit_evidence_summary.sql`
- `supabase/migrations/20260625061526_t068_limit_evidence_summary_grants.sql`
- `docs/06_tasks/T-068_GROOMLY_PET_FIT_EVIDENCE_SUMMARY.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- RED remote SQL query showed `public.groomer_pet_fit_evidence_summary` absent before migration.
- Supabase MCP migrations passed for `20260625061431_t068_pet_fit_evidence_summary` and corrective `20260625061526_t068_limit_evidence_summary_grants`.
- `supabase migration list` confirmed both T-068 migration versions are present locally and remotely; unrelated pre-existing migration-list skew remains outside T-068 scope.
- Remote metadata checks confirmed the view exists with `security_invoker=true`, `security_barrier=true`, expected columns, authenticated SELECT only, service_role SELECT only, and no anon grant.
- Rollback-only behavior checks passed for completed-booking trait aggregation, positive/negative structured outcome counts, customer participant full aggregate reads, groomer review-outcome aggregate reads, nonparticipant invisibility, anon SELECT denial, direct authenticated insert/update/delete denial, and zero persisted validation rows.
- Supabase security advisor returned only existing controlled public `SECURITY DEFINER` RPC warnings plus existing leaked-password protection.
- Supabase performance advisor returned existing INFOs; T-068 added no FK/index objects.
- `./scripts/supabase-check.sh`: passed.
- `git diff --check`: passed.
- no-index whitespace checks for the three new T-068 files: passed.

Simulator launch:

- skipped because T-068 is backend SQL only and has no visible app behavior change.

Risks:

- T-068 does not change request distribution, match scores, match reasons, iOS UI/repositories, or Storage policies.
- Direct authenticated view reads are constrained by underlying table RLS because the view is `security_invoker`; service/definer contexts can use the same view for full aggregate evidence in T-069.
- Existing `grooming_requests` RLS means booked groomer direct reads of the view can see structured-review aggregate rows but not all request-snapshot-derived completed-booking counts unless a later task explicitly changes request visibility or surfaces server-generated match reasons.

Next:

- T-069 should update `create_grooming_request` to keep existing hard filters while using T-068 evidence to write better `request_matches.match_score` and `request_matches.match_reason`. Do not start T-069 without a separate task file and explicit backend authorization.
