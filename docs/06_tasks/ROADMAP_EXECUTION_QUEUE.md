# Roadmap Execution Queue

Last verified: 2026-07-09.

Purpose: convert `ROADMAP.md` candidates into adoptable packages. This file does not assign `T-###` IDs. Each adopted package uses the next ID from `TASK_LEDGER.md`, one primary package per run.

Source: T-202 adopted root review input `../../V1.0_RELEASE_TASK_PLAN.md`; that root file is not an active task source.

## Selection Rules

- Start with the first unblocked Q-16...Q-33 unless the user names another package.
- Split any package that combines Supabase writes with visible SwiftUI or grows beyond one reviewable task.
- Get explicit authorization before migrations, Auth config writes, remote TestOps, seeds, deploys, release uploads, or other non-Git remote writes.
- Do not start Q-90...Q-92 until credentials and authorization are recorded.
- Q-01...Q-15 are complete and mapped in `ROADMAP.md`.

## Queue

| Order | Roadmap | Package | Mode | Scope | Validation |
|---|---|---|---|---|---|
| Q-16 | R-024 | P-01 Groomer notification backend | Deep | `groomer_notifications`, RLS, triggers for matches/offers/cancellations/messages. | Migration/RLS tests; `supabase-check` |
| Q-17 | R-024 | P-02 Groomer notification center UI | Standard | Store/View, read states, badge source, request/booking routing. | Focused Store tests; iOS build |
| Q-18 | R-025 | P-03 Foreground state timeliness | Standard | Scene refresh and Realtime fallback for matches/offers/bookings/notifications. | Store refresh tests; iOS build |
| Q-19 | R-028 | UT-01 Offer domain tests | Standard | Offer states, accepted/stale conflicts, withdraw rejection, empty/error lists. | Focused offer tests |
| Q-20 | R-028 | UT-02 Notification domain tests | Standard | Ordering, mark-all-read, concurrent read, event coverage, unknown types. | Focused notification tests |
| Q-21 | R-025 | P-04 Local appointment reminders | Standard | Local reminder scheduler, permission copy, refusal, revoke on cancel/complete. | Scheduler tests; iOS build |
| Q-22 | R-025 | P-05 Unread badge propagation | Standard | Customer/groomer notification and chat badge counts. | Badge tests; iOS build |
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
