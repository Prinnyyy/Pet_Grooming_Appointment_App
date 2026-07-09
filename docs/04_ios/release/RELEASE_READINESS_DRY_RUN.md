# Release Readiness Dry Run

Last verified: 2026-07-09.

Task: T-201 / R-015 / Q-15.
Branch: `codex/pet-fit-structure-cleanup`.
Scope: local and read-only release readiness evidence. This dry run did not upload a build, change App Store Connect, deploy Edge Functions, apply migrations, seed data, or execute remote TestOps writes.

## Passed Gates

- `./scripts/preflight.sh`
- `./scripts/testops-unit.sh`
- `node --test tests/ios/app-store-privacy.test.mjs`
- `node scripts/testops.mjs doctor --dry-run`
- `node scripts/testops.mjs run backend --scenario marketplace_full_lifecycle --matrix smoke5`
- `node scripts/testops.mjs run matching --scenario request_matching_eval --matrix matching_baseline`
- `TESTOPS_RUN_ID=TESTOPS-T201-LOCAL ./scripts/ios-testops-e2e.sh marketplace_full_lifecycle`
- `./scripts/supabase-check.sh`
- `supabase db advisors --linked --type security`
- `supabase db advisors --linked --type performance`
- `./scripts/ios-test.sh`
- `./scripts/ios-build.sh`

## Advisor Results

- Security advisor returned the known Auth leaked-password protection WARN. No new release-blocking schema, RLS, or SECURITY DEFINER finding appeared.
- Performance advisor returned no issues.

## Evidence Notes

- The marketplace `smoke5` and matching baseline TestOps commands were dry-run only. They generated deterministic local plans without remote mutations.
- The TestOps UI launch smoke verified the TestOps launch-argument path reaches the authentication root.
- App Store privacy checks confirmed release Privacy Policy and Support URLs are configured and the privacy manifest remains aligned with the checklist.
- `scripts/supabase-check.sh` was narrowed to flag env-style service-role assignments and `sb_secret_...` values, avoiding a false positive on test code that names `SUPABASE_SERVICE_ROLE_KEY` as an object key.

## Deferred Release Work

- Q-07 production auth email/deep-link implementation still waits for a production auth domain and SMTP credentials.
- Q-09 APNs dispatch still waits for Apple Developer Program access and APNs secrets.
- Remote TestOps smoke execution, TestFlight upload, App Store Connect metadata entry, release tagging, and submission require fresh user authorization.
