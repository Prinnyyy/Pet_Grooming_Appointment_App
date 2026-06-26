# T-081A - Groomly Evidence Dashboard Owner Visibility Backend

## Status

Completed on 2026-06-26.

## Mode

Deep.

## Authorization

The user explicitly authorized T-081A Deep backend work for project
`lqmasbuqzvcvtawonjlb`.

## Trigger

T-081 was blocked because the current `security_invoker` evidence summary view
depends on `grooming_requests.pet_snapshot`, while the existing
`grooming_requests` RLS policy does not let groomers read booked/completed
request rows directly.

## Primary Task

Create a backend-owned, owner-readable aggregate evidence contract for Groomer
Account without exposing raw customer, pet, request, booking, or review details.

Changed files:

- `supabase/migrations/20260626021651_t081a_evidence_dashboard_owner_rpc.sql`
- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`
- `docs/06_tasks/T-081_GROOMLY_GROOMER_EVIDENCE_DASHBOARD.md`
- Durable memory docs after implementation

## Implementation Summary

T-081A adds `public.get_my_groomer_pet_fit_evidence_summary()` as a
`SECURITY DEFINER` RPC with an empty `search_path`.

The RPC:

- rejects unauthenticated or anonymous callers with
  `authenticated_user_required`;
- validates the caller through `public.groomer_profiles` plus
  `public.profiles.role = 'groomer'`;
- filters aggregate rows to `auth.uid()`;
- reads the existing T-068 `public.groomer_pet_fit_evidence_summary` from a
  controlled backend context;
- returns only aggregate columns: groomer ID, canonical trait pair, completed
  booking count, positive/negative/structured outcome counts, safe timestamps,
  and conservative confidence tier;
- exposes no raw customer, pet, request, offer, booking, review, content, email,
  or `pet_snapshot` fields.

The migration does not alter `grooming_requests` RLS, direct view grants,
matching, request/offer/booking lifecycle behavior, Storage, or iOS code.

## Constraints

- Preserve the request-first marketplace model.
- Do not expose raw request pet snapshots, customer identities, booking rows, or
  review details through the dashboard contract.
- Do not broaden `grooming_requests` row visibility just to make the iOS
  dashboard work.
- Prefer a narrowly scoped aggregate RPC or view that performs explicit
  authenticated groomer-owner checks and returns only aggregate counts,
  canonical trait pairs, confidence tiers, and safe timestamps.
- Keep evidence confidence conservative; do not label a groomer as verified,
  expert, specialist, or generally better.
- Remote schema writes required explicit user approval for project
  `lqmasbuqzvcvtawonjlb`; approval was received before applying the migration.

## Validation Plan

- Start with rollback-only SQL that reproduces the current owner-read visibility
  gap for snapshot-derived completed-booking evidence.
- Validate the new contract with rollback-only data:
  - a groomer can read only their own aggregate evidence rows;
  - another groomer cannot read those rows;
  - a customer cannot read the groomer owner dashboard contract;
  - aggregate rows include completed counts and structured outcome counts;
  - no raw customer, pet, request, booking, review content, or pet snapshot data
    is returned.
- Run metadata checks for function/view options, grants, policies, and exposed
  columns.
- Run Supabase advisors and `./scripts/supabase-check.sh`.
- Run `git diff --check`.

## Validation Results

- RED rollback-only SQL reproduced the owner-read gap before implementation:
  backend context saw 7 completed-booking trait rows for the fixture groomer,
  while the authenticated groomer direct read of the `security_invoker` view saw
  0 completed-booking rows.
- `supabase db push --linked --dry-run` was intentionally not used for remote
  apply because existing historical migration drift made CLI push unsafe for a
  single-task migration. The reviewed T-081A SQL was applied through Supabase
  MCP `_apply_migration`; the local migration file was then aligned to the
  remote version `20260626021651`.
- Metadata check confirmed `SECURITY DEFINER`, empty `search_path`,
  `authenticated`/`service_role` execute, and no `anon`/`PUBLIC` execute.
- GREEN rollback-only SQL passed:
  - owner groomer RPC returned 7 aggregate trait rows with completed counts;
  - the `breed_group:poodle` row included 1 completed booking, 1 positive
    structured outcome, 0 negative outcomes, and low confidence;
  - direct `security_invoker` view access still hid completed request snapshot
    evidence for the groomer, proving table RLS was not broadened;
  - another groomer received 0 owner rows;
  - a customer caller was rejected with `P0001:groomer_profile_required`;
  - function signature exposed only aggregate columns.
- Residue check returned 0 validation rows in Auth, profiles, role markers,
  requests, matches, offers, bookings, reviews, and review outcomes.
- `supabase migration list --linked` shows local and remote T-081A aligned as
  `20260626021651`.
- Security advisor ran and reported the expected intentional
  `authenticated_security_definer_function_executable` WARN for the new owner
  RPC plus existing baseline WARNs.
- Performance advisor ran and reported existing INFO findings only.
- `./scripts/supabase-check.sh`: passed.
- `git diff --check`: passed.

## Resume Path

T-081 can resume as a Standard iOS task using the new owner-readable aggregate
contract behind `GroomerProfileRepository`.

The T-081 iOS implementation should call
`get_my_groomer_pet_fit_evidence_summary()` instead of direct-reading the T-068
view for owner dashboard completed-booking evidence.
