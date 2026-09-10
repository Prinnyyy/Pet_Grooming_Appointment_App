# App Functional Design Findings

Recorded: 2026-09-07 under T-365 (documentation only).
Updated: 2026-09-07 under T-366 with the subsequent request/offer/scheduling and matching discussion (documentation only).
Reviewed source baseline: `fc7da7317938500b53100330363f91d4e71ab208` on `codex/pet-fit-structure-cleanup`.

Status: local functional remediation and acceptance completed through T-385 on 2026-09-10. WP-00...WP-14 account for all 22 items and eight review corrections; [final acceptance and limits](sql_reviews/T-385_RELEASE_CHECKPOINT.md) maps each to specific evidence. Two independent Simulators satisfy the user's scope; physical devices, signing and store distribution are excluded, not deferred blockers. Original review observations below remain historical.

Register: 15 findings (F-01 through F-15), 3 simplification candidates (C-01 through C-03), and 4 lifecycle policy questions (L-01 through L-04). Policy questions and remaining matching checks are not confirmed implementation defects.

## Scope And Evidence

The preceding review inspected the main authentication/role, pet/profile, request/matching, offer, booking/review, chat, notification, and account-deletion paths in local source and targeted migration definitions. This is a functional design/source review, not a completed visual, accessibility, production-security, or end-to-end audit.

- Observed code behavior is distinguished from proposed product changes below. Priorities are provisional: P1 should be addressed first; P2 affects normal usability or behavior at larger data volumes.
- Local migrations are evidence of repository implementation, not fresh proof of deployed database behavior. Cloud state and the project's actual API row limit were not checked.
- The review ran 20 existing local function/SQL-contract tests, all passing. These include mocks and source assertions; they do not reproduce or disprove all findings.
- The subsequent flow review ran 22 local SQL-contract tests, all passing, and executed the source time-window enum in an isolated Swift probe. The probe confirmed remaining same-day time can fail the Store's future-start rule and that morning/flexible preferences span 359/1,439 minutes. These checks were run during the review, not rerun by the recording task; they do not establish database concurrency or end-to-end reliability.
- Full iOS regression, a new app build, Simulator interaction, screenshots, and live backend validation were not performed in the review.
- No application code, backend, product decision, or roadmap scope was changed. Subsequent discussion may refine severity, intended behavior, or proposed solutions.

## Findings

### F-01 - P1 - Availability replacement can erase the previous schedule

- Remediation: T-371 deployed and verified atomic Save, three-boundary rollback, cross-account authorization, concurrent Save/acceptance and actual UI Save/draft recovery. See [acceptance evidence](sql_reviews/T-371_AVAILABILITY_ACCEPTANCE.md). Old-client distribution remains part of WP-14 release acceptance.

- Status: resolved under WP-01; current client/backend failure safety verified. This does not close the other findings.
- Trigger and impact: `replaceAvailability` deletes all existing windows before a separate insert request. Failure after deletion leaves the old schedule gone. `saveAvailability` also saves profile, windows, and preferences separately, so a single Save can partially succeed.
- Evidence: [SupabaseGroomerProfileRepository.swift](../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift), `replaceAvailability`; [GroomerProfileStore+ServicesAvailability.swift](../../ios/Beckon/Beckon/Features/Groomer/Profile/GroomerProfileStore+ServicesAvailability.swift), `saveAvailability`.
- Proposed direction: define the intended Save boundary and perform its database changes in one transactional RPC. A failed save should preserve the previous state.
- Follow-up validation: interrupt/fail the insertion and preference update; verify previous data and the presented save outcome remain consistent. Backend changes require a separately adopted scope.

### F-02 - P1 - Future bookings can be completed before service begins

