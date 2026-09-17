# T-222 Ideal Operation Readiness Rehearsal

Date: 2026-07-09.
Branch: `codex/pet-fit-structure-cleanup`.
Scope: Q-33 / R-029 / M8 local and read-only readiness gates after Q-16 through Q-32.

This rehearsal did not apply migrations, seed data, execute remote TestOps writes, deploy Edge Functions, change Auth configuration, upload a build, create a release tag, or touch App Store Connect.

## Supabase Documentation Check

- Checked the current Supabase CLI reference before running linked CLI commands. The reference still documents the CLI as the supported local development and deployment tool, and documents linked project usage for remote project commands.
- Checked Supabase debugging/monitoring guidance for CLI database inspection context. The guide documents CLI inspection commands as Postgres-internal checks and notes linked project usage for Supabase instances.
- Checked the current changelog search results for relevant breaking changes. No current changelog item changed this rehearsal scope because T-222 creates no public table, grants, REST API surface, OpenAPI introspection dependency, Auth configuration, or migration.

## Passed Gates

- `supabase --version`
  - Result: `2.107.0`.
- `supabase db --help`
  - Result: confirmed `advisors` is available.
- `supabase db advisors --help`
  - Result: confirmed `--linked`, `--type`, `--level`, and `--fail-on` flags.
- `./scripts/testops-unit.sh`
  - Result: 24/24 Node tests passed.
- `node scripts/testops.mjs doctor --dry-run`
  - Result: parsed 50 customer and 50 groomer seed profiles; remote write env was not set.
- `node scripts/testops.mjs run backend --scenario marketplace_full_lifecycle --matrix smoke5`
  - Result: generated 5 deterministic dry-run lifecycle plans with no remote writes.
- `node scripts/testops.mjs run matching --scenario request_matching_eval --matrix matching_baseline`
  - Result: generated 8 deterministic matching dry-run plans with positive and negative target assertions.
- `./scripts/supabase-check.sh`
  - Result: Supabase contract check passed.
- `node --test tests/migrations/*.test.mjs`
  - Result: 39/39 migration contract tests passed.
- `./scripts/ios-test.sh`
  - Result: Xcode test run succeeded.
- `./scripts/ios-build.sh`
  - Result: Xcode simulator build succeeded.

## Advisor Results

Commands used `--fail-on none` so advisor findings could be recorded as release-readiness evidence without converting known warnings or informational findings into shell failures.

- `supabase db advisors --linked --type security --level info --fail-on none`
  - Result: completed.
  - Findings:
    - `INFO rls_enabled_no_policy`: `public.customer_push_tokens` has RLS enabled and no policies. This matches the externally blocked APNs foundation state: client access is intentionally controlled through RPCs and dispatch remains blocked until Apple Developer/APNs credentials exist.
    - `WARN auth_leaked_password_protection`: Supabase Auth leaked-password protection is disabled. This is the previously known Auth configuration warning and requires remote Auth configuration authorization to change.
- `supabase db advisors --linked --type performance --level info --fail-on none`
  - Result: completed.
  - Findings:
    - `INFO unindexed_foreign_keys`: multiple marketplace foreign keys lack covering indexes, including keys on `bookings`, `conversations`, `customer_booking_handoff_acknowledgements`, `groomer_offers`, `grooming_requests`, `pet_photos`, `request_matches`, and `request_photos`.
    - `INFO unused_index`: several indexes have not been used yet, including marketplace, notification, and account-deletion indexes.

## Readiness Assessment

Q-33 is closed for the local/read-only ideal-operation target: local TestOps planning, matching projections, backend migration contracts, Supabase contract checks, linked advisors, iOS tests, and iOS build were all exercised on the current branch.

The advisor findings above are not treated as hidden failures. They are tracked as follow-up risk:

- Auth leaked-password protection is a production Auth configuration item, not a local code change.
- `customer_push_tokens` remains tied to T-157/Q-90 APNs deployment, which is externally blocked.
- Performance index findings should be handled as a future backend tuning package if the user wants to reduce advisor noise before a production launch.

## Remaining Blockers

- Q-90 APNs dispatch deployment: blocked on paid Apple Developer access, APNs secrets, and deploy authorization.
- Q-91 TestFlight/App Store submission: blocked on paid Apple Developer access and release/upload authorization.
- Q-92 production email domain and SMTP: blocked on production domain, SMTP secrets, and Auth configuration authorization.
