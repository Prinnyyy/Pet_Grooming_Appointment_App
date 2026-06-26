# T-082 - Groomly Matching Fairness And Calibration

## Status

Completed on 2026-06-26.

## Mode

Deep.

## Authorization

The user explicitly authorized T-082 for the Supabase project
`lqmasbuqzvcvtawonjlb`.

## Primary Task

Validate and calibrate `create_grooming_request` matching fairness after T-073
added low-confidence claim and portfolio signals.

Changed files:

- `supabase/migrations/20260626033330_t082_matching_fairness_calibration.sql`
- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`
- `docs/06_tasks/T-075_TO_T-085_GROOMLY_PET_FIT_EVIDENCE_CLOSURE_PLAN.md`
- Durable memory docs after implementation

## Scope

- Replace only the internal scoring/reason logic of
  `public.create_grooming_request`.
- Preserve the RPC signature, result shape, `SECURITY DEFINER`, empty
  `search_path`, and `authenticated`/`service_role` execute grants.
- Preserve hard eligibility filters: active groomer profile, compatible service
  location, city/state eligibility, active fixed service, and saved
  availability for the requested range.
- Do not add iOS behavior, tables, RLS policies, Storage policies, lifecycle
  transitions, public directory browsing, direct booking, ML, or a new RPC.

## RED Finding

Rollback-only SQL created one request scenario with five eligible groomers:

- a new groomer with no evidence;
- a claim-only groomer;
- a portfolio-tag-only groomer;
- a positive evidence-backed groomer;
- a groomer with negative poodle evidence plus starter signals.

Before T-082, all five groomers were matched, but the negative-evidence groomer
scored `89.00` while the new groomer scored `80.00`. The reason text omitted
the mixed poodle feedback and included starter `Groomer fit signals`.

The issue was the top-three evidence selection. Neutral completed-booking rows
could outrank and drop negative structured review evidence before the final
reason/score sum, allowing low-confidence claims and portfolio tags to mask the
earned negative signal.

## Implementation Summary

Migration `20260626033330_t082_matching_fairness_calibration` replaces only
`create_grooming_request` internals.

The new logic:

- prioritizes negative evidence into the top evidence set before positive or
  neutral rows;
- tracks `pet_fit.has_negative_evidence`;
- suppresses the low-confidence claim/portfolio score adjustment whenever
  earned negative evidence is present;
- suppresses `Groomer fit signals` reason text in that same negative-evidence
  case;
- keeps positive evidence, claim-only, and portfolio-only starter behavior
  bounded by the existing caps.

## Validation Results

- RED rollback-only diagnostic reproduced the fairness failure: new groomer
  `80.00`, claim-only `83.00`, portfolio-only `86.00`, positive evidence
  `94.00`, and negative-evidence-plus-starter-signals `89.00`.
- GREEN rollback-only validation before remote apply passed with new groomer
  `80.00`, claim-only `83.00`, portfolio-only `86.00`, positive evidence
  `94.00`, and negative evidence `78.00`.
- The GREEN negative reason became:
  `Same city and service location. Pet-fit evidence: mixed feedback for poodles, curly coats, gentle handling.`
  It no longer included `Groomer fit signals`.
- The reviewed migration was applied with `supabase db query --linked --file`
  and migration history was repaired to mark
  `20260626033330_t082_matching_fairness_calibration` as applied.
- Supabase MCP migration listing confirmed the remote migration history includes
  version `20260626033330`.
- Post-apply rollback-only validation against the deployed RPC passed with the
  same GREEN score ordering and no persisted validation rows.
- Metadata/grant checks confirmed the `create_grooming_request` signature,
  return table, `SECURITY DEFINER`, empty `search_path`, no `anon` execute, and
  `authenticated`/`service_role` execute grants remained unchanged.
- Residue check returned 0 validation rows in Auth, profiles, requests,
  matches, offers, bookings, reviews, and review outcomes.
- Security advisor reported only existing controlled `SECURITY DEFINER` WARNs
  and leaked-password-protection baseline warning.
- Performance advisor reported existing baseline INFO findings only.
- `./scripts/supabase-check.sh`: passed.
- `git diff --check`: passed.

## Closeout

T-082 affects newly created request matches only; it does not backfill existing
`request_matches`. Claim and portfolio signals remain low-confidence starter
signals, and completed bookings plus structured customer outcomes remain the
evidence-backed source. The request-first flow remains unchanged.