- Status: resolved by T-377/WP-06; [deployed acceptance evidence](sql_reviews/T-377_FULFILLMENT_ACCEPTANCE.md). The original observations below remain historical.
- Trigger and impact: completion checks ownership and `confirmed` status but not appointment time. A future booking can become completed, enabling a review and removing cancellation eligibility before service takes place.
- Evidence: [completion helper](../../supabase/migrations/20260707183427_t159_private_rpc_lint_cleanup.sql), `app_private.complete_booking`; [Booking.swift](../../ios/Beckon/Beckon/Core/Models/Booking.swift), `canComplete`, `canCancel`, and `canReview`.
- Proposed direction: decide when completion is legitimate, including any early-finish case, and enforce the rule on the server as well as in UI affordances.
- Follow-up validation: future, ongoing, elapsed, cancelled, and already-completed bookings. The exact completion-time policy remains a product decision.
- Subsequent scope clarification: elapsed confirmed bookings remain `confirmed` and are classified under Past by [BookingsView.swift](../../ios/Beckon/Beckon/Features/Bookings/BookingsView.swift), `BookingListScope.contains`. This is not automatic completion or exception resolution; see L-04 before introducing another lifecycle state.

### F-03 - P1 - Booking addresses are incomplete and can change implicitly

- Status: resolved by T-376/WP-05: immutable complete agreement snapshots across Booking/Chat hydration, both service directions, full unit address and explicitly unverified legacy history. See [acceptance](sql_reviews/T-376_AGREEMENT_ACCEPTANCE.md).
- Trigger and impact: booking hydration omits Address Line 2, losing apartment/unit information. For customer-to-groomer appointments it reads the groomer's current profile address, so a profile edit changes the location shown for an existing booking.
- Evidence: [SupabaseBookingRepository.swift](../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift), `requestLocationColumns`, `groomerSummaryColumns`, and `groomerSummaries`; [Booking.swift](../../ios/Beckon/Beckon/Core/Models/Booking.swift), address fields and `appointmentAddressSummary`.
- Proposed direction: preserve the complete agreed service location at acceptance, including Address Line 2; make later appointment-location changes explicit rather than implicitly following profile edits.
- Follow-up validation: both service directions, unit addresses, profile changes after acceptance, booking detail, and chat booking cards. Snapshot persistence is a separate backend/product decision.

### F-04 - P2 - Service size configuration does not constrain matching

- Status: resolved by T-375/WP-04 under D-043: explicit service sizes are eligibility constraints; unknown sizes remain assessment. Direct quote/booking revalidation and client labels verified; see [acceptance](sql_reviews/T-375_MATCHING_ACCEPTANCE.md).
- Trigger and impact: the service editor stores a custom accepted size range, but the current matching eligibility condition checks active service type without consulting `accepted_pet_sizes`. A configured service range therefore does not filter request distribution.
- Evidence: [GroomerServicesEditorView.swift](../../ios/Beckon/Beckon/Features/Groomer/Profile/GroomerServicesEditorView.swift), `GroomerServiceAcceptedPetSizeSection`; [matching helper](../../supabase/migrations/20260712014418_t294_postgis_private_address_locations.sql), `create_request_matches_for_request`, service eligibility condition.
- Proposed direction: distinguish accepted sizes (eligibility) from size experience (ranking evidence), define inheritance/overrides once, and make UI wording match the enforced rule.
- Follow-up validation: custom ranges, inherited ranges, out-of-range requests, and whether existing matches/offers need revalidation after a change.

### F-05 - P2 - Preferred windows are treated as exact appointment intervals

- Status: resolved by T-374/WP-03 for request validation and offer defaults. Lasting Today-morning and 359/1,439-minute regression vectors, actual Wizard/offer interactions, deployed timing checks and full regression pass; see [UI evidence and limits](sql_reviews/T-374_TIMING_UI_ACCEPTANCE.md) and [backend acceptance](sql_reviews/T-374_TIMING_BACKEND_ACCEPTANCE.md). Matching explanations remain F-15/WP-04, not resolved here.
- Trigger and impact: Today plus flexible time creates a midnight start that fails the five-minute future-start validation. A partially elapsed preset window has the same problem. Separately, the default groomer offer copies the customer's entire preferred window, turning a morning preference into a nearly six-hour appointment interval.
- Evidence: [CustomerRequestWizardView.swift](../../ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestWizardView.swift), `flexibleRange` and `applySelectedTimeWindow`; [CustomerRequestsStore.swift](../../ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsStore.swift), `makeDraft` and `validateTimeAndLocationStep`; [GroomerRequestsStore.swift](../../ios/Beckon/Beckon/Features/Groomer/Requests/GroomerRequestsStore.swift), `defaultOfferRange`.
- Proposed direction: represent customer acceptable windows separately from proposed service duration. Clip today's windows to the valid remaining time and use service duration/availability for offer defaults.
- Follow-up validation: Today flexible, a partially elapsed morning, an expired window, future dates, and short services within broad preferences.
- Probe evidence: at 2026-09-07 10:00 in `America/Los_Angeles`, Today flexible and Today morning both retain future time but have starts before `now + 5 minutes`. Tomorrow morning spans 359 minutes and tomorrow flexible spans 1,439 minutes. This executed the existing enum with Foundation, not the full Wizard or a database transaction. F-15 separately records how the same broad-window assumption affects matching explanations.

