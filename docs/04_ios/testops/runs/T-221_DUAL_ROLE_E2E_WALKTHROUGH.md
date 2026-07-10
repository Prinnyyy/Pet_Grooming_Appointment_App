# T-221 Dual-Role E2E Walkthrough Evidence

Date: 2026-07-09.
Branch: `codex/pet-fit-structure-cleanup`.
Queue package: Q-32 / R-029 / P-11.

## Scope

This run records local, no-write evidence for the current dual-role marketplace lifecycle. It verifies that TestOps can plan customer/groomer request, match, offer, booking, completion, and review flows from seeded data, and that the iOS TestOps launch wrapper reaches the authentication root with run/scenario launch arguments.

No Supabase remote write, migration, seed, cleanup, deploy, release upload, PR, tag, merge, rebase, reset, or force-push was performed.

## Commands

```bash
node scripts/testops.mjs doctor --dry-run

node scripts/testops.mjs run backend \
  --scenario marketplace_full_lifecycle \
  --matrix smoke5

node scripts/testops.mjs run matching \
  --scenario request_matching_eval \
  --matrix matching_baseline

TESTOPS_RUN_ID=TESTOPS-LOCAL-T221 \
./scripts/ios-testops-e2e.sh marketplace_full_lifecycle
```

## Result

Status: passed for local dry-run and launch-smoke scope.

| Evidence | Result | Notes |
|---|---|---|
| TestOps doctor | passed | Found 50 customer profiles and 50 groomer profiles. Supabase env vars were intentionally unset; dry-run completed without remote writes. |
| `marketplace_full_lifecycle` / `smoke5` | passed | Generated 5 redacted customer/groomer lifecycle plans: `TC-MKT-001` through `TC-MKT-005`. |
| `request_matching_eval` / `matching_baseline` | passed | Generated 8 matching plans: 5 positive target-inclusion cases and 3 negative hard-filter exclusion cases. |
| iOS TestOps launch smoke | passed | `TestOpsLaunchSmokeTests.testLaunchWithTestOpsArgumentsShowsAuthenticationRoot` passed with `TESTOPS_RUN_ID=TESTOPS-LOCAL-T221`. |

## Lifecycle Coverage

`smoke5` plans cover:

- `BTC-001` Toy Poodle with `BTG-001` curly/full groom.
- `BTC-003` Miniature Schnauzer with `BTG-003` wire/terrier studio groom.
- `BTC-004` Shih Tzu with `BTG-004` small drop-coat groom.
- `BTC-016` German Shepherd with `BTG-006` large double-coat groom.
- `BTC-049` Standard Poodle with `BTG-041` Orange County curly/full groom.

Each generated plan includes the customer seed, groomer seed, request payload, preferred window, service notes tagged with `TESTOPS:<run_id>`, and a groomer offer payload.

## Matching Coverage

`matching_baseline` dry-run projected:

- Positive target inclusion for curly Toy Poodle exact preferred window.
- Positive target inclusion for same-day capacity when preferred time is late.
- Positive target inclusion for wire/terrier studio full groom.
- Positive target inclusion for large double-coat full groom.
- Positive target inclusion for Orange County curly/full groom.
- Negative exclusion for service type mismatch.
- Negative exclusion for location mode mismatch.
- Negative exclusion for unavailable request day.

The dry-run output included local candidate projections and target `excludedReasons` without creating remote requests.

## Gap List

- Full backend lifecycle execution was not run in this task because remote writes require a fresh explicit authorization, `--execute`, and `TESTOPS_REMOTE_WRITE_APPROVED=1`.
- UI lifecycle automation currently stops at launch/authentication-root wiring. The next UI expansion should automate sign-in as customer, publish request, switch to groomer, create offer, switch to customer, accept offer, switch to groomer, complete booking, switch to customer, and create review, with backend/Debug verification rather than screenshots.
- Image upload, Storage cleanup, chat message send failure, and no-match diagnostics remain separate future TestOps scenarios.
- APNs dispatch, TestFlight/App Store submission, and production SMTP/custom domain remain externally blocked.
