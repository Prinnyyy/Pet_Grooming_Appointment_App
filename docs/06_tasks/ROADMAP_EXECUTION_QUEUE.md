# Roadmap Execution Queue

Last verified: 2026-07-11.

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
- T-249 approved `../08_design/GROOMER_UI_REDESIGN.md`; T-250 completed Q-97, T-252 completed Q-98, T-253 completed Q-99, T-254 completed Q-100, T-255 completed Q-101, T-256 completed Q-102, T-257 completed Q-103, and T-258 completed default-text/selector integration verification. Q-104 retains only user-deferred Dynamic Type and Accessibility work; it has no backend or remote writes.
- T-291 approved `APPLE_MAPS_ADDRESS_SYSTEM_PLAN.md`; T-292 completed Q-105, T-293 completed Q-106, T-294 completed Q-107, and T-296 remotely completed Q-108. Q-109 through Q-112 continue feature integrations, controlled backfill, and strict coordinate cutover.

## Queue

| Order | Roadmap | Package | Scope / Exit |
|---|---|---|---|
| Q-109 | R-040 | Customer and Groomer Profile integration | Reuse the shared editor, atomically save confirmed display/private location data, preserve cache behavior, and expose confirmed profile address autofill. |
| Q-110 | R-040 | Customer Request integration | Require confirmation before Time & Location advances, publish through versioned RPC, snapshot Line 2, retain safe republish behavior, and verify radius matching. |
| Q-111 | R-040 | Controlled legacy address backfill | Dry-run-default MapKit tool, explicit write gate, ambiguous-address review, authorized profile/request backfill, zero-gap verification, and radius Matching TestOps. |
| Q-112 | R-040 | Strict coordinate cutover and integration gate | Remove city/state fallback only after zero active gaps; run full iOS/Supabase/TestOps/privacy gates and prove one shared address implementation. |
| Q-104 | R-039 | Groomer Dynamic Type and Accessibility integration gate | Complete the remaining Dynamic Type and Accessibility state/interaction audit after the user restores this deferred scope; rerun affected selector and full iOS regression gates. |

Q-109 is the first dependency-satisfied product package and receives the next available task ID. The user's 2026-07-11 authorization still covers the planned Q-111 backfill, but execution stops if project identity, migration history, private privileges, or zero-gap evidence conflicts.

## Completed Address Package

| Order | Roadmap | Package | Result |
|---|---|---|---|
| Q-108 | R-040 | Authorized remote address schema application | Complete T-296: applied only the reviewed T-294 migration to Beckon, verified private grants, owner RPCs, both radius directions, multilingual-city invariance, explicit fallback, linked history, rollback cleanup, advisors, and zero backfill. |
| Q-107 | R-040 | PostGIS/private location migration preparation | Complete T-294 locally: one pending append-only PostGIS/private-location migration, owner profile read/write wrappers, coordinate Request v2, distance/radius helper, explicit legacy fallback, rollback validation, and all migration/linked dry-run gates; no remote application. |
| Q-106 | R-040 | Shared editor and confirmation UI | Complete T-293: one provider-injected Line 1/Line 2 editor, non-reflowing candidate list, global auto-move notice, inline conflict/error state, compact status, multi-result choice, entered-vs-suggested confirmation, and stable selectors; no feature persistence or backend write. |
| Q-105 | R-040 | Shared address domain and parser | Complete T-292: provider-neutral address values/provider, complete secondary suffix and conflict rules, direct localized MapKit candidates, selected/manual resolution, compatible-query retention, and focused/full iOS regression evidence; no backend write. |

## Completed Groomer Package

| Order | Roadmap | Package | Result |
|---|---|---|---|
| T-258 | R-039 | Non-Accessibility integration verification | Complete: default-text compact/large Simulator checks plus seeded Groomer TestOps prove five direct tabs, six focused Account workspaces, one Back action, hidden editor tabs, and no `More`; full iOS tests/build and preflight pass. |
| Q-103 | R-039 | Fit Signals, Evidence, and Portfolio | Complete T-257: compact Fit Signals selection/size balance, truthful Evidence overview/empty state, and image-first Portfolio gallery/detail with fit-note save/delete controls; existing Store mutations, global feedback, authenticated cache, and selectors preserved. |
| Q-102 | R-039 | Services and Availability | Complete T-256: compact grouped services and availability surfaces; focused service/time-off forms with stable saves; existing weekly hours, booking preferences, size overrides, and mutations preserved through the Store path. |
| Q-101 | R-039 | Account and Edit Profile | Complete T-255: direct Account tab with Business, Matching & Schedule, and Support groups; truthful live summaries; focused Edit Profile with one Back action, hidden tab bar, stable Save Profile bar, preserved feedback, and stable selectors. |
| Q-100 | R-039 | Messages and Notifications | Complete T-254: Groomer-only grouped conversations and notifications, preserved unread/pagination/thread/read/Home-route behavior, stable row selectors, and trailing list inset above the tab bar. |
| Q-99 | R-039 | Schedule and Groomer booking presentation | Complete T-253: fixed date controls, one truthful empty state or populated-day summary, grouped operational rows, and role-correct booking Cancel/Complete actions. |
| Q-98 | R-039 | Requests and Offers workspace | Complete T-252: live-count segmentation, grouped match/offer rows, correct Home/notification routes, focused IDs, request detail/action hierarchy, and preserved pagination/mutations. |
| Q-97 | R-039 | Groomer navigation shell and Home | Complete T-250: five direct tabs, live/cache-aware Home summaries, Home notification entry, data-ready Availability deep link, updated TestOps selectors, and no system More. |

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
