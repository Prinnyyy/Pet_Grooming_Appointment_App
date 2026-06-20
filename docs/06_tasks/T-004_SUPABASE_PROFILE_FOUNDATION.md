# T-004 — Supabase Profile Foundation

## Status

Completed on 2026-06-20.

## Primary Task

Create the isolated Supabase foundation required for later authentication onboarding: an MCP-applied and repository-mirrored migration containing role/profile tables, owner-scoped RLS, and a private owner-scoped `avatars` bucket.

## Authorized Target

- Organization: `Prinnyyy` (`jckxqfrrrqrdxnlrakwi`).
- Project: `Pet Groomer Marketplace` (`lqmasbuqzvcvtawonjlb`).
- Region: `us-west-1`.
- Confirmed project cost: US$0/month.
- Forbidden legacy project: `swdiiyypysyxbnfrxxsv`.

## In Scope

- Draft one reviewed migration for the Customer/Groomer role type, `profiles`, `customer_profiles`, and `groomer_profiles`.
- Add explicit Data API grants and owner/role-scoped RLS policies.
- Add a private `avatars` bucket with owner-folder Storage policies.
- Apply the reviewed migration only through Supabase MCP to the authorized fresh project, then mirror the MCP-reported migration version locally.
- Validate deployed objects, grants, RLS behavior, Storage policies, and security/performance advisors through Supabase MCP.
- Synchronize backend contracts and durable memory with verified deployed state.

## Out of Scope

- Accessing, inspecting, branching, resetting, or mutating the legacy Supabase project.
- Supabase Swift SDK or any iOS/Swift/Xcode change.
- Auth screens, sign-up/sign-in, session handling, or onboarding UI.
- Pets, services, portfolio, requests, matches, offers, bookings, chat, reviews, or favorites.
- Runtime fixtures, privileged keys in client files, commit, or push.

## Validation Plan

1. Run `./scripts/supabase-check.sh` once after local files exist.
2. Verify the migration and deployed metadata on project `lqmasbuqzvcvtawonjlb`.
3. Run focused positive/negative profile and avatar policy checks with separate authenticated identities or equivalent transaction-local JWT claims.
4. Run Supabase security and performance advisors.
5. Review the current diff; do not run Xcode build or iOS tests.

## Execution Policy

All Supabase operations used Supabase MCP. The user authorized the reviewed migration by explicitly requesting resolution of the T-004 migration. No Supabase CLI, `npx supabase`, local Supabase stack, or direct database tooling was used.

## Current Progress

- MCP applied `20260620105202_t004_profile_foundation` to the authorized fresh project only.
- MCP performance advisors identified an `auth.jwt()` initialization-plan warning; the scoped remediation `20260620105409_t004_optimize_rls_auth_calls` was applied and both migration files are mirrored under `supabase/migrations/`.
- `profiles`, `customer_profiles`, and `groomer_profiles` are deployed with RLS, explicit client grants, and update triggers.
- The private `avatars` bucket is deployed with a 5 MiB limit, image MIME restrictions, and owner-folder policies.
- Rollback-only positive/negative tests passed for owner visibility, cross-user isolation, role-marker enforcement, Storage isolation, and anonymous denial.
- Final MCP security and performance advisor results contain no lints.

## Risk Level

High. This task creates remote database and Storage security boundaries.

## Stop Condition

Fulfilled. Stop after updating T-004 memory and validation evidence; do not start T-006 automatically.