### F-06 - P2 - Partial lists are used as complete business data

- Status: resolved by T-379/WP-08 and T-380/WP-09: nearest/date/exact booking/source reads and exact participant-pair chat routing. See [scoped reads](sql_reviews/T-379_SCOPED_READ_ACCEPTANCE.md) and [chat acceptance](sql_reviews/T-380_CHAT_SUMMARY_ACCEPTANCE.md).
- Trigger and impact: bookings are fetched in descending scheduled-start order with a default page size of 50. Home calculates the next booking from that first page; more than 50 future bookings can hide the nearest one. Booking-to-chat navigation also searches only loaded conversations and can report a missing chat when it exists on a later page.
- Evidence: [SupabaseBookingRepository.swift](../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift), paged `bookings`; [ListPagination.swift](../../ios/Beckon/Beckon/Core/Models/ListPagination.swift); [GroomerHomeStore.swift](../../ios/Beckon/Beckon/Features/Groomer/Home/GroomerHomeStore.swift), `loadBookings` and `nextBooking`; [ChatView.swift](../../ios/Beckon/Beckon/Features/Chat/ChatView.swift), `openFocusedConversationIfPossible`.
- Proposed direction: query the nearest eligible appointment and the target conversation directly. Keep list pagination separate from global lookup, schedule filtering, and summary logic.
- Follow-up validation: 51+ future bookings, 51+ conversations, and navigation to a conversation absent from the current page.
- Subsequent scope clarification: [BookingsStore.swift](../../ios/Beckon/Beckon/Features/Bookings/BookingsStore.swift), `load`, fetches the first page before [GroomerSchedulePresentation.swift](../../ios/Beckon/Beckon/Features/Bookings/GroomerSchedulePresentation.swift) filters the selected day. A day with an appointment outside that page can therefore appear empty. Validate date-scoped queries independently of the general booking list; unloaded is not equivalent to free.

### F-07 - P2 - Password recovery has no in-app flow

- Status: resolved under T-383/WP-12; [acceptance](sql_reviews/T-383_PASSWORD_RECOVERY_ACCEPTANCE.md) includes delivered recovery email, real SDK password change, account isolation, reused-link rejection and temporary-account cleanup. T-385 adds actual Simulator expired-callback/retry and marketplace-account preservation.
- Trigger and impact: a user who forgets an email-account password has no reset flow in the authentication UI or repository interface.
- Evidence: [AuthenticationStore.swift](../../ios/Beckon/Beckon/Features/Auth/AuthenticationStore.swift), production auth actions; [AuthenticationView.swift](../../ios/Beckon/Beckon/Features/Auth/AuthenticationView.swift); [AuthSessionRepository.swift](../../ios/Beckon/Beckon/Core/Repositories/AuthSessionRepository.swift), protocol surface.
- Proposed direction: provide reset-email request, recovery callback, new-password submission, and expired-link recovery as one complete flow.
- Follow-up validation: successful recovery, invalid/expired links, email delivery/rate limits, and resuming in the app. This is separate from Q-93 leaked-password protection.

### F-08 - P2 - Customer notifications do not route to the related action

