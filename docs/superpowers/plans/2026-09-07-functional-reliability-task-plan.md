<!-- task-artifact
task: T-367
status: completed
type: plan
-->
# Beckon Functional Reliability Task Plan

Historical accepted plan. The original execution instructions below are retained as evidence, not current workflow rules. [Development Guide](../../05_workflow/DEVELOPMENT_GUIDE.md) now owns execution; T-367 authoring provenance remains distinct from functional acceptance through T-385.

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:executing-plans` for one explicitly adopted work package at a time. Subagents remain disabled. Read this plan's contracts, decision gates, and the selected package before execution. An unchecked package is not permission to start it.

**Goal:** Resolve the recorded functional defects and adopted lifecycle gaps without replacing Beckon's request-first marketplace or introducing unnecessary infrastructure.

**Architecture:** Keep SwiftUI presentation thin and preserve Store/repository ownership and controlled backend mutations. Share availability semantics across matching, offers, and acceptance; preserve versioned booking facts; distinguish authoritative business outcomes from optional UI enrichment and notification delivery.

**Tech Stack:** Existing Swift/SwiftUI, Supabase Auth/Postgres/RPC/RLS, UserNotifications, Swift Testing, and Node SQL-contract tests. No new dependency or deployment platform is proposed.

**Spec:** [App Functional Design Findings](../../06_tasks/APP_FUNCTIONAL_DESIGN_FINDINGS.md), F-01 through F-15, C-01 through C-03, and L-01 through L-04; the Reviewed Solution Contract below preserves the solution discussion and its subsequent self-review corrections.

**Status:** Local functional execution completed through T-385 on 2026-09-10 under the user's delegated judgment and necessary-operation authorization. WP-00 through WP-14 and all 22 items have evidence/dispositions in [final acceptance](../../06_tasks/sql_reviews/T-385_RELEASE_CHECKPOINT.md). Physical devices, signing and store distribution are outside scope. T-367 remains this master document's authoring owner; its historical documentation closeout is separate from functional completion.

**Baseline:** Source `fc7da7317938500b53100330363f91d4e71ab208`, branch `codex/pet-fit-structure-cleanup`, reviewed 2026-09-07. Local source findings are not proof of current deployed behavior.

## Global Constraints

- Execution, validation, Git, and remote authorization are owned by [Single-Agent Workflow](../../05_workflow/SINGLE_AGENT_WORKFLOW.md), [Tooling Policy](../../05_workflow/TOOLING_POLICY.md), and [GitHub Rules](../../05_workflow/GITHUB_RULES.md). This plan does not override them.
- One adopted primary task per session. WP-00 through WP-14 are plan-local work-package IDs, not allocated T-task numbers or Codex tasks. Allocate the ledger's next available number only when work is explicitly adopted, respecting any reserved governance review.
- Keep existing user work. No dependency, signing, entitlement, role-capability, schema, RPC, Storage, or non-Git remote change is authorized by the request to write this plan.
- Backend changes use newly generated migrations at implementation time; do not edit historical migrations or invent migration timestamps. Remote apply, test-data writes, cleanup, and deployment need named authorization.
- Do not turn uncertain findings into established production defects. Keep read-only/source tests, Swift tests, database transaction tests, and device evidence distinct.
- Preserve current publication replay, participant authorization, request-first routing, and atomic acceptance while extending their contracts. Do not add a public groomer directory or calendar-first direct booking.
- Payments, financial penalties, dispute arbitration, route optimization, a general event-sourcing framework, and broad UI redesign are outside this plan. T-157 APNs, Q-104 accessibility, and Q-93 remain separately gated; fixing a reminder does not authorize push deployment.
- Policy proposals below require approval, not inferred consent. A package blocked by a decision stops at that gate; independent approved packages can proceed.

## Scope And Deliverables

This is one master task plan with independently reviewable packages, not one large implementation task. Each adopted package produces its own bounded changes, regression evidence, compatible rollout notes, and closeout. Before coding a package, finalize its exact wire/type signatures and a short executable TDD checklist from its approved contracts; this document deliberately does not invent production SQL for undecided business rules.

Completion requires all 22 register items to be resolved or explicitly dispositioned, all eight self-review corrections below to be accounted for, and the integrated reliability gates to pass. An optional simplification can be retained with a documented justification; a correctness defect cannot be called fixed merely because its implementation was deferred.

## Decision Gates

WP-00 choices are adopted in the product/backend owners and Decision Log. D-042 owns [timing semantics and bounds](../../03_backend/SERVICE_TIMING_CONTRACT.md); D-043 through D-052 and [T-385 final disposition](../../06_tasks/sql_reviews/T-385_RELEASE_CHECKPOINT.md) account for all remaining gates and measured budgets. The table preserves the original questions; none remains an unassigned functional blocker. Adoption is distinguished from the package-specific deployment/acceptance evidence.

| Gate | Proposed direction and required decision | Blocks |
|---|---|---|
| G-01 Time meaning | The whole customer-facing service fits the selected window; outside-window/date alternatives require explicit permission. Confirm service-location timezone, earliest permissible start, and interpretation of advance-notice days. | WP-03, WP-04, WP-05 |
| G-02 Resource occupancy | Separate service time from groomer preparation, cleanup, and mobile travel allowances. Confirm buffer values/bounds, daily-count rules, and the release rule after interruption. Fixed travel allowances are estimates, not guaranteed arrival times. | WP-03, WP-06, WP-07 |
| G-03 Offer commitment | Pending offers do not hold slots. Separate valid terms from current slot selectability; cap confirmation at the earliest applicable deadline. Confirm waiting lifetime and explicit terminal-invalidity reasons. | WP-05 |
| G-04 Revisions and history | A quote binds a request revision; acceptance binds that quote revision; later booking changes are explicit. Confirm how customers revise open requests and how unverifiable legacy booking details are presented and reconfirmed. | WP-05 |
| G-05 Unknown service data | Explicit exclusions are hard filters; experience is ranking evidence. Unknown duration/accepted-size data is not a proven fit or automatic rejection. Confirm a bounded assessment path and existing-account transition before enforcement. | WP-03, WP-04 |
| G-06 Actual fulfillment | Separate scheduled and actual service times. Confirm who records start/end, earliest allowed start, early completion, correction of mistakes, pre-start cancellation, interruption, and no-show waiting/release rules. | WP-06 |
| G-07 Rescheduling | One live proposal per booking; preserve the old booking until accepted; define deadlines and competing-action behavior. Recommend time-only rescheduling initially, with participant/pet/service replacement requiring a new request. Address changes still require an explicit versioned agreement. | WP-07 |
| G-08 Reading versus acknowledgement | Decide whether booking acknowledgement is an independent cross-device business action or only dismissal of a presentation card. Separately approve when notifications become read; reading must not change fulfillment state. | WP-10 |
| G-09 Unfulfilled service and support | Define an actor, terminal outcome, and customer next action for no-show/interruption. Identify a real support owner before promising adjudication; absent that owner, record facts and objections without automatically assigning blame or penalties. | WP-06, WP-14 |
| G-10 Quality evidence | Approve the representative matching dataset, acceptable fairness/feasibility tradeoffs, and measured latency/query budgets after collecting a baseline. Do not invent an accuracy or speedup target without evidence. | WP-04 quality signoff, WP-13, WP-14 |

## Reviewed Solution Contract

These constraints supersede ambiguous wording in the earlier conversational proposal, subject to the policy gates above.

1. **Request -> Offer -> Booking revisions:** changing an open request's critical constraints prevents acceptance of an older quote. A booking retains the exact agreed pet/service/location/price/time facts, including Address Line 2 and timezone. Profile edits never silently rewrite that agreement.
2. **One availability definition, different certainty:** matching finds candidate intervals using declared estimates; an assessment-required candidate is labeled uncertain. A quote specifies actual proposed duration. Acceptance revalidates the concrete interval, current eligibility, versions, notice rules, pet/groomer conflicts, and daily capacity under concurrency control.
3. **Terms validity is not selectability:** a time collision can make an otherwise valid quote temporarily unselectable. If it clears before the deadline and the same terms/consent remain valid, selectability may recover. Withdrawal, expiry, superseded terms, or explicit revoked eligibility do not automatically revive.
4. **Retry is not another booking:** the same owned acceptance produces one receipt and one set of lifecycle events. A lost response yields an unresolved operation that can be reconciled across restart, not a fabricated failure or new request. Replaying the original receipt must also expose the booking's current state if it has since changed.
5. **Release follows reality:** pre-start cancellation, in-service interruption, completion, and no-show are different actions. Occupancy is not blindly erased because a status changed; the approved actual-time/buffer rule controls release. Overrun must not silently move another confirmed booking.
6. **Reschedule excludes its own old allocation:** recheck the proposed interval without treating the existing booking as a competing booking or double-counting same-day quota. Revalidate both local dates when moving days. An expired/rejected proposal preserves the old arrangement; cancellation/completion can invalidate a pending proposal.
7. **Read is not acknowledged:** do not delete a business acknowledgement merely because notification read state exists. If acknowledgement remains necessary, retain one authoritative record and treat local state as a retryable cache, not another source of truth.
8. **Unknown history stays unknown:** a current profile address is not proof of an old booking address. Missing legacy pet identity, size settings, or service duration needs explicit classification and a safe transition, not an invented backfill or blanket account shutdown.
9. **Lists are not global truth:** each query declares its scope, completeness, and freshness. An unloaded day is not free; an unloaded object is not missing. Scheduling and mutation decisions never depend on the first UI page.
10. **Business success survives enrichment failure:** booking facts and required lifecycle events commit consistently. Image loading, refreshed presentation, and notification delivery can retry without reversing that result. Logout invalidates account-owned work and reminders.

## Logical Interfaces

These are proposed logical payloads, not deployed API names or permission to create endpoints. Each package must bind them to the existing repository boundaries and publish its final typed/wire contract before a dependent package consumes it.

| Contract | Inputs | Required output/behavior | Producer |
|---|---|---|---|
| Availability revision | Owned windows/preferences, expected revision | Entire accepted revision or no change; conflicting confirmed bookings remain visible | WP-01 |
| Operation outcome | Authenticated owner, operation identity, immutable intent | Confirmed receipt, explicit rejection with recovery action, or awaiting reconciliation; no duplicate side effects | WP-02 |
| Service timing | Window, timezone, declared duration/confidence, direction, approved buffers | Separate service and occupied intervals; boundary/assessment result | WP-03 |
| Match evaluation | Request revision, groomer/service facts, schedule revision, evaluation time | Eligible candidate intervals or assessment/exclusion reasons; explanation derived from the same evaluation | WP-04 |
| Quote evaluation | Request/quote revisions, fixed terms, deadline, current schedule | Terms-validity reason separately from current selectability; revalidation required at acceptance | WP-05 |
| Booking agreement | Accepted quote revision and stable pet identity | Versioned complete terms and provenance, never silently following mutable profiles | WP-05 |
| Fulfillment mutation | Actor, expected booking revision, allowed action, actual-time evidence | Authorized current outcome, occupancy/release result, and next action; replay safe | WP-06 |
| Change proposal | Booking base revision, proposed terms, initiator, deadline | One live proposal; accept/reject/expire result; old agreement preserved until atomic acceptance | WP-07 |
| Scoped read | Participant identity, date range or exact object ID, continuation | Scope/as-of/completeness plus items or explicit unavailable/unauthorized result | WP-08/WP-09 |
| Reminder snapshot | Account, horizon, complete eligible bookings and explicit changes | Reconcile only the authoritative covered scope; no removal inferred from a partial page | WP-11 |

## Ownership Map

Paths below are existing entry points, not a requirement to edit every listed file. New Swift helpers stay with their domain; new migrations and rollback validation artifacts are created only in the adopted backend task. Keep published migrations as read-only evidence.

| Area | Existing source ownership | Existing test ownership |
|---|---|---|
| Availability/services | [GroomerProfileStore+ServicesAvailability.swift](../../../ios/Beckon/Beckon/Features/Groomer/Profile/GroomerProfileStore+ServicesAvailability.swift), [SupabaseGroomerProfileRepository.swift](../../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift), [GroomerProfile.swift](../../../ios/Beckon/Beckon/Core/Models/GroomerProfile.swift) | [GroomerProfileFeatureTests+Operations.swift](../../../ios/Beckon/BeckonTests/GroomerProfileFeatureTests+Operations.swift), [GroomerProfileFeatureTests+FitSignals.swift](../../../ios/Beckon/BeckonTests/GroomerProfileFeatureTests+FitSignals.swift) |
| Customer request/acceptance | [CustomerRequestsStore.swift](../../../ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsStore.swift), [CustomerRequestWizardView.swift](../../../ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestWizardView.swift), [SupabaseCustomerRequestRepository.swift](../../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseCustomerRequestRepository.swift), [CustomerRequest.swift](../../../ios/Beckon/Beckon/Core/Models/CustomerRequest.swift) | [CustomerRequestFeatureTests+Offers.swift](../../../ios/Beckon/BeckonTests/CustomerRequestFeatureTests+Offers.swift), [CustomerRequestFeatureTests+WizardPresentation.swift](../../../ios/Beckon/BeckonTests/CustomerRequestFeatureTests+WizardPresentation.swift), [CustomerRequestFeatureTests+Republish.swift](../../../ios/Beckon/BeckonTests/CustomerRequestFeatureTests+Republish.swift) |
| Groomer matching/offers | [GroomerRequestsStore.swift](../../../ios/Beckon/Beckon/Features/Groomer/Requests/GroomerRequestsStore.swift), [GroomerRequestsView.swift](../../../ios/Beckon/Beckon/Features/Groomer/Requests/GroomerRequestsView.swift), [SupabaseGroomerRequestRepository.swift](../../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseGroomerRequestRepository.swift), [GroomerRequest.swift](../../../ios/Beckon/Beckon/Core/Models/GroomerRequest.swift) | [GroomerRequestFeatureTests.swift](../../../ios/Beckon/BeckonTests/GroomerRequestFeatureTests.swift), [GroomerOffersFeatureTests.swift](../../../ios/Beckon/BeckonTests/GroomerOffersFeatureTests.swift), [backfill-matching.test.mjs](../../../tests/migrations/backfill-matching.test.mjs), [time-boundary-contract.test.mjs](../../../tests/migrations/time-boundary-contract.test.mjs) |
| Booking lifecycle/schedule | [BookingRepository.swift](../../../ios/Beckon/Beckon/Core/Repositories/BookingRepository.swift), [SupabaseBookingRepository.swift](../../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift), [Booking.swift](../../../ios/Beckon/Beckon/Core/Models/Booking.swift), [BookingsStore.swift](../../../ios/Beckon/Beckon/Features/Bookings/BookingsStore.swift), [BookingsView.swift](../../../ios/Beckon/Beckon/Features/Bookings/BookingsView.swift), [GroomerSchedulePresentation.swift](../../../ios/Beckon/Beckon/Features/Bookings/GroomerSchedulePresentation.swift) | [BookingFeatureTests.swift](../../../ios/Beckon/BeckonTests/BookingFeatureTests.swift), [ListPaginationFeatureTests.swift](../../../ios/Beckon/BeckonTests/ListPaginationFeatureTests.swift), [GroomerHomeFeatureTests.swift](../../../ios/Beckon/BeckonTests/GroomerHomeFeatureTests.swift) |
| Chat | [SupabaseChatRepository.swift](../../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseChatRepository.swift), [ChatView.swift](../../../ios/Beckon/Beckon/Features/Chat/ChatView.swift) | [ChatFeatureTests.swift](../../../ios/Beckon/BeckonTests/ChatFeatureTests.swift), [participant-chat-booking-events.test.mjs](../../../tests/migrations/participant-chat-booking-events.test.mjs) |
| Notifications/reminders | [CustomerNotificationsView.swift](../../../ios/Beckon/Beckon/Features/Customer/Notifications/CustomerNotificationsView.swift), [BeckonSystemNotifications.swift](../../../ios/Beckon/Beckon/DesignSystem/BeckonSystemNotifications.swift), [AppointmentReminderScheduler.swift](../../../ios/Beckon/Beckon/Core/Services/AppointmentReminderScheduler.swift) | [CustomerNotificationsFeatureTests.swift](../../../ios/Beckon/BeckonTests/CustomerNotificationsFeatureTests.swift), [SystemNotificationsPresentationTests.swift](../../../ios/Beckon/BeckonTests/SystemNotificationsPresentationTests.swift), [booking-handoff-read-state.test.mjs](../../../tests/migrations/booking-handoff-read-state.test.mjs) |
| Auth/account boundaries | [AuthenticationStore.swift](../../../ios/Beckon/Beckon/Features/Auth/AuthenticationStore.swift), [AuthenticationView.swift](../../../ios/Beckon/Beckon/Features/Auth/AuthenticationView.swift), [AuthSessionRepository.swift](../../../ios/Beckon/Beckon/Core/Repositories/AuthSessionRepository.swift), [SupabaseAuthSessionRepository.swift](../../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseAuthSessionRepository.swift), [AuthCallbackConfiguration.swift](../../../ios/Beckon/Beckon/Core/Models/AuthCallbackConfiguration.swift) | [AppEntryModelsTests.swift](../../../ios/Beckon/BeckonTests/AppEntryModelsTests.swift), [CustomerPushNotificationFeatureTests.swift](../../../ios/Beckon/BeckonTests/CustomerPushNotificationFeatureTests.swift) |
| Optional loading | [GroomerProfileStore.swift](../../../ios/Beckon/Beckon/Features/Groomer/Profile/GroomerProfileStore.swift), Customer Requests and the repositories above | [GroomerProfileFeatureTests.swift](../../../ios/Beckon/BeckonTests/GroomerProfileFeatureTests.swift), [CustomerRequestFeatureTests.swift](../../../ios/Beckon/BeckonTests/CustomerRequestFeatureTests.swift), [PrivateImageLoaderTests.swift](../../../ios/Beckon/BeckonTests/PrivateImageLoaderTests.swift) |

## Package Sequence

WP-00 established D-038 and scoped evidence under T-369; final gate disposition is recorded in T-385. WP-01 through WP-13 are accepted under T-371/T-373 through T-384; WP-14 local integration is accepted under T-385. User clarification on 2026-09-10: complete the application on this Mac using independent iOS Simulators. Physical devices, developer-program membership, signing, provisioning, TestFlight, App Store submission and distribution are outside this task, not prerequisites or deferred completion gates. This supersedes earlier package notes that treated them as requirements. Functional, concurrency, recovery, authorization and data-integrity standards were preserved.

| Package | Independently reviewable result | Dependencies | Mode |
|---|---|---|---|
| WP-00 | Approved policies, evidence baseline, and executable package boundaries | None | Quick; read-only backend evidence separately scoped |
| WP-01 | Failure-safe availability save | WP-00 | Deep |
| WP-02 | Same-pet conflict protection and recoverable acceptance | WP-00 | Deep |
| WP-03 | Shared time/occupancy semantics and useful offer defaults | WP-01 | Deep |
| WP-04 | Feasible, explainable, maintainable matching | WP-03 | Deep |
| WP-05 | Versioned agreements and truthful quote validity | WP-02, WP-03, WP-04 | Deep |
| WP-06 | Controlled completion, cancellation, and interruption | WP-02, WP-03, WP-05 | Deep |
| WP-07 | Safe two-party rescheduling | WP-06 | Deep |
| WP-08 | Correct scoped booking/request reads | WP-00 | Deep if new controlled read is needed |
| WP-09 | Bounded chat summaries and exact conversation lookup | WP-00 | Deep |
| WP-10 | Actionable notifications and deliberate acknowledgement semantics | WP-08, WP-09 | Standard; Deep if acknowledgement contract changes |
| WP-11 | Account-scoped reminder reconciliation | WP-06, WP-07, WP-08 | Standard; Deep if new snapshot read is needed |
| WP-12 | Complete password recovery | WP-00 | Deep |
| WP-13 | Core-first loading without stale-state regressions | WP-03, WP-05, WP-08, WP-09 | Standard |
| WP-14 | Compatibility, integrated evidence, and release acceptance | WP-01 through WP-13 | Deep |

Recommended review order: decide contracts, address save/acceptance safety, unify timing, then matching/agreements/lifecycle. Query, chat, and password-recovery packages can be separately adopted without waiting for the entire booking redesign. Do not hold an independent correctness fix hostage to an unrelated optional simplification.

## Work Packages

Each implementation package follows a separate test/change/review cycle. Its acceptance cases are required scenarios, not claims that the existing tests already execute them. Choose exact test identifiers and wire signatures in that package's approved executable checklist; do not treat SQL-text assertions as concurrency tests.

### WP-00 - Approve Policies And Evidence Boundaries

**Coverage:** L-01 through L-04, all review corrections, and remaining matching verification. **Files:** product flow/data contracts and Decision Log only when decisions are actually approved; this plan and the findings register for traceability. **Produces:** signed gate choices and a per-package input/output contract.

- [x] Review G-01 through G-10; choices adopted under the user's explicit delegated judgment, including timing bounds and participant-owned exception facts without promised arbitration.
- [x] Preserve the eight self-review corrections and classify existing unknown inputs; T-385 final matrix records their evidence and owners.
- [x] Confirm task-relevant installed backend definitions under scoped authorization before dependent implementation; preserve credential and write boundaries.
- [x] Publish the first adopted package checklist and subsequent exact domain contracts; execute the original packages under the user's later continuous-plan authorization.

**Acceptance:** every adopted package has no unresolved gate affecting its behavior. A proposal is not recorded as a decision merely because it appears in this plan. **Stop boundary:** no implementation, rollout, or remote mutation in WP-00.

**T-369 checkpoint:** The user approved WP-01's Save boundary on 2026-09-07 (D-038): working windows, time off, and booking preferences form one atomic save; failure retains prior saved data; existing confirmed appointments stay intact; profile details/photos save independently. Targeted linked catalog verification has now succeeded; see the scoped T-369 evidence in [Supabase Contract](../../03_backend/SUPABASE_CONTRACT.md). No whole-document freshness, authorization execution, or concurrency claim follows from that inspection. WP-00 remains open for exact contracts; other G-01 through G-10 choices are still pending.

**Historical WP-01 preparation from local source, superseded by T-371 acceptance below:**

- The Store's `saveAvailability()` currently validates/writes a profile, then replaces weekly windows, then saves preferences. Remove profile validation/writes from this action; preserve its independent editing draft.
- `createTimeOff()` and `deleteTimeOff()` currently persist immediately. Stage those changes in the availability draft instead; cancellation/reload must not accidentally commit them. Include time off in whole-save rollback coverage.
- `SupabaseGroomerProfileRepository.replaceAvailability()` currently issues separate DELETE and INSERT calls. A client-side restore attempt is not the atomicity fix; the approved data must commit in one controlled backend transaction.
- Extend existing Operations tests with failed-save draft retention, unchanged prior data, no profile-write side effect, and staged time-off behavior. Add authorized database failure/concurrency tests before claiming transaction safety.
- Targeted backend definitions are verified. Finalize the snapshot/revision and mutation signatures, all-writer concurrency/compatibility rules, and exact test commands. The deployed tables lack an aggregate revision; authenticated direct writes remain possible. Acceptance takes request-related locks before its groomer advisory lock, so define consistent lock ordering and test save-versus-acceptance rather than simply adding a Save-only lock.
- Row-level Save changes trigger insert-only missing-match backfill repeatedly. Ensure final-state matching effects and bounded work within the approved Save transaction; do not mistake this trigger for reconciliation of existing matches. Do not invent a deployed RPC or mark this preparation as a completed executable checklist.

### WP-01 - Make Availability Saves Atomic

**Accepted under T-371:** rollback/access, concurrent same-version HTTP Save, save/acceptance race and both orderings, draft recovery and actual Save UI passed. Independent server reads and exact fixture restoration were verified. See [standalone acceptance evidence](../../06_tasks/sql_reviews/T-371_AVAILABILITY_ACCEPTANCE.md). Distribution of compatible builds remains WP-14, not a claim that all installed clients have updated.

**T-371 implementation:** D-040 chooses `get_groomer_availability()` and `save_groomer_availability(p_expected_revision, p_windows, p_preferences, p_time_off)`, returning an owned snapshot with an opaque fingerprint. The migration is now deployed under the user's necessary-operation authorization. It shares acceptance's advisory lock, batches final-state backfill and revokes legacy partial writes. No booking/profile/photo writes occur. Swift stages time off and supports conflict recovery, independent profile forms, reload and discard. Old clients need the compatible build; unsafe partial writes are not retained.

**Evidence:** 457 Swift cases, six separately authorized seeded UI cases, 85 migration/10 function tests, final build, live SQL rollback/access tests, concurrent HTTP cases, 72 aligned migrations and empty push dry run. Advisors retain Q-93 only. F-01 is resolved for the current implementation; other findings and package requirements remain open.

**Coverage:** F-01. **Files:** Availability/services ownership. **Consumes:** approved Save boundary and expected revision. **Produces:** one authoritative saved schedule revision, used by WP-03.

- [x] Add a failure-injection regression proving an insert/preference failure currently can follow deletion; assert preservation of the entire previous schedule for the corrected behavior.
- [x] Move the approved availability-owned changes into one controlled transaction; include revision conflict handling and preserve confirmed appointments when a new schedule conflicts with them. Keep unrelated profile/photo operations outside this Save.
- [x] Update repository/Store behavior so failure retains the editable draft and authoritative prior data; success applies the full returned result once.
- [x] Verify rollback after each write boundary, simultaneous saves, save versus acceptance, authorization, and invalid-window rejection; run the package's focused tests and completion gates before Git closeout.

**Acceptance example:** saving a new Tuesday window fails during its second write; all old windows/preferences remain, and the UI reports failure without claiming a saved revision. **Rollback:** retain the last confirmed revision; no delete-and-reinsert fallback. New remote SQL requires separate authorization.

### WP-02 - Protect Pet Capacity And Recover Acceptance Outcomes

**T-373 accepted:** Non-null owned pet identity, native exclusion, admission guard, original receipt/current state, read-only reconciliation and request-first offer writers are deployed. Final eight independent-session races passed with exact restoration; rollback/access/direct-writer/terminal-state checks passed. Independent process recovery, refresh-after-signout RED/GREEN, full 463-case Swift regression, preflight and build passed. See [scoped evidence and limits](../../06_tasks/sql_reviews/T-373_ACCEPTANCE_EVIDENCE.md); physical multi-device network interruption and release qualification are not claimed.

**Coverage:** F-11, F-12. **Files:** Booking lifecycle and Customer request/acceptance ownership; a new migration and its transaction/authorization tests. **Consumes:** stable pet identity and the current admission rules. **Produces:** conflict-safe acceptance and the operation-outcome contract.

- [x] Write regressions for the same pet on different requests/groomers and for a committed acceptance whose response is lost. Reproduce concurrency with separate database sessions in an explicitly authorized environment, not only Store mocks.
- [x] Enforce groomer and pet occupancy plus daily capacity for every acceptance writer. Audit legacy/null pet references first; do not silently skip conflict protection or use a shared dummy identity.
- [x] Replay an already accepted owned offer without duplicating bookings, conversations, or lifecycle messages; preserve rejection of another customer's offer or a competing offer. Return the original receipt alongside current booking state.
- [x] Keep unresolved submission identity across reload/restart, reconcile before retry, and keep it account-scoped. Confirm cancellation or completion occurring before a retry is shown as current state rather than resurrecting confirmation.
- [x] Run duplicate-tap, cross-device-equivalent independent-session, competing-offer, different-pet, cancelled-capacity, logout, and layered dropped-response cases before the package closeout gates. Physical-device network interruption remains part of release qualification.

**Acceptance example:** two customers' operations cannot produce overlapping bookings for the same groomer, and two requests for one pet cannot produce overlapping bookings with different groomers; retrying a winning operation returns its existing booking. **Rollback:** never drop the new safety guard while an older writer remains able to bypass it.

### WP-03 - Separate Windows, Duration, And Occupancy

**T-374 accepted (2026-09-08):** Original WP-03 requirements below are verified by lasting Swift/SQL vectors, deployed migration `20260908052312`, actual HTTP publication/replay -> automatic match -> offer/booking allocation and receipt replay, both verified admission/Save lock orderings and exact restoration. Real Wizard confirmation/publication and quote occurrence/device-environment submissions pass. Full regression/build and final preflight pass; 359/1,439-minute regressions pass. See [backend evidence](../../06_tasks/sql_reviews/T-374_TIMING_BACKEND_ACCEPTANCE.md) and [UI evidence/limits](../../06_tasks/sql_reviews/T-374_TIMING_UI_ACCEPTANCE.md). WP-04 matching and WP-06 fulfillment are not claimed.

**Coverage:** F-05, C-03, L-01, L-03; timing foundation for F-14/F-15. **Files:** Customer Wizard/Store/models, Groomer offer form/Store, Availability/services ownership, exact-availability helpers and tests. **Consumes:** G-01/G-02/G-05 and WP-01. **Produces:** the shared service-timing contract.

**Release qualification:** A supplemental system-keyboard-visible screenshot was not established. Retain it for WP-14 alongside physical-device interruption/distribution; do not call it passing. This does not waive the original timing, changed-flow or integration requirements.

- [x] Convert the preceding isolated probe into lasting boundary tests: a 10:00 local Today-morning selection retains valid remaining time; broad morning/flexible preferences never become 359/1,439-minute default services.
- [x] Define service and groomer-occupied intervals using the approved timezone, duration confidence, buffers, local-day capacity, and notice rules. Reject a window only when no valid remaining service interval exists.
- [x] Use current service price/duration as editable defaults; changing duration recalculates eligibility, not the customer's accepted constraints. Unknown custom-service duration stays assessment-required.
- [x] Align request validation, proposed-time selection, and exact backend checks. Validate same-day clipping, overnight boundaries, DST repeated/missing times, device-timezone changes, adjacent buffered appointments, and out-of-window alternatives.
- [x] Run focused Swift/SQL tests and inspect the changed Wizard/offer flow in Simulator under the normal completion gates; no dependency or route optimizer is included.

**Acceptance example:** within 09:00-12:00, a 60-minute service can use a valid 10:00-11:00 interval if its resource buffers also fit; the whole three-hour preference does not have to be free. **Rollback:** preserve request intent and server conflict checks; do not silently reinterpret existing accepted appointments.

### WP-04 - Make Matching Feasible And Explainable

**T-375 accepted (2026-09-08):** Applied 20260908185059 integrates interval/size evaluation, unchanged ranking, authenticated publication/replay, append-only refresh events, pending-aware owned reads and writer guards. SQL boundary/authorization/quality probes, both real admission/Save contention orderings with exact fixture restoration, actual scheduled refresh, full regression/build/preflight and changed-flow rendering pass. All 75 histories align; dry run empty. See [acceptance and scoped performance limits](../../06_tasks/sql_reviews/T-375_MATCHING_ACCEPTANCE.md). WP-05 and release qualification remain separate.

**Coverage:** F-04, F-14, F-15; matching verification gaps. **Files:** Groomer matching/offers and service configuration ownership; current matching/day-capacity definitions referenced by the findings, modified only through new migrations. **Consumes:** WP-03, G-05/G-10. **Produces:** candidate intervals, assessment/exclusion reasons, and invalidation scope.

- [x] Add cases for a fully occupied day below its appointment limit, fragmented gaps, a short service inside a broad preference, an explicitly excluded size, and a legacy unknown size/duration.
- [x] Separate explicit eligibility from experience ranking; return estimated feasible intervals or an honestly labeled assessment candidate. Unknown identity/authorization/location cannot be excused as merely assessment-required.
- [x] Generate time-fit explanations from the same interval evaluation. Rank only permitted candidates; test tie behavior and new-groomer exposure on the approved representative dataset without presenting scores as success probabilities.
- [x] Refresh/re-evaluate only affected active requests/matches when services, address, availability, time off, or bookings change. Preserve deliberate dismissals; revalidate at offer creation and acceptance even if a cached match exists.
- [x] Implement truthful zero-match/assessment recovery with explicit customer permission for changing constraints. Measure feasibility, query/fan-out cost, and exposure against G-10; run the exact-boundary and authorization cases as well as matching tests.

**Acceptance example:** a groomer with no continuous 60-minute opening is not labeled as able to fit a known 60-minute service simply because only one daily appointment exists. A valid opening inside the requested window gets the in-window explanation. **Rollback:** correctness fixes must not require rolling back unrelated ranking changes; keep those changes separately reviewable.

### WP-05 - Version Agreements And Separate Quote Validity From Availability

**Coverage:** F-03, F-13; review corrections for request revisions and temporary quote unavailability. **Files:** Customer Request and Groomer Offer models/repositories/Stores, Booking hydration and acceptance, expiry helpers and relevant tests. **Consumes:** WP-02/WP-03/WP-04, G-03/G-04. **Produces:** quote evaluation and versioned booking agreements.

- [x] Add regressions for request edits between quote and acceptance, profile-address edits after quote/booking, unit-address hydration, and a slot collision that later clears before the quote deadline.
- [x] Bind quote terms to the request revision and the exact displayed service/pet/location/time/price facts. Define an explicit supersession path for open-request changes; do not permit stale acceptance during it.
- [x] Persist the accepted terms with provenance, including Address Line 2 and service timezone. For legacy bookings, backfill only facts supported by evidence; otherwise surface missing/unverified details for participant confirmation without fabricating history.
- [x] Compute terms validity independently from current selectability. Enforce deadlines on reads and mutations rather than trusting cron timing; allow only transient-capacity recovery to restore selectability, not withdrawn/expired/superseded consent.
- [x] Test changes in both service directions, complete snapshots on all booking/chat surfaces, request/quote edits racing acceptance, stopped expiry processing, and slot recovery. Keep lost-response behavior from WP-02 intact.

Acceptance: [T-376 evidence](../../06_tasks/sql_reviews/T-376_AGREEMENT_ACCEPTANCE.md). WP-06/WP-07 own fulfillment and subsequent bilateral changes; WP-14 owns physical-device/distribution qualification.

**Acceptance example:** customer reviews quote revision 3, then changes the request's service; accepting revision 3 fails with a current replacement/recovery path and creates no booking. A mere temporary slot collision does not destroy otherwise valid unchanged terms. **Rollback:** do not revert to mutable profile-derived agreement details or accept an unversioned unsafe old-client mutation.

### WP-06 - Control Actual Fulfillment And Resource Release

**Coverage:** F-02, L-04 and the cancellation/early-completion/support review corrections. **Files:** Booking models/repository/Store/views, completion/cancellation operations, reminder event inputs, and Booking tests. **Consumes:** WP-02/WP-03/WP-05, G-06/G-09. **Produces:** authorized fulfillment outcomes and resource-release semantics.

- [x] Add cases for a future booking, allowed actual start/end, elapsed-unresolved booking, pre-start cancellation, in-service interruption, no-show report, and competing terminal actions.
- [x] Separate planned time from actual fulfillment evidence; prevent starting/completing a future appointment outside the approved start rule. Support approved early completion without allowing a click on Start to bypass that rule; retain required buffers.
- [x] Apply the approved cancellation/interruption/no-show transition matrix with actor, reason, actual-time, and version checks. Do not free an in-progress resource immediately from a unilateral cancellation click or silently extend over a following booking.
- [x] Keep elapsed unresolved bookings actionable. Keep ending unfulfilled service separate from assigning fault; do not enable completed-service reviews or penalties based only on an allegation. Provide the approved customer recovery/support path without inventing staffing.
- [x] Validate repeat actions, correction rules, completion versus cancellation, reminders, daily counts, and eligibility for exactly one review. Inspect both roles' changed lifecycle controls and complete the required regression gates.

**Acceptance example:** a customer reports interruption during service; the system records the report and follows the approved stop/release process instead of advertising the groomer as instantly free. A future booking cannot become completed. **Rollback:** preserve actual evidence and terminal outcomes; no destructive reset to confirmed.

Acceptance: [T-377 fulfillment evidence](../../06_tasks/sql_reviews/T-377_FULFILLMENT_ACCEPTANCE.md). Later package and release obligations remain unchanged.

### WP-07 - Add Safe Two-Party Rescheduling

**Coverage:** L-02 and the rescheduling self-review correction. **Files:** Booking ownership, Customer/Groomer booking actions, related notification/chat event handling and tests. **Consumes:** WP-06 and its prerequisites, G-07. **Produces:** the change-proposal contract.

- [x] Write cases for overlapping old/new intervals of the same booking, a date change at daily capacity, expiry at the original service boundary, cancellation racing acceptance, and another booking taking the proposed slot.
- [x] Add one live proposal per booking using the base revision, initiator consent, other-participant acceptance, and approved deadline. Restrict changed fields to G-07's approved scope; participant/pet/service replacement is not silently treated as a reschedule.
- [x] On acceptance, exclude the booking's own old allocation, revalidate both dates/resources, and atomically replace terms and occupancy. Preserve the old booking on conflict, rejection, or proposal expiry; return its current state.
- [x] Make proposal/accept/reject operations replay safe. Invalidate proposals when their base booking is cancelled, completed, superseded, or outside the allowed change window; do not let an unresolved proposal excuse the original appointment.
- [x] Verify both roles' consent presentation, one resulting calendar agreement, correct chat events, and the reminder change input consumed by WP-11.

Acceptance: [T-378 evidence](../../06_tasks/sql_reviews/T-378_RESCHEDULING_ACCEPTANCE.md). Global reminder reconciliation remains WP-11; complete reads and asynchronous enrichment remain WP-08/WP-13.

**Acceptance example:** moving one booking from 10:00-11:00 to 10:30-11:30 does not conflict with itself, but still fails if it conflicts with another appointment; failure preserves 10:00-11:00. **Rollback:** stop new proposals and retain old confirmed agreements; never abandon both slots mid-change.

### WP-08 - Replace Partial-List Business Lookups

**Coverage:** F-06 booking/Home/republish surfaces. **Files:** Booking repository/Store/schedule, Customer Request repository/Store, [GroomerHomeStore.swift](../../../ios/Beckon/Beckon/Features/Groomer/Home/GroomerHomeStore.swift), related pagination/Home/republish tests. **Consumes:** WP-00 and existing participant access. **Produces:** complete date-scoped and exact-object reads.

- [x] Add 51+ future-booking fixtures with the nearest appointment outside page one and a cancelled booking whose source request is not loaded.
- [x] Query nearest eligible appointment, requested date range, and exact request/booking IDs directly. Define explicit completion/freshness for each requested scope rather than loading all historical records.
- [x] Render loading, stale/incomplete, error, and confirmed-empty states distinctly. Keep cancelled-booking republish tied to authoritative original data without reopening old offers or accepting an unconfirmed new address.
- [x] Validate pagination ties, day changes, missing/unauthorized objects, and request lookup failures; complete focused tests and changed-surface runtime gates.

Acceptance: [T-379 evidence](../../06_tasks/sql_reviews/T-379_SCOPED_READ_ACCEPTANCE.md). Final full regression/build/preflight passed; existing RLS and 79-version backend baseline unchanged.

**Acceptance example:** a selected day containing a booking outside the general list's first page never appears free solely because that page omitted it. **Rollback:** retain a visible incomplete/loading state; never substitute a partial list for a complete date answer.

### WP-09 - Bound Chat Summary Reads And Resolve Exact Conversations

**Coverage:** F-10 and F-06 booking-to-chat navigation. **Files:** Chat ownership, participant conversation access, exact Booking lookup and tests. **Consumes:** WP-00 and current participant-pair conversation identity. **Produces:** one summary per authorized conversation and exact navigation lookup.

- [x] Add a busy conversation exceeding the configured response cap alongside quiet conversations, plus a booking's conversation outside the loaded list.
- [x] Return one latest-message summary per conversation with deterministic tie ordering; load thread history separately. Preserve booking-card rendering and existing read semantics rather than silently adding deferred cross-device read receipts.
- [x] Resolve booking-to-conversation navigation through participant-pair/exact-object lookup, not the first conversation page. Preserve counterpart-avatar access and fail closed for nonparticipants.
- [x] Verify all quiet conversations retain correct previews/unread evidence and that query/payload cost scales with page size rather than total message history.

Acceptance: [T-380 evidence](../../06_tasks/sql_reviews/T-380_CHAT_SUMMARY_ACCEPTANCE.md). Installed 1500-message/1000-cap vectors, indexed cost, exact routing, final serial integration/build/preflight passed; 80 histories aligned.

**Acceptance example:** thousands of messages in conversation A cannot erase conversation B's newest preview; a valid later-page conversation opens directly. **Rollback:** never fall back to an unbounded history fetch or bypass participant access.

### WP-10 - Route Notifications And Resolve Acknowledgement Semantics

**Coverage:** F-08, C-02. **Files:** Customer/Groomer notification features/repositories, shared notification presentation, Customer Request handoff state, notification/handoff tests. **Consumes:** WP-08/WP-09, G-08. **Produces:** safe destination routing and one intentional read/acknowledgement model.

- [x] Add routing cases for each existing notification kind, an unloaded target, a stale/deleted target, and a target changed between notification delivery and tap.
- [x] Route by authoritative IDs, then follow the approved read-marking rule. Reading a notification cannot mark fulfillment complete or silently acknowledge a separate business action.
- [x] Apply G-08's chosen branch: remove a purely presentational acknowledgement with compatible cleanup, or retain one server-owned acknowledgement and reconcile retryable local cache. A failed remote acknowledgement must not become permanently unrepeatable due to a local guard.
- [x] Verify two independent Simulators, logout/account switch, read versus acknowledgement independence, accessible action identifiers and notification authorization boundaries; T-385 also fixes the omitted disappearance bulk-read path.

**Acceptance example:** tapping New Offer opens its current request/offer even if unloaded; opening a notification does not imply independent appointment acknowledgement when that business concept is retained. **Rollback:** retain independent business acknowledgement until its removal is explicitly approved; no speculative data deletion.

### WP-11 - Reconcile Account-Owned Reminders

WP-10 implementation/deployment evidence: [T-381](../../06_tasks/sql_reviews/T-381_NOTIFICATION_ACCEPTANCE.md). Two-client/server-session checks pass; original two-device qualification remains mandatory in WP-14 and is not claimed from mocks.

**Coverage:** F-09. **Files:** AppointmentReminderScheduler, Booking/Customer Request synchronization, AuthenticationStore account exit, reminder-related tests. **Consumes:** WP-06/WP-07/WP-08, a complete reminder snapshot. **Produces:** bounded account/horizon reconciliation.

- [x] Add cases for other-party cancellation, reschedule, completion, partial pages, disabled notification permission, and an in-flight fetch returning after logout.
- [x] Reconcile additions, time changes, and removals only within a declared authoritative horizon or from explicit changed/deleted booking results. Do not infer cancellation from absence in an incomplete snapshot.
- [x] Clear account-owned scheduled/delivered reminders on exit and prevent old-session work from rescheduling them. Use stable booking identity/version handling across time and timezone changes.
- [x] Test reconnect/foreground reconciliation and reminder taps resolving current state. Explicitly state the offline limit: a remotely cancelled booking cannot be guaranteed to disappear immediately from an offline device's previously scheduled local alerts.

Acceptance: [T-382 evidence](../../06_tasks/sql_reviews/T-382_REMINDER_ACCEPTANCE.md). Physical-device release qualification remains WP-14.

**Acceptance example:** refreshing after the other party cancels removes the old reminder; loading an unrelated partial booking page does not remove a valid future reminder. **Rollback:** disable unsafe scheduling and clear owned obsolete alerts, not unrelated account/app notifications. APNs deployment is excluded.

### WP-12 - Complete Password Recovery

**Coverage:** F-07. **Files:** Auth/account ownership and focused auth callback/Store tests. **Consumes:** existing auth/role boundaries. **Produces:** a recoverable reset-email/callback/new-password flow.

- [x] Add auth-state tests for recovery request, valid callback, expired/used link, network interruption, and callback arrival while another account is active.
- [x] Extend the existing repository/Store boundary for recovery; verify supported Supabase SDK behavior and allowed callbacks in the adopted task before implementing. Do not change roles or invent a signed-in session.
- [x] Provide resend/retry and return routing, consistent responses that do not reveal account existence, and safe handling of partial recovery sessions. Preserve account-scoped data isolation.
- [x] Validate controlled email/callback delivery with explicitly authorized accounts/configuration where required; local mocks alone do not close the end-to-end recovery finding.

Acceptance: [T-383 evidence](../../06_tasks/sql_reviews/T-383_PASSWORD_RECOVERY_ACCEPTANCE.md). Real delivered email/SDK recovery and scoped account cleanup passed; physical-device handoff remains WP-14.

**Acceptance example:** an expired reset link leads to a usable new-reset path without exposing another account's data or leaving the app in a fabricated authenticated state. **Rollback:** retain the established login path and block invalid recovery transitions; do not alter unrelated provider settings.

### WP-13 - Load Core Facts Before Optional Enrichment

**Coverage:** C-01; preserve C-03 integration. **Files:** Optional loading ownership and affected Stores/repositories, focused load/cancellation tests. **Consumes:** stable contracts from WP-03/WP-05/WP-08/WP-09 and G-10. **Produces:** responsive, failure-isolated loading without new state authorities.

- [x] Measure current time-to-core-content, request count, and payloads on a fixed dataset; add delayed/failed image/evidence cases and a refresh arriving during a dirty form edit.
- [x] Render authoritative core results first and load optional photos/evidence with bounded concurrency or on demand. Missing critical identity/state/address data must disable dependent actions, not be silently fabricated.
- [x] Protect user edits, account boundaries, and mutation revisions against stale asynchronous results. Split a Store only at a demonstrated ownership boundary; do not introduce a generic framework to shorten files.
- [x] Verify optional failures do not block core use and no stale load overwrites a newer booking/profile mutation; compare measurements against the approved baseline and run the required shared-behavior regression gates.

Acceptance: [T-384 evidence](../../06_tasks/sql_reviews/T-384_CORE_LOADING_ACCEPTANCE.md). Fixed repository counts/image payloads are unchanged; production-network and physical-device claims remain WP-14.

**Acceptance example:** failed portfolio/evidence loading leaves a correctly loaded profile usable, while a missing authoritative booking address is visibly unresolved and cannot be substituted with an invented agreement. **Rollback:** preserve correctness and dirty form data even if an optimization is disabled.

### WP-14 - Verify Compatibility And The Complete Lifecycle

Final acceptance: [T-385](../../06_tasks/sql_reviews/T-385_RELEASE_CHECKPOINT.md). Installed compatibility/legacy/cost/security, two independent Simulator roles, keyboard, callback, interruption/reconnect, full regression and local build checks pass. The existing user-directed governance cadence exception remains explicit. No physical-device, signing or store-distribution prerequisite applies.

**Carried release check:** Verify the changed quote form with the system keyboard visibly open; T-374's window-only images and successful submissions do not prove this state.

**Coverage:** all findings, adopted policies, and outstanding matching verification. **Files:** existing iOS tests, migration/function tests, authorized SQL/TestOps evidence and applicable product/backend docs; no unrelated cleanup. **Consumes:** WP-01 through WP-13. **Produces:** evidence-backed local functional acceptance, not a store-release decision.

- [x] Review migration ordering, old writers and version negotiation; unsafe writers reject, current Stores expose typed update guidance. No claim that an already distributed binary can be changed remotely.
- [x] Classify legacy addresses/pet references, unknown settings, zero old pending offers and retained acknowledgements; no guessed backfill, explicit participant owners.
- [x] Run two independent actual Simulator apps under the authorized fixture scope. Committed-result interruption/restart, reconnect and real server races are labeled separately from Store/source evidence in the final matrix.
- [x] Compare matching feasibility/fairness and measured cost/payload with G-10; scoped schedule/chat and OS reminder reconciliation accepted.
- [x] Run full regression/build/runtime/security and closeout checks; record the pre-existing governance cadence exception without weakening functional gates. Specific findings, operational/offline limits and failed attempts remain explicit.

**Acceptance:** all mandatory invariants pass; every policy-dependent capability has an approved operational owner and recovery path. **Rollback:** use compatible feature disablement or reviewed forward fixes; never reset marketplace data, remove safety constraints, or weaken RLS as a shortcut.

## Integrated Acceptance Scenarios

| Scenario | Required outcome |
|---|---|
| Publish succeeds, response disappears, user restarts | Recover the same request/operation, not another indistinguishable publication |
| Zero confirmed-fit candidates or unknown service duration | Truthful assessment/no-match state and explicit constraint-adjustment recovery; no fabricated fit |
| Two customers confirm overlapping offers for one groomer | At most one conflicting occupancy succeeds; the other receives a current next action |
| One pet has two overlapping requests with different groomers | At most one conflicting pet booking succeeds, including simultaneous acceptance |
| Customer edits a request while reviewing an old quote | Old quote cannot bind the new request terms; no partial booking is produced |
| Profile address changes after booking, including unit address | Existing agreed location remains intact or explicitly labeled legacy-unverified |
| Slot is temporarily taken and later released | Unchanged unexpired quote may become selectable again; withdrawn/expired terms do not revive |
| Service stops early or a no-show is reported | Actual evidence, occupancy release, review eligibility, and responsibility remain distinct |
| Reschedule races cancel/complete or the deadline passes | One valid current result; no double allocation and no lost original booking on failed change |
| Selected day's booking and target chat are beyond page one | Day is not falsely empty and authorized navigation still resolves |
| One conversation dominates message history | Other conversations retain correct bounded summaries |
| Another party changes booking while device is offline | Reconcile on reconnect; stale alert tap opens current state; no false promise of immediate offline withdrawal |
| Account exits while optional loads/reminder sync are pending | No old-account data or reminders reappear in the new session |
| Password recovery link expires or is reused | Safe error and a working recovery restart; no fabricated session or role |

## Validation And Authorization Handoff

The mode-required commands remain owned by Tooling Policy. The following existing local source checks are useful baselines, not sufficient acceptance for the new behavior:

```sh
node --test tests/migrations/request-publish-idempotency.test.mjs tests/migrations/time-boundary-contract.test.mjs tests/migrations/request-expiry.test.mjs tests/migrations/backfill-matching.test.mjs tests/migrations/participant-chat-booking-events.test.mjs
node --test tests/migrations/notification-rls-negative-contract.test.mjs tests/migrations/booking-handoff-read-state.test.mjs tests/migrations/chat-counterpart-avatar-access.test.mjs
```

Use the repository's iOS test/build scripts at the applicable gates; choose focused test identifiers from the actual adopted package rather than inventing script flags. Add true database rollback, separate-session concurrency, and network-fault tests under explicit authorization. Simulator testing does not grant permission to write real user data. No application/backend tests are implied to have run while writing this plan.

T-368 corrected the general documentation-closeout blockers: pending checkpoints are distinguished from completed tasks, and stale backend verification dates are advisory for unrelated work. Backend-dependent packages still require fresh evidence under Tooling Policy. This governance repair neither verifies deployed facts nor authorizes implementation; never falsify verification dates or task status.

## Coverage Matrix

Every register ID has an accountable package. Shared dependencies do not imply duplicate implementation.

| Register item | Accountable package(s) |
|---|---|
| F-01 | WP-01 |
| F-02 | WP-06 |
| F-03 | WP-05 |
| F-04 | WP-04 |
| F-05 | WP-03 |
| F-06 | WP-08, WP-09 |
| F-07 | WP-12 |
| F-08 | WP-10 |
| F-09 | WP-11 |
| F-10 | WP-09 |
| F-11 | WP-02 |
| F-12 | WP-02 |
| F-13 | WP-05 |
| F-14 | WP-04 |
| F-15 | WP-04 |
| C-01 | WP-13 |
| C-02 | WP-10 |
| C-03 | WP-03, WP-04 |
| L-01 | WP-00, WP-03, WP-05 |
| L-02 | WP-00, WP-07 |
| L-03 | WP-00, WP-03, WP-06 |
| L-04 | WP-00, WP-06 |

| Self-review correction | Accountable package(s) |
|---|---|
| Request changes must invalidate incompatible quote revisions | WP-05 |
| Cancellation does not always release all capacity immediately | WP-06 |
| Reschedule needs deadlines and self-allocation/quota exclusion | WP-07 |
| Temporary unselectability is not permanent quote termination | WP-05 |
| Estimated fit and legacy unknown data require honest handling | WP-03, WP-04, WP-14 |
| Notification reading is not necessarily booking acknowledgement | WP-10 |
| Planned completion and actual service end must be distinguished | WP-06 |
| Operational exceptions need a real owner without invented adjudication | WP-00, WP-06, WP-14 |

## Plan Review And Adoption

- [x] User adopted execution and subsequently authorized delegated judgment and necessary operations for the entire original plan; mere document drafting was not treated as deployment permission.
- [x] Allocate actual T-task IDs as packages were adopted, beginning with T-369/WP-00.
- [x] Bind each package to bounded contracts, concrete tests and original ownership; no subagents or unrelated timezone-settings work.
- [x] Complete the original packages under the user's later continuous-execution instruction and final local-only clarification; preserve explicit governance/offline/operational limits in T-385.
