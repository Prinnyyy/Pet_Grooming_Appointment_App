# Managed Roadmap

Last verified: 2026-07-09.

This is the governed planning index. It summarizes approved direction and candidate work without assigning task IDs. Adoptable execution packages live in `ROADMAP_EXECUTION_QUEUE.md`. Task status stays in `TASK_LEDGER.md`; current branch, validation, and risks stay in `../00_memory/CURRENT_STATE.md`.

## Adoption Rules

- External agent reports and root roadmap drafts are review input only.
- A roadmap item becomes managed only after the user asks to adopt or execute it.
- Do not copy old task numbers from external plans; implementation uses the next `T-###` from `TASK_LEDGER.md`.
- Scope/release/planning changes need a `../07_decisions/DECISION_LOG.md` entry.
- Completed items must point to the closing ledger row or evidence.
- Do not start the next roadmap item automatically. One user request equals one primary task.

Inputs: active facts from `TASK_LEDGER.md`, `ROADMAP_EXECUTION_QUEUE.md`, `../00_memory/CURRENT_STATE.md`, and `../00_memory/FEATURE_INDEX.md`; review input from frozen external reports only.

## V1.0 DoD

Checklist:

- Placeholder UI is removed or explicitly deferred.
- Required fields persist or are removed from production surfaces.
- Authorized private images render or are explicitly deferred.
- Request expiry behavior is implemented and verified.
- Match backfill behavior is implemented and verified.
- Cancelled request and booking recovery paths are clear.
- Customer notification behavior is clear.
- Foreground chat timeliness is clear.
- Account deletion is implemented and documented.
- Privacy Policy and Support URLs are ready.
- Privacy Manifest is present and checked.
- App Store notes/materials are ready.
- Build, test, and E2E gates are defined.
- Supabase advisors show no unresolved new release-blocking findings.

Boundary: Open Request -> Groomer Offer -> Customer Confirmation -> Booking; no SwiftUI direct Supabase access; remote writes require explicit authorization.

Out of V1.0 unless explicitly changed: payments, subscriptions, public directory, map-first discovery, AI recommendations, multi-pet requests, favorites, chat attachments, read receipts, groomer review replies, request editing, admin tooling, and social login.

## Milestones

| Milestone | Goal | Status | Exit Signal |
|---|---|---|---|
| G0 Docs governance | Keep docs indexed and bounded. | T-163...T-179 complete. | Startup uses active indexes, not stale root/frozen plans. |
| M1 Half-finished surfaces | Remove incomplete UI/data behavior. | T-152, T-154, T-188 through T-192 complete; T-193 design complete with implementation dependency. | No placeholder surfaces or misleading inputs. |
| M2 Marketplace timeliness | Make request/offer/booking/chat state timely. | T-153, T-155, T-156, T-162, and T-194 complete; T-157 dispatch blocked. | Timely notifications/chat and cross-device states. |
| M3 Compliance and ops | Satisfy App Store and ops basics. | T-160, T-161, T-195, and T-197 through T-199 complete. | Metadata and operational evidence are ready. |
| M4 Quality expansion | Make tests/checks systematic. | T-165/T-168 started docs/preflight coverage. | Required checks are documented, runnable, and task-typed. |
| M5 Release | Prepare TestFlight/App Store release. | Proposed only. | M1-M4 exits are satisfied and user authorizes release/tag work. |

## Candidate Backlog

| Roadmap ID | Milestone | Candidate | Status |
|---|---|---|---|
| R-001 | G0 | Testing/migration workflow rules | Complete T-168 |
| R-002 | G0 | Active document structure reduction | Complete T-169 |
| R-003 | G0 | Context hygiene v3 fact checks | Complete T-170 |
| R-004 | G0 | Periodic meta-review template | Complete T-171 |
| R-005 | M1 | Private image rendering | Complete T-188 through T-191 |
| R-006 | M1 | Request wizard persistence decision | Complete T-192 |
| R-007 | M1 | Email deep link and production SMTP | Design complete T-193; implementation waits on domain/SMTP |
| R-008 | M2 | Realtime foreground chat | Complete T-194 |
| R-009 | M2 | APNs dispatch deploy | Blocked on Apple/APNs secrets |
| R-010 | M3 | Privacy/Support URLs | Complete T-195 |
| R-011 | M3 | Crash/funnel events | Complete T-197 |
| R-012 | M3 | Accessibility and copy audit | Complete T-198 |
| R-013 | M3 | Performance/network resilience | Complete T-199 |
| R-014 | M4 | Store/model/state/UI test expansion | Candidate |
| R-015 | M5 | E2E/security, TestFlight, App Store | Proposed |
| R-016 | G0 | Rule-change process | Complete T-172 |
| R-017 | G0 | Main governance divergence reconciliation | Complete T-173 |
| R-018 | G0 | Decision log prearchive and governance review intake | Complete T-174 |
| R-019 | G0 | Context hygiene v4 failure-mode checks | Complete T-175 |
| R-020 | G0 | Entrypoint and branch fact-source alignment | Complete T-176 |
| R-021 | G0 | ROADMAP DoD and ignore cleanup | Complete T-177 |
| R-022 | G0 | Backtick path and Markdown waterline checks | Complete T-178 |
| R-023 | G0 | Active Markdown budget reduction | Complete T-179 |

Completed mapping: T-152/T-154/T-188...T-193 M1; T-153/T-155/T-156/T-162/T-194 M2; T-157 M2 blocked for dispatch; T-160/T-161/T-195/T-197...T-199 M3; T-163...T-179 G0.

Execution sequencing: use `ROADMAP_EXECUTION_QUEUE.md` to select the next adoptable package. The queue is planning input only; each adopted package receives the next `T-###` from `TASK_LEDGER.md`.
