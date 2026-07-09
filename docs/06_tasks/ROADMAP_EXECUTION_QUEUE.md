# Roadmap Execution Queue

Last verified: 2026-07-09.

Purpose: convert `ROADMAP.md` candidates into adoptable packages. This file does not assign `T-###` IDs. Each adopted package uses the next ID from `TASK_LEDGER.md`, one primary package per run.

Source: T-202 adopted root review input `../../V1.0_RELEASE_TASK_PLAN.md`; that root file is not an active task source.

## Selection Rules

- Start with the first dependency-satisfied package; skip gated packages until authorization exists.
- Split packages that mix Supabase writes with SwiftUI or exceed one reviewable task.
- Get explicit authorization before migrations, Auth config writes, remote TestOps, seeds, deploys, release uploads, or other non-Git remote writes. On 2026-07-09 the user authorized the currently listed remote packages Q-35, Q-36, Q-37, and Q-42; each still runs as a separate task with its own prerequisite and safety checks.
- Q-92 and Q-93 remain blocked by their stated external prerequisites; the remote authorization does not supply missing domain/SMTP credentials or a Supabase plan upgrade.
- Q-90, Q-91, T-157, and the `customer_push_tokens` advisor finding are excluded from this remediation sequence because they depend on APNs or paid Apple Developer capabilities.
- Q-01...Q-34 and Q-38 are complete and mapped in `ROADMAP.md`.

## Queue

| Order | Roadmap | Package | Mode | Scope | Validation |
|---|---|---|---|---|---|
| Q-35 | R-031 | Groomer in-app notification remote parity | Deep | Apply existing T-203 migration; verify history, grants, RLS, RPCs, triggers, list/read state. Excludes APNs, push tokens, and Edge Functions. | Contract tests; authorized migration; linked parity/advisors; focused iOS tests/build. |
| Q-36 | R-032 | Evidence-backed foreign-key index migration | Deep | Depends on Q-34. Add only justified indexes; never remove one solely from low-traffic `unused_index` output. | Migration/rollback tests; authorized apply; advisor and safe plan comparison; Supabase check. |
| Q-37 | R-034 | Remote TestOps lifecycle and matching evidence | Deep | Run `smoke5` and `matching_baseline` with unique IDs, safety gates, redacted artifacts, and cleanup. | Unit/doctor checks; authorized run; 5/5 and 8/8 pass; zero residue. |
| Q-39 | R-036 | Booking and notification pagination | Standard | Expose booking pagination and add customer/groomer notification paging with retry/end states. | Focused tests; full iOS test/build; Simulator check. |
| Q-40 | R-036 | Conversation and message-history pagination | Standard | Page conversations and older messages without duplicates, reordering, or reader-position jumps. | Chat ordering/dedupe/cancellation/scroll tests; full iOS test/build; Simulator check. |
| Q-41 | R-035 | UI TestOps harness and stable selectors | Standard | Add stable identifiers and no-screenshot drivers for seeded sign-in, session reset, tabs, and workflow sheets. No remote writes. | UI navigation/TestOps launch tests; full iOS test/build. |
| Q-42 | R-035 | Full dual-role UI lifecycle automation | Deep | Depends on Q-41. Automate publish -> offer -> accept -> booking/chat -> complete -> review with backend/Debug assertions, tags, and cleanup. | Authorized run; transition assertions; zero residue; full iOS test/build. |

## Blocked Non-Apple Queue

| Order | Roadmap | Package | Blocker |
|---|---|---|---|
| Q-92 | R-033 | Production email domain and SMTP | Verified production domain, SMTP provider credentials, DNS control, and Auth config authorization. |
| Q-93 | R-033 | Supabase leaked-password protection | Supabase Pro-or-higher plan decision and Auth config authorization; the hosted Free Plan cannot clear this advisor warning. |

## Excluded Apple/APNs Queue

These existing items remain recorded for future recovery but are not part of the current remediation sequence.

| Order | Roadmap | Package | Blocker |
|---|---|---|---|
| Q-90 | R-030 | APNs dispatch deployment | Paid Apple Developer, APNs secrets, deploy authorization. |
| Q-91 | R-030 | TestFlight / App Store submission | Paid Apple Developer and release/upload authorization. |
