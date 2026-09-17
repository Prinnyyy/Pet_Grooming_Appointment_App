# T-373 Acceptance Reliability Evidence

Date: 2026-09-07. Scope: functional-reliability WP-02, F-11 and F-12.

## Delivered

- Authoritative owned pet identity on bookings; native pet interval exclusion and shared groomer admission guard enforce occupancy and daily capacity. Legacy audit found no unresolved pet identities or existing conflicting pet bookings.
- Accepted owned offers replay the original booking/conversation receipt with current status, without another booking or lifecycle message. A read-only lookup reconciles ambiguous outcomes; competing and unauthorized offers remain rejected.
- Offer creation, withdrawal and dismissal acquire the request lock before child rows, matching acceptance ordering.
- Account-scoped unresolved offer identity persists before submission and survives independent process launches. Recovery checks the original offer before explicit retry and presents cancelled/completed state without re-confirmation.
- Late successful acceptance replies and post-acceptance refresh results are checked against the active account before publishing state or returning a navigation handoff. Refresh failure copy does not assume the booking remains confirmed.

## Evidence

- Same-pet overlap reproduced before the migration. Deployed migration: `20260907233627_t373_pet_capacity_acceptance.sql`. All 73 migration versions aligned and the repeat dry run was empty; advisors retained existing Q-93 only.
- Rollback SQL verified authenticated acceptance, same-pet rejection, direct-writer exclusion, immutable allocation, client write denial, original receipt/message counts, pending lookup, cancellation releasing capacity, current cancelled/completed replay, anonymous and foreign-owner rejection. Every rollback fixture was removed transactionally.
- Final HTTP runner passed eight cases: same pet/different groomers, same groomer/different customers, different pets/different groomers, daily quota with nonoverlapping times, duplicate submission, competing offers, withdrawal versus acceptance, and creation versus acceptance. Each barrier observed two distinct blocked database sessions. Exact original schedule rows/revisions and booking/match hashes were restored.
- Response-loss behavior is verified in layers: real HTTP acceptance followed by receipt lookup/replay, plus a Store network-error fake and independent write/recover process launches. Each phase passed 109 Store tests; recovery made no new acceptance write and displayed current cancellation. This is not a physical multi-device network interruption or power-loss test.
- New refresh-after-signout regression failed on stale request publication before the fix and passed after it. Final full iOS regression passed 463 uniquely reported Swift cases, including 109 Customer Requests cases. The phase-gated process test is covered by the separate launches above. Default UI suite executed three cases and skipped six credential/write-gated cases; skips are not end-to-end acceptance evidence.
- Final preflight passed 89 migration and 10 function tests. Final iOS build and diff check passed; only the existing AppIntents metadata extraction information remains. Review was local; subagents remain disabled.

## Repeatable Checks

Remote tests require explicit authorization for the named Beckon test accounts and must not overlap another linked CLI or fixture writer.

```sh
TESTOPS_REMOTE_WRITE_APPROVED=1 node scripts/test-t373-acceptance-races.mjs
```

Rollback cases: [T-373_ACCEPTANCE_ROLLBACK.sql](T-373_ACCEPTANCE_ROLLBACK.sql). HTTP recovery snapshots remain in ignored `artifacts/testops/`; unknown outcomes require reconciliation before cleanup.

Local evidence logs: `/tmp/beckon-t373-resume-races.log`, `/tmp/beckon-t373-refresh-red.log`, `/tmp/beckon-t373-refresh-full-green.log`, `/tmp/beckon-t373-resume-preflight.log`, `/tmp/beckon-t373-resume-build.log`, and the earlier independent-process logs referenced in the Worklog. Method-only filters that executed zero tests were excluded from evidence.

## Limits

WP-03 through WP-14 are not delivered here. Current occupancy/completion semantics remain unchanged pending the timing and fulfillment packages. Rescheduling must preserve or deliberately extend the allocation guard. Global account-exit/reminder cleanup remains WP-09; the acceptance session checks do not claim to solve every asynchronous account workflow. Physical-device network interruption, forced-power-loss durability and integrated release qualification remain unverified. Compatible-client distribution remains WP-14. No migration was redeployed during this final continuation.
