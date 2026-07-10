# Roadmap Execution Queue

Last verified: 2026-07-09.

Purpose: convert `ROADMAP.md` candidates into adoptable packages. This file does not assign `T-###` IDs. Each adopted package uses the next ID from `TASK_LEDGER.md`, one primary package per run.

Source: T-202 adopted root review input `../../V1.0_RELEASE_TASK_PLAN.md`; that root file is not an active task source.

## Selection Rules

- Start with the first dependency-satisfied package; skip gated packages until authorization exists.
- Split packages that mix Supabase writes with SwiftUI or exceed one reviewable task.
- Get explicit authorization before migrations, Auth config writes, remote TestOps, seeds, deploys, release uploads, or other non-Git remote writes. Q-35 through Q-37 and Q-42 used the 2026-07-09 authorization.
- Q-92 is complete in T-242. Q-93 remains blocked because the hosted Free Plan cannot enable leaked-password protection.
- Q-90, Q-91, T-157, and the `customer_push_tokens` advisor finding are excluded from this remediation sequence because they depend on APNs or paid Apple Developer capabilities.
- Q-01...Q-43 are complete and mapped in `ROADMAP.md`.
- T-243 approved the Beckon identity contract in `BECKON_BRAND_MIGRATION.md`; Q-94/T-246 and Q-95/T-247 are complete, while Q-96 remains remote-write gated.

## Queue

| Order | Roadmap | Package | Dependencies / authorization | Exit signal |
|---|---|---|---|---|
| Q-96 | R-038 | Remote Beckon identity cutover | Q-94/Q-95 complete; fresh remote-write authorization | Supabase/Auth/runtime and 100 seed users use Beckon in place, UUIDs remain stable, and remote lifecycle/matching/Auth verification passes with zero residue. |

## Completed Beckon Package

| Order | Roadmap | Package | Result |
|---|---|---|---|
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
