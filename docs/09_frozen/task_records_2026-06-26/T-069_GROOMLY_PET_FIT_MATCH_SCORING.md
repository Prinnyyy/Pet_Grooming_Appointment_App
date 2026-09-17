# T-069 - Groomly Pet-Fit Match Scoring

## Status

Completed.

## Mode

Deep.

## User Request

Execute T-069.

## Primary Task

Update `public.create_grooming_request(...)` so newly created request matches keep the existing hard eligibility filters while writing more useful backend-generated `request_matches.match_score` and `request_matches.match_reason` values from T-068 pet-fit evidence.

## Out of Scope

- Changing the `create_grooming_request` signature or return shape.
- Changing request, match, offer, booking, review, Storage, or iOS contracts.
- Adding a public groomer directory, direct customer slot booking, availability enforcement, payments, AI/ML recommendations, or client-authored match scoring.
- Treating groomer self-claims or portfolio tags as evidence-backed outcomes.
- Changing existing RLS policies or direct table write grants.

## Existing Mapping

- T-065 provides private SQL trait derivation helpers for request pets.
- T-068 provides the read-only `groomer_pet_fit_evidence_summary` aggregate view.
- `create_grooming_request` already owns backend-controlled creation of `grooming_requests` and eligible `request_matches`.
- iOS currently displays `match_reason` directly, so T-069 must write concise human-readable reason text.

## Implementation Plan

1. Run a RED rollback-only remote SQL test proving current `create_grooming_request` does not rank a groomer with matching T-068 evidence above an otherwise equivalent groomer without evidence.
2. Create a Supabase migration that replaces only `public.create_grooming_request(...)`.
3. Keep the current hard filters: active groomer profile, compatible service-location mode, state/city location heuristic, and active fixed service.
4. Add request-trait derivation and bounded pet-fit evidence adjustment to match scoring.
5. Write short display-ready `match_reason` text combining location fit and top pet-fit evidence labels.
6. Re-apply the existing execute grants and comments for the RPC.
7. Apply the migration to project `lqmasbuqzvcvtawonjlb`.
8. Run GREEN rollback-only behavior checks, metadata/grant checks, advisors, `./scripts/supabase-check.sh`, and `git diff --check`.
9. Update backend contract, RLS policy docs, task ledger, and durable memory after validation.

## Required Validation

- RED rollback-only remote SQL test fails for the pre-T-069 behavior:
  - two same-city/same-service groomers both match;
  - only one groomer has completed-booking and positive structured review evidence;
  - current score/reason still treats both groomers identically.
- Supabase migration application to `lqmasbuqzvcvtawonjlb`.
- Remote metadata checks:
  - function signature and return shape unchanged;
  - `SECURITY DEFINER` with empty `search_path`;
  - `authenticated` and `service_role` have execute;
  - `anon` does not have execute.
- GREEN rollback-only behavior checks:
  - evidence-backed groomer outranks equivalent no-evidence groomer;
  - reason text includes location fit and pet-fit evidence language;
  - match count and hard filters remain bounded to eligible groomers;
  - score remains within 0 through 100;
  - rollback leaves zero validation rows.
- Supabase security and performance advisor checks.
- `./scripts/supabase-check.sh`
- `git diff --check`

Simulator launch is skipped because T-069 is backend SQL only and has no visible app behavior change.

## Stop Condition

Stop and report if this requires iOS model/repository/UI changes, changing RLS or Storage policies, adding new public tables/views/RPCs, changing request/offer/booking lifecycle semantics, or remote writes outside the T-069 migration.

## Progress

- RED rollback-only remote SQL failed as expected before implementation: the evidence groomer and baseline groomer both received `100.00` and `same_city_state_service_location`.
- RED residue check returned zero validation auth users, profiles, grooming requests, matches, offers, bookings, and reviews.
- Supabase MCP migration application passed as `20260625064506_t069_pet_fit_match_scoring` after CLI `db query`, `db push --dry-run`, and `migration list` intermittently hung during linked login-role initialization.
- Metadata checks confirmed the `create_grooming_request` signature and result shape are unchanged, the function remains `SECURITY DEFINER` with empty `search_path`, `authenticated` and `service_role` have execute, and `anon` does not.
- GREEN rollback-only behavior validation passed: the evidence groomer outranked the equivalent no-evidence groomer, reason text included location and pet-fit evidence language, the no-evidence groomer reason remained location-only, the ineligible service groomer did not match, scores stayed within 0 through 100, and cleanup left no validation rows.

## Closeout

Status: completed

Changed files:

- `supabase/migrations/20260625064506_t069_pet_fit_match_scoring.sql`
- `docs/06_tasks/T-069_GROOMLY_PET_FIT_MATCH_SCORING.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/06_tasks/README.md`
- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- RED rollback-only remote SQL reproduced the old same-score/same-reason behavior before implementation.
- Supabase MCP migration applied as `20260625064506_t069_pet_fit_match_scoring`.
- MCP `_list_migrations` confirmed the T-069 migration in remote migration history; local migration file was renamed to the same version. `supabase migration list` later hung during linked login-role initialization and was interrupted.
- Remote metadata/grant checks confirmed unchanged RPC signature/result shape, `SECURITY DEFINER`, empty `search_path`, `authenticated`/`service_role` execute, and no `anon` execute.
- GREEN rollback-only behavior checks passed for evidence scoring, reason text, hard-filter preservation, score bounds, and ineligible-service exclusion.
- Final residue check returned zero T-069 validation auth users, profiles, grooming requests, request matches, offers, bookings, reviews, and structured review outcomes.
- Supabase security advisor returned existing controlled public `SECURITY DEFINER` RPC warnings plus existing leaked-password protection.
- Supabase performance advisor returned existing FK/index INFOs; T-069 added no tables, foreign keys, or indexes.
- `./scripts/supabase-check.sh`: passed.
- `git diff --check`: passed.
- no-index whitespace checks for the new T-069 task and migration files: passed.

Simulator launch:

- skipped because T-069 is backend SQL only and has no visible app behavior change.

Risks:

- T-069 changes only new request-match score/reason generation. Existing `request_matches` rows are not backfilled.
- T-069 does not change the RPC signature, iOS models/repositories/UI, RLS policies, Storage, availability enforcement, groomer claims/portfolio weighting, or request/offer/booking lifecycle semantics.
- iOS currently displays raw backend `match_reason` text; T-070 can improve surfacing without changing backend matching behavior.

Next:

- T-070 should surface existing fit reasons in iOS offer/request UI without adding a customer groomer directory, direct booking, or new matching backend behavior.
