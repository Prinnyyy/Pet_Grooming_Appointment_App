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

## V1.0 Ideal Operation Extension

Adopted in T-202 from root review input `../../V1.0_RELEASE_TASK_PLAN.md`. The root file remains review input; this roadmap plus `ROADMAP_EXECUTION_QUEUE.md` is the active governed task source.

Target: before paid Apple capabilities are available, the app should run a complete customer/groomer marketplace lifecycle on Simulator or free-signing device with timely foreground state, local appointment reminders, clear recovery paths, and no known misleading placeholder behavior.

Acceptance signals:

- Customer and groomer can complete registration, role onboarding, profile setup, request publishing, matching, offer, acceptance, booking/chat, completion, and review.
- Both roles see relevant state changes while the app is open without blindly visiting every page.
- Appointment reminders use local notifications until APNs is unblocked.
- Free-tier email verification and custom scheme callback are verified separately from production SMTP/universal-link work.
- Swift Testing grows toward the managed target of at least 400 tests through focused unit packages.
- Final ideal-operation evidence reruns build/test/TestOps/advisor/context gates without remote release actions.

External blockers that do not block the local ideal-operation target: APNs dispatch deployment, TestFlight/App Store submission, and production SMTP/custom domain.

## Milestones

| Milestone | Goal | Status | Exit Signal |
|---|---|---|---|
| G0 Docs governance | Keep docs indexed and bounded. | T-163...T-179 complete. | Startup uses active indexes, not stale root/frozen plans. |
| M1 Half-finished surfaces | Remove incomplete UI/data behavior. | T-152, T-154, T-188 through T-192 complete; T-193 design complete with implementation dependency. | No placeholder surfaces or misleading inputs. |
| M2 Marketplace timeliness | Make request/offer/booking/chat state timely. | T-153, T-155, T-156, T-162, and T-194 complete; T-157 dispatch blocked. | Timely notifications/chat and cross-device states. |
| M3 Compliance and ops | Satisfy App Store and ops basics. | T-160, T-161, T-195, and T-197 through T-199 complete. | Metadata and operational evidence are ready. |
| M4 Quality expansion | Make tests/checks systematic. | T-165/T-168 started docs/preflight coverage; T-200 closes focused Store/state coverage; T-206/T-208/T-214/T-216 close offer, notification, decode/cache, and state-machine tolerance coverage. | Required checks are documented, runnable, and task-typed. |
| M5 Release | Prepare TestFlight/App Store release. | Local/read-only dry run complete in T-201; external release setup remains. | M1-M4 exits are satisfied and user authorizes release/tag work. |
| M6 Free-mode timeliness | Make local/foreground updates symmetric without APNs. | Q-16 through Q-18 and Q-21 through Q-22 complete. | Groomer/customer notifications, foreground refresh, local reminders, and unread badges are covered. |
| M7 Structural and edge resilience | Reduce oversized surfaces and close edge-case gaps. | Q-23 through Q-29 complete; planned Q-30 through Q-31. | Request/profile surfaces are split, republish/pagination/auth edges are tested, and unit coverage increases. |
| M8 Ideal operation verification | Prove the local V1.0 lifecycle end to end. | Planned Q-32 through Q-33. | Dual-role walkthrough evidence and readiness dry run pass. |
| D External release blockers | Track work that requires paid Apple or production credentials. | Blocked Q-90 through Q-92. | Only starts after credentials and explicit authorization exist. |

## Candidate Backlog

| Roadmap ID | Milestone | Candidate | Status |
|---|---|---|---|
| R-001 | G0 | Testing/migration workflow rules | Complete T-168 |
| R-002 | G0 | Active document structure reduction | Complete T-169 |
| R-003 | G0 | Context hygiene v3 fact checks | Complete T-170 |
| R-004 | G0 | Periodic meta-review template | Complete T-171 |
| R-005 | M1 | Private image rendering | Complete T-188 through T-191 |
| R-006 | M1 | Request wizard persistence decision | Complete T-192 |
| R-007 | M1 | Email deep link and production SMTP | Local custom-scheme callback complete T-217; production domain/SMTP remains blocked |
| R-008 | M2 | Realtime foreground chat | Complete T-194 |
| R-009 | M2 | APNs dispatch deploy | Blocked on Apple/APNs secrets |
| R-010 | M3 | Privacy/Support URLs | Complete T-195 |
| R-011 | M3 | Crash/funnel events | Complete T-197 |
| R-012 | M3 | Accessibility and copy audit | Complete T-198 |
| R-013 | M3 | Performance/network resilience | Complete T-199 |
| R-014 | M4 | Store/model/state/UI test expansion | Complete T-200 |
| R-015 | M5 | E2E/security, TestFlight, App Store | Local dry run complete T-201; TestFlight/App Store remote work waits on user authorization and external setup |
| R-016 | G0 | Rule-change process | Complete T-172 |
| R-017 | G0 | Main governance divergence reconciliation | Complete T-173 |
| R-018 | G0 | Decision log prearchive and governance review intake | Complete T-174 |
| R-019 | G0 | Context hygiene v4 failure-mode checks | Complete T-175 |
| R-020 | G0 | Entrypoint and branch fact-source alignment | Complete T-176 |
| R-021 | G0 | ROADMAP DoD and ignore cleanup | Complete T-177 |
| R-022 | G0 | Backtick path and Markdown waterline checks | Complete T-178 |
| R-023 | G0 | Active Markdown budget reduction | Complete T-179 |
| R-024 | M6 | Groomer notification symmetry | Complete T-203 and T-204 |
| R-025 | M6 | Foreground state timeliness, local reminders, unread badges | Q-18 complete T-205; Q-21 complete T-209; Q-22 complete T-210 |
| R-026 | M7 | Large SwiftUI/Store structural refactors | Complete T-211 and T-212 |
| R-027 | M7 | Recovery, auth callback, and pagination robustness | Q-27 complete T-215; Q-29 complete T-217; planned Q-30 |
| R-028 | M4/M7 | Focused unit and contract test expansion toward 400 tests | Q-19 complete T-206; Q-20 complete T-208; Q-25 complete T-213; Q-26 complete T-214; Q-28 complete T-216; planned Q-31 |
| R-029 | M8 | Ideal-operation walkthrough and readiness rehearsal | Planned Q-32 through Q-33 |
| R-030 | D | Paid/external release operations | Blocked Q-90 through Q-92 |

Completed mapping: T-152/T-154/T-188...T-193/T-217 M1 auth/UI foundations; T-153/T-155/T-156/T-162/T-194 M2; T-157 M2 blocked for dispatch; T-160/T-161/T-195/T-197...T-199 M3; T-200/T-206/T-208/T-213/T-214/T-216 M4 focused tests; T-201 M5 local dry run; T-203...T-205/T-209/T-210 M6 groomer notification, foreground refresh, local reminders, and unread badges; T-211/T-212/T-214...T-217 M7 request/profile splits, decode/cache tolerance, republish hardening, state-machine edge tests, and auth callback implementation; T-163...T-179/T-207/T-218 G0.

Execution sequencing: use `ROADMAP_EXECUTION_QUEUE.md` to select the next adoptable package. The queue is planning input only; each adopted package receives the next `T-###` from `TASK_LEDGER.md`. Active V1.0 ideal-operation sequencing continues at Q-30.
