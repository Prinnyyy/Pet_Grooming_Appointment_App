# T-073 Groomly Claim and Portfolio Match Signals

## Status

Completed.

## Mode

Deep. This task changes deployed Supabase RPC behavior by replacing `create_grooming_request` internals while preserving its signature, result shape, grants, and client contract.

## Goal

Consume existing T-066 groomer fit claims and portfolio fit tags as low-confidence match-scoring signals for newly created request matches.

## Scope

In scope:

- Reuse `public.groomer_fit_claims` active rows and `public.groomer_portfolio_fit_tags` rows that match request-derived T-065 traits.
- Keep all existing T-072 hard filters:
  - active groomer profile;
  - compatible service-location mode;
  - city/state eligibility;
  - active fixed service type;
  - saved groomer availability for the preferred range.
- Preserve the existing `create_grooming_request` signature, return columns, error contract, `SECURITY DEFINER` mode, empty `search_path`, and execute grants.
- Keep completed-booking and structured-review evidence from T-068/T-069 as the evidence-backed scoring source.

Out of scope:

- New tables, RLS policies, Storage rules, or public RPC signatures.
- Treating claims or portfolio tags as proof of expertise, specialist status, or eligibility by themselves.
- Customer-facing slot discovery, public groomer directory browsing, direct booking, auto-accept, payments, notifications, or ML recommendations.
- iOS model, repository, or UI changes.

## Implementation Summary

- Added local migration `supabase/migrations/20260625081925_t073_claim_portfolio_match_signals.sql`.
- Applied the SQL to `Pet Groomer Marketplace` / `lqmasbuqzvcvtawonjlb` through `supabase db query --linked --file`, then recorded the same local migration version with `supabase migration repair --linked --status applied 20260625081925`.
- A prior MCP connectivity probe accidentally created empty remote migration history entry `20260625082052_t073_claim_portfolio_match_signals`; it was removed with `supabase migration repair --linked --status reverted 20260625082052` before the real migration was applied.
- Updated `create_grooming_request` so eligible availability-fit groomers receive a bounded low-confidence adjustment from matching:
  - portfolio tags: 2 points per matched request trait;
  - active self-claims: 1 point per matched request trait;
  - combined claim/tag adjustment cap: 6 points.
- Added display-ready `match_reason` text under `Groomer fit signals:` using `portfolio tag for ...` and `self-claimed fit for ...` language.
- Updated backend contract, RLS/RPC policy docs, task ledger, feature index, current state, and worklog.

## Validation

- RED rollback-only remote SQL failed as expected before implementation:
  - two same-city/same-service/same-availability groomers both matched;
  - only one groomer had a matching active claim and portfolio tag;
  - both groomers received `80.00` and `Same city and service location.`;
  - residue check returned zero validation rows.
- Remote migration history now includes `20260625081925_t073_claim_portfolio_match_signals`.
- GREEN rollback-only remote SQL passed:
  - both eligible groomers still matched;
  - the claim/tag groomer outranked the equivalent baseline groomer;
  - claim/tag reason text included `self-claimed` and `portfolio tag`;
  - the baseline reason stayed location-only;
  - scores remained within 0 through 100;
  - validation data rolled back.
- Remote metadata/grant check confirmed `create_grooming_request` remains:
  - same arguments and return type;
  - `SECURITY DEFINER`;
  - empty `search_path`;
  - not executable by `anon`;
  - executable by `authenticated` and `service_role`.
- Final residue check returned zero T-073 validation rows/users.
- Supabase security advisor returned only existing intentional controlled `SECURITY DEFINER` RPC warnings plus leaked-password protection.
- Supabase performance advisor returned no issues.
- `./scripts/supabase-check.sh` passed.
- `git diff --check` passed.
- No iOS build or simulator launch was run because this task changed backend RPC behavior and documentation only, with no Swift or visible app UI changes.

## Risks and Follow-ups

- Claim/tag signals only affect newly created request matches. Existing `request_matches` rows are not backfilled.
- Claims and portfolio tags remain low-confidence groomer-owned signals; they do not create match eligibility, proof of expertise, specialist/expert status, public directory behavior, or direct booking.
- T-070 surfaces backend fit reasons only in the groomer matched-request list/detail. Customer offer review and public groomer profile surfaces still do not expose these signals.