- Status: resolved by T-381/WP-10 and T-385 actual integration. T-385 discovered and removed the remaining shared-page disappearance bulk-read call, added explicit Mark All Read, and verified old notifications open current Withdrawn/Cancelled states. See [package acceptance](sql_reviews/T-381_NOTIFICATION_ACCEPTANCE.md) and [final integration](sql_reviews/T-385_RELEASE_CHECKPOINT.md). Original evidence below is historical.
- Trigger and impact: customer notifications contain related request/offer/booking IDs, but their view supplies no selection action. A user reading New Offer must manually locate the request. Leaving the shared page marks loaded notifications read, even when not individually opened.
- Evidence: [CustomerNotification.swift](../../ios/Beckon/Beckon/Core/Models/CustomerNotification.swift), related IDs; [CustomerNotificationsView.swift](../../ios/Beckon/Beckon/Features/Customer/Notifications/CustomerNotificationsView.swift); [BeckonSystemNotifications.swift](../../ios/Beckon/Beckon/DesignSystem/BeckonSystemNotifications.swift), `selectAction` and `onDisappear`.
- Proposed direction: connect related notifications to existing destinations and separately decide whether read marking should depend on visibility, opening, or an explicit action.
- Follow-up validation: each notification kind, stale/deleted targets, unloaded destination data, and read-state behavior. APNs deployment is not part of this finding.

### F-09 - P2 - Local reminders can outlive cancelled bookings

- Status: resolved by T-382/WP-11 with complete owned snapshot reconciliation and session-safe cleanup. See [acceptance](sql_reviews/T-382_REMINDER_ACCEPTANCE.md), including explicit offline/delivery limits. Original evidence below is historical.
- Trigger and impact: reminder synchronization adds eligible reminders but does not remove previously scheduled reminders whose bookings became cancelled elsewhere. Cancellation cleanup runs only on the device executing the cancellation/completion action. Account exit also lacks reminder cleanup in the inspected paths.
- Evidence: [AppointmentReminderScheduler.swift](../../ios/Beckon/Beckon/Core/Services/AppointmentReminderScheduler.swift), `syncReminders` and `cancelReminder`; [BookingsStore.swift](../../ios/Beckon/Beckon/Features/Bookings/BookingsStore.swift); [AuthenticationStore.swift](../../ios/Beckon/Beckon/Features/Auth/AuthenticationStore.swift), `signOut` and `deleteAccount`.
- Proposed direction: reconcile scheduled reminders against authoritative booking state and clear account-owned reminders on exit. Do not treat absence from a partial page as proof of cancellation.
- Follow-up validation: other-party cancellation followed by refresh, logout/account switching, completion, and paginated booking data. Background delivery remains a separate concern.

### F-10 - P2 - Chat previews fetch message history instead of one summary per conversation

