# T-004 Migration Review

## Status

Applied and validated on 2026-06-20.

## Target and Baseline

- Authorized project: `Pet Groomer Marketplace` (`lqmasbuqzvcvtawonjlb`).
- Forbidden legacy project: `swdiiyypysyxbnfrxxsv`.
- Initial remote baseline: project was `ACTIVE_HEALTHY` on Postgres 17.6; `public` had no tables, migration history was empty, and no `avatars` bucket existed.
- Applied migration mirror: `supabase/migrations/20260620105202_t004_profile_foundation.sql`.
- Advisor remediation mirror: `supabase/migrations/20260620105409_t004_optimize_rls_auth_calls.sql`.
- The first mirror intentionally preserves its reviewed pre-apply header comment because the file is an exact copy of the SQL applied remotely; deployed status is recorded in this review and the task intake.

## Reviewed Scope

- Enum: `public.user_role` with `customer` and `groomer`.
- Tables: `profiles`, `customer_profiles`, `groomer_profiles` only.
- Shared writable fields: `display_name` and private `avatar_path`.
- Role-specific tables are minimal onboarding markers; groomer marketplace details remain T-010.
- Client grants are column-scoped. Role, identity, and timestamps cannot be updated directly.
- RLS permits non-anonymous authenticated users to read only their own rows and create only their matching role row.
- Private `avatars` bucket: 5 MB; JPEG, PNG, HEIC, or HEIF; owner-only path/read/update/delete.
- No Auth trigger, RPC, Swift dependency, product table, demo data, service key, or legacy-project operation.

## Validation Results

1. Supabase CLI applied `20260620105202_t004_profile_foundation` to `lqmasbuqzvcvtawonjlb` and the exact SQL was mirrored locally.
2. Metadata inspection confirmed all three tables, constraints, grants, RLS policies, update triggers, and the private `avatars` bucket.
3. Rollback-only tests passed for own-row access, cross-user denial, role mismatch denial, owner-folder enforcement, and anonymous denial; no test data persisted.
4. Performance advisors initially reported seven equivalent `auth.jwt()` initialization-plan warnings. Supabase CLI migration `20260620105409_t004_optimize_rls_auth_calls` corrected the expressions without changing access semantics.
5. Final Supabase CLI security and performance advisors both returned zero lints.
6. The first static repository check exposed a validator false positive on legitimate SQL `service_role` grants. The scan was narrowed to actual key-value patterns, a targeted rerun passed, and `git diff --check` passed.

## Authorization Gate

Satisfied by the user's explicit request to resolve the T-004 migration. No operation targeted the forbidden legacy project.
