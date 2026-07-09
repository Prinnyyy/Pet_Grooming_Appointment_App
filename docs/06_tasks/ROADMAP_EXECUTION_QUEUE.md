# Roadmap Execution Queue

Last verified: 2026-07-09.

Purpose: convert `ROADMAP.md` candidates into adoptable packages. This file does not assign `T-###` IDs. Each adopted package uses the next ID from `TASK_LEDGER.md`, one primary package per run.

Source: T-202 adopted root review input `../../V1.0_RELEASE_TASK_PLAN.md`; that root file is not an active task source.

## Selection Rules

- Start with the first unblocked Q-21...Q-33 unless the user names another package.
- Split any package that combines Supabase writes with visible SwiftUI or grows beyond one reviewable task.
- Get explicit authorization before migrations, Auth config writes, remote TestOps, seeds, deploys, release uploads, or other non-Git remote writes.
- Do not start Q-90...Q-92 until credentials and authorization are recorded.
- Q-01...Q-15 are complete and mapped in `ROADMAP.md`.

## Queue

| Order | Roadmap | Package | Mode | Scope | Validation |
|---|---|---|---|---|---|
| Q-23 | R-026 | P-06 Split `CustomerRequestsView.swift` | Standard | Structure-only wizard/list/detail split; behavior preserved. | Full iOS test/build |
| Q-24 | R-026 | P-07 Split groomer profile surfaces | Standard | Structure-only services/portfolio/availability/fit split. | Full iOS test/build |
| Q-25 | R-028 | UT-03 Time and boundary tests | Standard | Midnight/DST, expiry edge, time-off overlap, size limits, daily capacity. | Focused time/matching tests |
| Q-26 | R-028 | UT-04 Decode/data tolerance tests | Standard | Optional fields, unknown enums, bad dates, null/empty arrays, cache/image corruption. | Focused decoding/cache tests |
| Q-27 | R-027 | P-08 T-162 republish hardening | Standard | Missing/expired original requests and missing photos. | RED/GREEN republish tests |
| Q-28 | R-028 | UT-05 State-machine edge tests | Standard | Draft retention/discard, republish mapping, refresh dedupe, reminder idempotence. | Focused state tests |
| Q-29 | R-027 | P-09 Free-tier email verification/deep link | Deep | Supabase default email plus custom URL scheme; document production gap. | Auth/callback tests; device/simulator check |
| Q-30 | R-027 | P-10 List pagination/load audit | Standard | Request/offer/booking/message/notification limits and pagination. | Audit note; pagination tests |
| Q-31 | R-028 | UT-06 Backend contract negatives | Deep | Notification RLS and protected RPC rejection tests. | Node/Supabase contract tests |
| Q-32 | R-029 | P-11 Dual-role E2E walkthrough | Deep | Local customer/groomer lifecycle evidence and gap list. | Evidence doc; TestOps dry-runs |
| Q-33 | R-029 | P-12 Ideal-operation readiness rehearsal | Deep | Full local/read-only readiness gates after Q-16...Q-32. | Full build/test/TestOps/advisor gates |

## Blocked External Queue

| Order | Roadmap | Package | Blocker |
|---|---|---|---|
| Q-90 | R-030 | APNs dispatch deployment | Paid Apple Developer, APNs secrets, deploy authorization. |
| Q-91 | R-030 | TestFlight / App Store submission | Paid Apple Developer and release/upload authorization. |
| Q-92 | R-030 | Production email domain and SMTP | Production domain, SMTP secrets, Auth config authorization. |