- Status: resolved by T-380/WP-09. Actual configured cap is 1000; 1500-message rollback vectors reproduce the old truncation and verify bounded indexed summaries preserve quiet conversations. See [acceptance](sql_reviews/T-380_CHAT_SUMMARY_ACCEPTANCE.md). Original evidence below is historical.
- Trigger and impact: `latestMessages` fetches messages for all listed conversations and chooses the latest per conversation in memory. Enough messages from busy conversations can exhaust the API response cap before other conversations' latest messages are returned, losing previews/unread evidence.
- Evidence: [SupabaseChatRepository.swift](../../ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseChatRepository.swift), `latestMessages`; [Supabase Swift select documentation](https://supabase.com/docs/reference/swift/select) describes the configurable response-row cap, defaulting to 1,000.
- Proposed direction: return one latest-message summary per authorized conversation from the backend, with explicit paging for the conversation list.
- Follow-up validation: a busy conversation exceeding the configured cap alongside quieter conversations; verify summaries/unread behavior and payload size.

### F-11 - P1 - Same-pet booking conflicts are not checked across requests

- Status: resolved under WP-02. Same-pet overlap reproduced before migration; authoritative pet exclusion, direct-writer protection and independent-session admission verified. See [T-373 evidence](sql_reviews/T-373_ACCEPTANCE_EVIDENCE.md).
- Trigger and impact: a customer can publish separate requests for the same active pet. Booking uniqueness is per request/offer, while the time exclusion and acceptance lock are groomer-scoped. The inspected acceptance path does not reject overlapping bookings for that pet with different groomers.
- Evidence: [booking constraints](../../supabase/migrations/20260621044424_t018_offer_acceptance_booking_backend.sql), `bookings_request_key`, `bookings_offer_key`, and `bookings_no_groomer_time_overlap`; [current acceptance helper](../../supabase/migrations/20260713223400_t351_participant_conversations_booking_events.sql), `app_private.accept_groomer_offer`; [request creation](../../supabase/migrations/20260712014418_t294_postgis_private_address_locations.sql), `app_private.create_grooming_request_v2`, active-pet validation and customer open-request limit.
- Proposed direction: protect the pet's occupied interval across requests at the authoritative acceptance boundary. Do not automatically prohibit all simultaneous bookings for a customer with different pets; that is a separate policy.
- Follow-up validation: sequential and concurrent acceptance for one pet across two requests/different groomers, nonoverlapping bookings, distinct pets, and cancellation freeing capacity. Existing groomer-overlap protection should remain intact.

### F-12 - P2 - Acceptance cannot replay success after a lost response

- Status: resolved under WP-02. Owned receipt replay, read-only reconciliation, account-scoped process persistence and current terminal-state recovery verified in backend/client layers. Physical-device network interruption is not claimed. See [T-373 evidence](sql_reviews/T-373_ACCEPTANCE_EVIDENCE.md).
- Trigger and impact: the server can commit an accepted offer and booking while its response is lost. A retry then hits `offer_not_pending` instead of returning the existing booking. The Store refreshes authoritative acceptance state after success, but its error branch only reports failure; the customer may not know a booking already exists.
- Evidence: [current acceptance helper](../../supabase/migrations/20260713223400_t351_participant_conversations_booking_events.sql), pending-status guard in `app_private.accept_groomer_offer`; [CustomerRequestsStore.swift](../../ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsStore.swift), `accept` and `refreshAfterAcceptance`.
- Proposed direction: replay the owned result for acceptance of the same offer and reconcile unknown outcomes before inviting another action. The existing publication v3 replay design is a useful reference, not evidence that acceptance already has it. Preserve authorization and rejection of competing offers; do not fabricate a successful booking after an error.
- Follow-up validation: committed acceptance with a dropped response, safe retry, app restart/reload, another device accepting first, and an offer losing to a competing offer. Verify one booking and no duplicate lifecycle messages.

### F-13 - P2 - Pending offers can remain visible after their time becomes unusable

- Status: resolved by T-376/WP-05: owned validity/selectability evaluation, local confirmation cutoff, atomic versioned acceptance/replacement, temporary slot recovery and terminal revocation. See [acceptance](sql_reviews/T-376_AGREEMENT_ACCEPTANCE.md).
- Trigger and impact: requests expire 48 hours after publication and offers inherit that deadline, independent of the proposed service start. A proposed start may pass, or a different request may consume the groomer's slot, while an offer remains pending. The acceptance UI checks status rather than current slot eligibility; server revalidation prevents acceptance but leaves an abrupt failure instead of a clear recovery path.
- Evidence: [request expiry assignment](../../supabase/migrations/20260712014418_t294_postgis_private_address_locations.sql), `create_grooming_request_v2`; [offer creation and exact availability](../../supabase/migrations/20260625073116_t071_availability_enforcement.sql); [request expiry conversion](../../supabase/migrations/20260706211524_t154_request_expiry_conversion.sql), `expire_grooming_requests`; [CustomerRequestDetailView.swift](../../ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestDetailView.swift), `acceptanceCard`.
- Proposed direction: distinguish request lifetime, offer confirmation deadline, and actual service start. Make stale/unavailable proposals visible as such and provide another-time/another-offer recovery, while retaining atomic acceptance checks. Whether an offer temporarily holds capacity remains a product decision; a pending offer currently is not a guaranteed reservation.
- Follow-up validation: a service starting within 48 hours, passage of the proposed start while a screen is open, two requests with overlapping offers, changed availability/time off, and expiry-worker delay. Do not equate a passing static cron test with deployed job health.

### F-14 - P2 - Day-capacity matching does not prove a usable service interval exists

- Status: resolved by T-375/WP-04: continuous interval evaluation rejects real occupied days and fragmented gaps below quota; explicit/legacy cases, writer guards and refresh contention verified. See [acceptance](sql_reviews/T-375_MATCHING_ACCEPTANCE.md).
- Trigger and impact: `groomer_has_capacity_on_request_day` checks an enabled local weekday, time off, advance-notice days, and confirmed/completed booking count. It does not check remaining continuous free time. A groomer below the daily count limit can pass even when existing bookings fill every usable window or the remaining gaps are too short for the requested service.
- Evidence: [day-capacity helper](../../supabase/migrations/20260701033335_t126_request_day_capacity_matching.sql), `app_private.groomer_has_capacity_on_request_day`; [current matching eligibility](../../supabase/migrations/20260712014418_t294_postgis_private_address_locations.sql), `create_request_matches_for_request`.
- Proposed direction: decide the minimum feasibility a distributed match promises. Prefer checking for at least one feasible interval based on agreed time semantics and service duration before ranking; preserve exact revalidation when an offer is accepted. Avoid adding a complex scheduling optimizer before those rules are settled.
- Follow-up validation: a fully occupied day below the count limit, fragmented free gaps, short versus long services, time off, local-date/DST boundaries, and any adopted preparation/travel buffers. Measure false-positive distribution with representative data.

### F-15 - P2 - Time-fit explanations test the whole preference window

- Status: resolved by T-375/WP-04: eligibility and explanations share the same interval result; broad windows may contain shorter valid services, unknown settings remain assessment and queued results read pending. See [acceptance](sql_reviews/T-375_MATCHING_ACCEPTANCE.md).
- Trigger and impact: matching calls `groomer_is_available_for_range` with the customer's entire preferred interval to choose between `Preferred time fits` and `Can suggest another time on your preferred day`. A valid one-hour opening inside a broad morning preference can receive the alternative-time explanation because the whole morning is not free. This branch chooses explanation text; it does not itself exclude the groomer or supply an availability ranking bonus.
- Evidence: [current matching helper](../../supabase/migrations/20260712014418_t294_postgis_private_address_locations.sql), `eligible_groomers.availability_reason`; [exact-range helper](../../supabase/migrations/20260625073116_t071_availability_enforcement.sql), `groomer_is_available_for_range`.
- Proposed direction: derive the explanation from a feasible proposed service interval and distinguish a time inside the customer's range from an explicitly permitted alternative. Do not suggest that a feasibility explanation guarantees a still-unreserved slot.
- Follow-up validation: a one-hour opening inside a morning preference, a valid same-day opening outside that preference, an entirely unavailable day, and customer permission for alternate times. Full ranking/exposure evaluation remains unperformed.

## Simplification Candidates

These are proposals for discussion, not approved refactors or proven performance measurements.

### C-01 - Separate core loading from optional enrichment

Disposition: T-384/WP-13 accepted under D-052; [evidence](sql_reviews/T-384_CORE_LOADING_ACCEPTANCE.md) covers fixed-data measurements, bounded optional reads, failed-metadata editing guards, dirty drafts, stale loads and full client regression. No generic Store split was needed. The following describes the original finding.

[GroomerProfileStore.load](../../ios/Beckon/Beckon/Features/Groomer/Profile/GroomerProfileStore.swift) serially reads nine data groups before assigning core results. An optional evidence/tag failure can prevent basic profile data from updating. [CustomerRequestsStore](../../ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsStore.swift) also loads photo data sequentially before continuing the main request load.

Proposed direction: show core data first, use bounded concurrency for independent reads, load photos on demand, and retain section-specific failure states. Split list and wizard responsibilities at existing feature boundaries only where this removes real coupling. Measure first-content latency and request counts before claiming improvement; retain the current repository architecture.

### C-02 - Reconsider a separate persistence system for booking-card acknowledgement

Disposition: D-049 retains one independent server-owned confirmation with a verified retryable account cache. T-381 [acceptance](sql_reviews/T-381_NOTIFICATION_ACCEPTANCE.md) covers read independence, retries and session isolation; T-385 completes local dual-Simulator qualification and removes the remaining automatic bulk-read path.

[CustomerRequestsStore.acknowledgeBookingHandoff](../../ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsStore.swift) maintains in-memory IDs, UserDefaults, and a remote acknowledgement RPC, alongside existing notification read state. This adds another synchronization/recovery path for a presentation state.

Proposed direction: first decide whether independent cross-device acknowledgement of the card is required. Reuse notification state when it meets that requirement; otherwise retain the distinct concept with an explicit reconciliation policy. Do not remove the existing persistence without that decision.

### C-03 - Make existing service configuration useful before adding more configuration

Disposition: T-374/T-375 use existing duration/price defaults and explicit size eligibility without duplicate configuration; T-385 verifies the actual numeric-keyboard quote form and authoritative readback.

Services already store base price, duration, and accepted sizes in [GroomerProfile.swift](../../ios/Beckon/Beckon/Core/Models/GroomerProfile.swift). The [offer form](../../ios/Beckon/Beckon/Features/Groomer/Requests/GroomerRequestsView.swift) starts with an empty price and defaults its interval through `defaultOfferRange`; size configuration does not constrain matching as described in F-04.

Proposed direction: use existing service values as editable offer defaults and clearly distinguish hard eligibility from ranking evidence. Reduce duplicate input and misleading settings before introducing additional scores, tags, or configuration pages. This overlaps F-04/F-05 and should not become a duplicate remediation package.

## Lifecycle Policy Questions

These questions preserve the discussion without adopting product rules, new states, persistence, or backend work.

### L-01 - Define what the customer's preferred time permits

Disposition: D-042/D-044 and T-374/T-376 require the full service within the accepted window and versioned consent; no silently broadened alternatives. Original question follows.

Decide whether the selected interval is mandatory, negotiable, or only a preferred date, and whether the entire service must fit inside it. The current [offer creation path](../../supabase/migrations/20260625073116_t071_availability_enforcement.sql), `create_groomer_offer`, checks the proposed range against groomer availability but does not constrain it to the request's preferred interval/date. Candidate direction: default to the customer's acceptable range and require explicit treatment of alternatives. Link this decision to F-05, F-14, and F-15 rather than independently redesigning each screen.

### L-02 - Define a safe rescheduling path

Resolved under T-378/WP-07 and D-046: time-only bilateral proposals preserve the original reservation until atomic acceptance, with base revisions, deadlines, rejection/withdrawal and conflict recovery. Same-booking overlap and target-day capacity are handled without dropping the old reservation. Both real cancellation race orders and exact fixture restoration pass; see [acceptance evidence](sql_reviews/T-378_RESCHEDULING_ACCEPTANCE.md). Other term changes remain new-request/agreement flows, not silent rescheduling.

### L-03 - Define the occupied interval beyond service time

Disposition: D-042/D-045 and T-374/T-377 define explicit preparation/cleanup/directional travel buffers and actual fulfillment release. Unknown buffers require owner confirmation; travel allowances are not arrival guarantees. Original question follows.

The [exact availability helper](../../supabase/migrations/20260625073116_t071_availability_enforcement.sql) checks service-range overlaps without explicit preparation, cleanup, or travel buffers. Back-to-back service intervals may therefore be valid in data but impractical, especially for mobile service. Decide which buffers are necessary and whether they differ by service direction. Prefer a simple explicit buffer policy before considering route optimization; no duration, routing dependency, or scheduling rule is adopted here.

### L-04 - Resolve elapsed bookings and service exceptions explicitly

Adopted under D-045 and implemented/accepted by T-377/WP-06; see [fulfillment contract](../03_backend/BOOKING_FULFILLMENT_CONTRACT.md). The following describes the original policy gap.

An elapsed confirmed booking moves into the customer's Past presentation without a new authoritative outcome. Decide how late service, no-show, and forgotten completion should be surfaced and resolved, alongside the legitimate completion-time policy in F-02. Avoid treating elapsed time as proof of service completion or adding states without an actor, transition rule, and recovery action. Evidence: [BookingListScope.contains](../../ios/Beckon/Beckon/Features/Bookings/BookingsView.swift) and [Booking status/actions](../../ios/Beckon/Beckon/Core/Models/Booking.swift).

## Matching Review Coverage

Core local matching rules were inspected: active profile/service eligibility, service direction and coordinate-backed distance, day-capacity filtering, the time-fit explanation, and the transition to exact offer/acceptance validation. F-04, F-14, and F-15 are the three matching-specific concerns discussed with the user. This is not a completed matching-specialist or production audit.

Historical unverified questions at the original review, now dispositioned by T-374/T-375/T-376 and [T-385](sql_reviews/T-385_RELEASE_CHECKPOINT.md). Approved representative vectors, current worker/cost checks and real server races pass; production-population recall or performance percentiles are not claimed:

- Ranking quality, tie-breaking, explainability, and exposure fairness across representative groomers and requests. A score is not a measured acceptance probability.
- Whether existing matches/offers are correctly refreshed or invalidated after service, size, address, availability, time-off, or capacity changes; inspect the complete lifecycle before declaring the existing backfill mechanism sufficient or defective.
- Zero-match recovery, retry/republication, and any user-approved expansion of dates or distance. Do not silently broaden customer constraints.
- Real-data match feasibility, recall, false-positive distribution, query plans, latency, and fan-out costs.
- Deployed matching/expiry jobs, dual-device concurrency, interrupted network responses, and full end-to-end transitions. Local source assertions do not establish these outcomes.

## Discussion And Verification Handoff

The bullets below preserve the original documentation-only handoff. They do not override the user's later execution authorization or the completed local acceptance recorded at the top.

- Proposed follow-up: [Functional Reliability Task Plan](../superpowers/plans/2026-09-07-functional-reliability-task-plan.md), recorded under T-367, maps every finding/candidate/policy question and the subsequent solution self-review to gated work packages. It does not close these findings or authorize implementation. Its temporary-unselectability and acknowledgement rules refine earlier discussion directions, subject to explicit approval.
- Preserve the request-first marketplace, Store/repository boundaries, RLS, and atomic offer acceptance unless a later finding justifies a focused change.
- Suggested order, not an adopted plan: schedule/data safety and acceptance-result recovery (F-01/F-11/F-12); booking state/location correctness (F-02/F-03); shared time/size/feasibility semantics (F-04/F-05/F-13/F-14/F-15); query/routing and reminder consistency; then adopted lifecycle recovery and measured simplification. Settle the relevant L-01...L-04 policies before implementation.
- Tentative closed-loop responsibilities: Requests express needs and acceptable constraints; Offers propose a feasible service interval, price, and confirmation deadline; Acceptance atomically revalidates and returns a durable Booking; agreed changes preserve the original arrangement until committed; terminal outcomes reconcile schedule, chat, and reminders. These are discussion directions, not an adopted architecture or implementation plan.
- T-157 APNs, Q-104 Groomer accessibility, and Q-93 leaked-password protection remain independently blocked/deferred under current project state. Already-deferred payments/disputes are not counted as new defects here.
- The user requested recording these findings before discussing other areas. Continue that discussion without automatically starting any fix. New observations should receive new IDs; revised conclusions should retain their original IDs and describe the change in evidence.

The preceding review's passing local checks were:

```sh
node --test tests/functions/account-deletion.test.mjs tests/migrations/participant-chat-booking-events.test.mjs tests/migrations/backfill-matching.test.mjs tests/migrations/booking-handoff-read-state.test.mjs tests/migrations/chat-counterpart-avatar-access.test.mjs
```

Result: 20 passed, 0 failed. T-365 records this earlier evidence; it does not claim these tests were rerun or that remediation is complete. Documentation-record validation is recorded in the [Worklog](../00_memory/WORKLOG.md).

The subsequent flow/matching review's passing local checks were:

```sh
node --test tests/migrations/request-publish-idempotency.test.mjs tests/migrations/time-boundary-contract.test.mjs tests/migrations/request-expiry.test.mjs tests/migrations/backfill-matching.test.mjs tests/migrations/participant-chat-booking-events.test.mjs
```

Result: 22 passed, 0 failed. These overlap the earlier command and are not 22 additional unique tests. The separate Swift probe ran the existing `CustomerRequestTimeWindowOption` enum with Foundation and checked the four time-boundary observations recorded in F-05; it made no repository edits and was not a Simulator or backend test. T-366 records these preceding results without claiming a rerun, production validation, or fixes.
