# WP-05 Agreement Acceptance

T-376, 2026-09-08. Original WP-05 accepted; WP-06 follows.

## Contract

- Immutable published request and quote revisions; quote submission and acceptance send the reviewed revision. Atomic, idempotent replacement closes the old request/offers only after valid replacement publication. Failure preserves the original.
- Complete immutable quote/booking agreements include pet, service, price, time, service timezone, full address including unit, and source provenance. Booking detail and Chat booking hydration retain the agreement; unsupported historical addresses are explicitly unverified.
- Owned evaluation separates terminal validity from current capacity. Time-off/slot conflicts recover; withdrawal, supersession, eligibility and advance-notice policy changes cannot revive old consent. Missing optional preferences use admission defaults; incomplete schedules remain unavailable.
- Original acceptance receipts and recovery remain intact. Old unsafe mutation endpoints require an updated client. No account-timezone settings changes.

## Evidence

| Gate | Evidence |
|---|---|
| Installed SQL | `/tmp/beckon-t376-installed-agreement-vectors.log`: both service directions, address units/source deletion, profile isolation, authenticated ownership/private grants, revision rejection, replacement/replay/failure, deadline without cron, capacity recovery, non-reviving eligibility/notice changes and revision forgery rejection. All rollback fixtures restored. |
| Real HTTP | `/tmp/beckon-t376-races-lock-chain.log`: acceptance/Save and acceptance/replacement, both winner orders; one winner, authoritative readback/replay, exact 39-field restoration. Private run `artifacts/testops/T376-8542f028-809f-4a62-9b5d-e916e8253b26`. |
| Client | Full `/tmp/beckon-t376-full-integration.log` had one obsolete copy assertion; corrected assertion and all targeted Customer/transport/agreement cases passed `/tmp/beckon-t376-final-client.log`. Final `/tmp/beckon-t376-final-recovery-deadline.log` passes Customer/Agreement suites, exact local cutoff and persistent acceptance recovery projection. |
| Runtime | `/tmp/beckon-t376-final-runtime.log`: both roles, verified/legacy booking details and replacement review. Five screenshots exported and representative verified/legacy/replacement images inspected; complete unit address, explicit unknown history and Replace Request warning/button render without overlap. |
| Build/static | `/tmp/beckon-t376-final-build.log`, `/tmp/beckon-t376-notice-preflight.log`; final 11 migration/barrier cases pass; strict hygiene and diff checks pass. |
| Deployment | Both `20260908203810` and `20260908212824` applied and immutable; `/tmp/beckon-t376-final-history.log` shows 77 aligned versions; `/tmp/beckon-t376-final-dry-run.log` is empty. |
| Advisors | Post-deploy security: no ERROR, existing Q-93 and three intentional server-owned RLS INFOs. Performance: existing FK/index INFOs, none for new agreement/lineage objects. |

## Failures And Limits

- Reproduced and fixed request mutation, source-deletion guard, absent-preference evaluation and notice-policy revival defects. The second migration is append-only; the first applied migration was not edited.
- Initial request barrier held longer than authenticated statement timeout and required direct blocking; rejected observations were not counted. Shorter wait plus a verified lock chain to the same holder passed both genuine request contention orders. Fixture restoration passed on failed runs too.
- Default full UI runs three cases and skips six environment-gated cases; skips are not acceptance. Physical-device interruption, compatible binary distribution, generic TestOps legacy-RPC migration and earlier keyboard-visible screenshot remain WP-14. Fulfillment and later bilateral changes remain WP-06/WP-07, not claimed here.
