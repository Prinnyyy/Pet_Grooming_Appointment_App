# T-072 Groomly Availability-Aware Matching

## Status

Completed.

## Mode

Deep. This task changes deployed Supabase RPC behavior by replacing `create_grooming_request` internals while preserving its signature, result shape, grants, and client contract.

## Goal

Filter request matches by the groomer's saved availability at request creation time, without adding customer-facing slot browsing or direct booking.

## Scope

In scope:

- Reuse the T-071 private helper `app_private.groomer_is_available_for_range(uuid, timestamptz, timestamptz)` inside `create_grooming_request`.
- Keep all existing hard filters:
  - active groomer profile;
  - compatible service-location mode;
  - city/state eligibility;
  - active fixed service type;
  - bounded T-069 pet-fit score/reason generation.
- Preserve the existing `create_grooming_request` signature, return columns, error contract, `SECURITY DEFINER` mode, empty `search_path`, and execute grants.

Out of scope:

- New tables, RLS policies, Storage rules, or public RPC signatures.
- Customer-facing slot discovery, public groomer directory browsing, direct booking, auto-accept, payments, notifications, or multiple windows per day.
- iOS model, repository, or UI changes.

## Implementation Summary

- Added local migration `supabase/migrations/20260625075813_t072_availability_aware_matching.sql`.
- Applied remote migration `20260625080102_t072_availability_aware_matching` to `Pet Groomer Marketplace` / `lqmasbuqzvcvtawonjlb` through Supabase MCP because `supabase db push --linked --dry-run` hung at `Initialising login role...`.
- Updated `create_grooming_request` so `eligible_groomers` must also pass `app_private.groomer_is_available_for_range(groomer_profile.user_id, p_preferred_start, p_preferred_end)`.
- Updated backend contract, RLS/RPC policy docs, task ledger, feature index, current state, and worklog.

## Validation

- Initial validation attempt used a UTC timestamp that still mapped inside the unavailable groomer's Los Angeles local window, so that timestamp check was discarded.
- Corrected rollback-only remote SQL passed:
  - available groomer matched;
  - groomer unavailable for the request's local time was filtered out;
  - match count returned `1`;
  - validation data rolled back.
- Remote metadata/grant check confirmed `create_grooming_request` remains:
  - same arguments and return type;
  - `SECURITY DEFINER`;
  - empty `search_path`;
  - not executable by `anon`;
  - executable by `authenticated` and `service_role`.
- Final residue check returned zero T-072 validation rows/users.
- Supabase security advisor returned only existing intentional controlled `SECURITY DEFINER` RPC warnings plus leaked-password protection.
- Supabase performance advisor returned no issues.
- `./scripts/supabase-check.sh` passed.
- `git diff --check` passed.
- No iOS build or simulator launch was run because this task changed backend RPC behavior and documentation only, with no Swift or visible app UI changes.

## Risks and Follow-ups

- Availability is now enforced when creating request matches, creating groomer offers, and accepting offers. It is still not a customer-facing slot discovery or direct booking system.
- Groomers with no enabled weekly availability rows will not receive new request matches until they save availability.
- `auto_accept_bookings` remains persisted but unused.
- Multiple availability windows per day and holiday calendars beyond groomer-entered time off remain deferred.
