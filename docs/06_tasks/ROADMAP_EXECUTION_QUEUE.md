# Roadmap Execution Queue

Last verified: 2026-07-10.

Purpose: convert `ROADMAP.md` candidates into adoptable packages. This file does not assign `T-###` IDs. Each adopted package uses the next ID from `TASK_LEDGER.md`, one primary package per run.

Source: T-202 adopted root review input `../../V1.0_RELEASE_TASK_PLAN.md`; that root file is not an active task source.

## Selection Rules

- Start with the first dependency-satisfied package; skip gated packages until authorization exists.
- Split packages that mix Supabase writes with SwiftUI or exceed one reviewable task.
- Get explicit authorization before migrations, Auth config writes, remote TestOps, seeds, deploys, release uploads, or other non-Git remote writes. Q-35 through Q-37 and Q-42 used the 2026-07-09 authorization.
- Q-92 is complete in T-242. Q-93 remains blocked because the hosted Free Plan cannot enable leaked-password protection.
- Q-90, Q-91, T-157, and the `customer_push_tokens` advisor finding are excluded from this remediation sequence because they depend on APNs or paid Apple Developer capabilities.
- Q-01...Q-43 are complete and mapped in `ROADMAP.md`.
- T-243 approved the Beckon identity contract in `BECKON_BRAND_MIGRATION.md`; Q-94/T-246, Q-95/T-247, and Q-96/T-248 are complete.
- T-249 approved `../08_design/GROOMER_UI_REDESIGN.md`; Q-97 through Q-104 implement R-039 without backend or remote writes.

## Queue

| Order | Roadmap | Package | Scope / Exit |
|---|---|---|---|
| Q-97 | R-039 | Groomer navigation shell and Home | Replace six-tab/More routing with Home, Requests, Schedule, Messages, Account; add read-only Home summaries and notification entry; update tab TestOps. |
| Q-98 | R-039 | Requests and Offers workspace | Add Matches/Offers segmentation, grouped request/offer lists, and approved request-detail hierarchy while preserving offer mutations and pagination. |
| Q-99 | R-039 | Schedule and Groomer booking presentation | Stabilize date controls, remove duplicate empty summaries, and apply the operational row/detail hierarchy without changing booking rules. |
| Q-100 | R-039 | Messages and Notifications | Apply grouped conversation/notification rows, preserve pagination/unread/deep links, and remove notification dependence on a More tab. |
| Q-101 | R-039 | Account and Edit Profile | Make Account a direct tab, group business/settings rows, hide the tab bar in Edit Profile, and provide one back action plus stable save bar. |
| Q-102 | R-039 | Services and Availability | Apply the focused editor shell and compact grouped rows while preserving service overrides, weekly hours, booking preferences, and time off. |
| Q-103 | R-039 | Fit Signals, Evidence, and Portfolio | Apply the approved density/image hierarchy while preserving size range, fit selection, evidence, upload/replace/delete, and cache behavior. |
| Q-104 | R-039 | Groomer UI integration gate | Verify compact/large viewports, Dynamic Type, state matrix, accessibility, selector TestOps, full iOS tests/build, and no More/duplicate navigation. |

Q-97 is the first dependency-satisfied package and receives the next available `T-###` only when the user starts it.

## Completed Beckon Package

| Order | Roadmap | Package | Result |
|---|---|---|---|
| Q-96 | R-038 | Remote Beckon identity cutover | Complete T-248: project/Auth/runtime and 100 seed users use Beckon in place, UUIDs remain stable, lifecycle is 5/5, matching is 8/8, tagged residue is zero, and full local gates pass. |
| Q-95 | R-038 | Beckon workflow vocabulary | Complete T-247: active agent/workflow sources use Beckon and are enforced by the permanent identity audit; no product or remote change. |
| Q-94 | R-038 | Local Beckon application and source identity | Complete T-246: canonical Xcode/app/source/TestOps/seed/design identity, permanent audit, prepared append-only runtime migration, and full local gates. |

## Completed Non-Apple Package

| Order | Roadmap | Package | Result |
|---|---|---|---|
| Q-92 | R-033 | Production email domain and SMTP | Complete T-242: verified Resend domain, Cloudflare DMARC, custom SMTP, exact Auth scheme URL configuration, and accepted delivery smoke. |

## Blocked Non-Apple Queue

| Order | Roadmap | Package | Blocker |
|---|---|---|---|
| Q-93 | R-033 | Supabase leaked-password protection | Supabase Pro-or-higher plan decision and Auth config authorization; the hosted Free Plan cannot clear this advisor warning. |

## Excluded Apple/APNs Queue

These existing items remain recorded for future recovery but are not part of the current remediation sequence.

| Order | Roadmap | Package | Blocker |
|---|---|---|---|
| Q-90 | R-030 | APNs dispatch deployment | Paid Apple Developer, APNs secrets, deploy authorization. |
| Q-91 | R-030 | TestFlight / App Store submission | Paid Apple Developer and release/upload authorization. |
