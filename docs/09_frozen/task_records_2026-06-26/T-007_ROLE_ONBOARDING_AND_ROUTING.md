# T-007 — Role Onboarding and Authenticated Routing

## Status

Completed on 2026-06-20. Migrations `20260620172839_t007_create_my_profile` and
corrective `20260620180607_t007_fix_create_my_profile_conflict_target` are
deployed and mirrored. The correction replaced the ambiguous `on conflict (id)`
target with `profiles_pkey`. Rollback-only RPC/RLS checks, security/performance
advisors, the static Supabase check, 17 Swift Testing tests, and one UI smoke test
passed. No test users or profile rows persisted from validation.

## Primary Task

Allow an authenticated user without a marketplace profile to enter a display name, choose Customer or Groomer, create the matching profile records atomically, and route to the corresponding existing Tab shell.

## Dependencies

- T-004 profile tables, grants, and RLS are deployed to the authorized fresh Supabase project.
- T-005 provides the configured Supabase Swift client and repository boundary pattern.
- T-006 provides real email/password Auth and session restoration.

## Approved Design

- `docs/superpowers/specs/2026-06-20-t007-role-onboarding-design.md`
- Onboarding collects one required display name and one explicitly selected role.
- A `security invoker` RPC creates `profiles` plus the matching role marker in one transaction.
- The RPC inserts `profiles` before the marker because the deployed marker RLS policy requires that order.
- Same-role retries are idempotent and preserve the stored display name; an existing different role returns the stable immutable-role error without relying on an RLS failure.
- Auth state remains owned by `AuthenticationStore`; profile loading and routing use a separate Store and repository.
- The real authenticated entry flow replaces and removes both T-006 onboarding placeholder views.

## In Scope

- One reviewed onboarding RPC migration plus its separately approved conflict-target correction, with explicit execute privileges preserved.
- Profile repository contract and Supabase adapter.
- Authenticated entry Store with loading, onboarding, Customer, Groomer, and retryable failure states.
- Role onboarding UI with display-name validation and duplicate-submit protection.
- Real Customer/Groomer routing from authoritative profile data.
- A minimal authenticated Account destination that preserves sign-out access after routing.
- Focused Store tests, existing launch smoke coverage, backend RLS/RPC checks, and durable documentation updates.

## Out of Scope

- Avatar upload, customer details, pet creation, groomer business details, services, portfolio, role switching, account deletion, or any marketplace workflow.
- Runtime fixtures, fake backend success, service-role credentials in the app, or direct Supabase calls from SwiftUI views.
- Changes to the legacy Supabase project.
- Commit or push without a separate explicit user instruction.

## Remote Boundary

All Supabase work must use Supabase CLI and target only the linked `lqmasbuqzvcvtawonjlb` project. The complete migration SQL must be reviewed and explicitly approved before `supabase db push --linked`. The applied migration must then be mirrored exactly under `supabase/migrations/`.

## Validation Plan

1. Apply the approved migration with Supabase CLI.
2. Use rollback-only Supabase CLI SQL checks for Customer/Groomer creation, same-role idempotency, role-switch rejection, and cross-user isolation.
3. Run Supabase CLI security and performance advisors.
4. Run `./scripts/supabase-check.sh` as a static repository check.
5. Run exactly one Xcode validation attempt: `./scripts/ios-test.sh`.
6. Run lightweight diff checks and review only the T-007 scope.

If the Xcode validation fails, report the first real error and stop without entering a fix loop.

## Stop Condition

Stop when authenticated profile loading, atomic onboarding, role-based entry, retryable failures, validation, and durable memory updates are complete. Do not begin T-008.
