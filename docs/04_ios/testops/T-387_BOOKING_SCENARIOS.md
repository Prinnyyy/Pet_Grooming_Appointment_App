# T-387 Real Booking Scenarios

## Scope And Oracle

User-requested adversarial acceptance of the existing app, not a change to product policy. At least 50 cases must actually execute. H = real password-authenticated HTTP/RPC transactions against Beckon; U = actual Simulator UI. Database reads establish outcomes, not substitute privileged writes for customer/groomer behavior. No mock result counts as H/U. Every negative case needs the expected business/security error and unchanged authoritative state, not merely any error.

Actors: C1-C10 = existing BTC-003/004/016/049/005/007/008/009/010/011; G1/G2 = BTG-001/006. BTC-002 is the unrelated customer for access checks. Each customer uses their own active pet. HTTP tests use existing coordinate-backed locations as explicitly synthetic test destinations; they do not verify Maps geocoding. Simulator publication uses the customer's profile address and actual suggested-address confirmation. Temporary seven-day hours and explicit buffers are restored after the run. No account creation, DDL, RLS bypass in the behavior under test, real-device/store work, or modification of the existing BTC-001 request.

Default: mobile service, future Los Angeles dates, 08:00-22:00 hours, daily cap 4, notice 1 day, preparation 15 / cleanup 10 / inbound 30 / outbound 20 minutes. Mobile occupancy is service -45/+30 minutes. Studio would use -15/+10, but the original groomer address zones are unconfirmed; do not fabricate their provenance to pass a test. Dates are distinct between independent groups; related cases intentionally share live records. Zero price is currently allowed by contract, not assumed to be a defect. Different pets can be booked simultaneously under current pet/groomer resource policy; customer travel feasibility is recorded separately as a design question.

Expected behavior comes from [timing](../../03_backend/SERVICE_TIMING_CONTRACT.md), [fulfillment](../../03_backend/BOOKING_FULFILLMENT_CONTRACT.md), [rescheduling](../../03_backend/BOOKING_RESCHEDULING_CONTRACT.md), and the versioned agreement APIs used by the current app. Counts, exact receipts, revisions, unchanged agreements, occupancy and participant visibility are the primary assertions. HTTP dispatch concurrency proves transaction outcomes, not necessarily observed lock contention.

## Cases

Each row describes its setup/action and expected result. Actual per-case status, error, duration and redacted references are produced by the runner; `NOT RUN` remains distinct from failed or passed. Related cases may reuse the immediately preceding fixture, but failures do not turn dependent setup errors into additional product bugs.

| ID | Channel | Setup And Action | Expected Outcome |
|---|---|---|---|
| B01 | H | C1 publishes one valid request | Owned request, immutable terms revision, real eligible matches |
| B02 | H | C1 publishes requests for two owned pets | Two independent requests with correct pet snapshots |
| B03 | H | C1 publishes multiple distinct requests for one pet | Distinct intents remain distinct; no reservation before acceptance |
| B04 | H | Four customers each publish a request | Owner/pet isolation and all four successful publications |
| B05 | H | Retry the same publish operation | Same request and original receipt, no duplicate |
| B06 | H | Dispatch four copies of one publication concurrently | One request and identical receipts |
| B07 | H | C1 tries publishing for C2's pet | Ownership rejection, no request |
| B08 | H | Publish with end equal to start | Invalid window rejection, no request |
| B09 | H | Publish a wholly elapsed preference | Rejection, no request |
| B10 | H | Publish without a reference timezone | Explicit timezone rejection |
| B11 | H | Publish with a nonexistent timezone | Explicit timezone rejection |
| B12 | H | Publish an unsupported service identifier | Service validation rejection |
| B13 | H | G1 quotes a matched request at valid price/duration | One pending quote with exact agreement and buffers |
| B14 | H | G1 quotes six overlapping requests before any acceptance | Six pending quotes, zero bookings; quotes reserve no capacity |
| B15 | H | G1 quotes price zero | Accepted under current nonnegative-price policy |
| B16 | H | Quote a negative or sub-cent price | Each rejected without a quote |
| B17 | H | Quote a 14-minute service | Duration rejection |
| B18 | H | Quote a 15-minute service | Accepted lower duration boundary |
| B19 | H | Quote a 720-minute service inside hours and consent | Accepted upper duration boundary |
| B20 | H | Quote a 721-minute service | Duration rejection |
| B21 | H | Quote begins before the preferred window | Consent rejection |
| B22 | H | Quote ends after the preferred window | Consent rejection |
| B23 | H | Quote with a stale request revision | Revision rejection |
| B24 | H | Withdraw an offer, then quote again | Old quote remains withdrawn; new quote has new identity/revision |
| B25 | H | Repeat a quote while that groomer's offer is pending | No duplicate live quote |
| B26 | H | Two eligible groomers quote the same request | Independent quotes; no booking yet |
| B27 | H | Three customers accept G1's sequential jobs with buffers touching | Three nonoverlapping bookings and one quota count per service |
| B28 | H | Service times touch but preparation/cleanup overlap | Second acceptance rejected without a booking |
| B29 | H | Mobile jobs have enough studio gap but travel overlaps | Rejected; all four applied buffers are respected |
| B30 | H | Same pet, two groomers, overlapping service | One accepted booking, second rejected |
| B31 | H | Same customer, different pets and groomers, overlapping service | Allowed by current resource contract; no pet/groomer double-booking |
| B32 | H | Customers confirm four nonoverlapping G1 services in a day | All four accepted at exact daily limit |
| B33 | H | Accept a fifth otherwise nonoverlapping service that day | Daily capacity rejection |
| B34 | H | Cancel one pre-start booking and accept the fifth offer | Capacity is released and acceptance succeeds |
| B35 | H | Accept another appointment on a different local date | Previous day's quota does not leak |
| B36 | H | Keep multiple overlapping pending quotes, accept one | Pending quotes did not reserve capacity; only accepted job occupies |
| B37 | H | Quote becomes capacity-blocked; conflicting job is cancelled | Quote becomes selectable again while its terms remain valid |
| B38 | H | Six concurrent accepts of the same offer | One booking/conversation card, idempotent receipts |
| B39 | H | Concurrently accept two groomers' offers for one request | Exactly one winner and one booking |
| B40 | H | Two customers concurrently accept overlapping G1 jobs | Exactly one winner; no groomer overlap |
| B41 | H | Concurrently accept overlapping jobs for the same pet at two groomers | Exactly one winner; no pet overlap |
| B42 | H | Another customer tries accepting an offer | Access rejection and no mutation |
| B43 | H | Accept with a stale quote revision | Revision rejection and no booking |
| B44 | H | Cancel a request, then accept its old quote | Rejected; request stays cancelled |
| B45 | H | Propose a shift overlapping only the booking's own old interval | Proposal accepted by counterpart; same booking identity |
| B46 | H | Proposal author tries accepting their own proposal | Consent rejection; original booking unchanged |
| B47 | H | Counterpart proposes while one proposal is pending | Single-live-proposal rejection |
| B48 | H | Another job takes the time of a pending proposal | Other job succeeds because pending proposals do not reserve |
| B49 | H | Accept the now-conflicting proposal | Rejected; original booking and allocation remain intact |
| B50 | H | Counterpart rejects a proposal | Original booking unchanged; proposal rejected |
| B51 | H | Author withdraws a proposal | Original booking unchanged; proposal withdrawn |
| B52 | H | Replay accepted reschedule with identical operation ID | Original receipt, current booking, no second mutation |
| B53 | H | Race cancellation against reschedule acceptance | One winner; no duplicated or missing allocation |
| B54 | H | Save time off covering a confirmed booking | Save rejected atomically; existing schedule unchanged |
| B55 | H | Save availability with an old revision | HTTP conflict and no overwrite |
| B56 | H | Groomer starts a future confirmed booking before its start window | Early-start rejection |
| B57 | H | Groomer completes without a recorded Start | State rejection; booking not completed |
| B58 | H | Nonparticipant tries a fulfillment mutation | Access rejection and unchanged booking |
| B59 | H | Repeat the same pre-start cancellation operation | Same receipt and one fulfillment event |
| B60 | H | Review a confirmed but uncompleted booking | Review rejection and no review/rating change |
| B61 | H | Ten customers publish three requests each; groomer pages all 30 matches | Every eligible request returned exactly once across pages |
| B62 | H | Read reminder snapshot with several live bookings | Complete owned in-horizon booking set; cancelled jobs excluded |
| B63 | H | Nonparticipant reads quote/booking operation state | No foreign state or receipt disclosed |
| B64 | H | Read acceptance outcome after discarding the successful response | Existing receipt recovered without another booking |
| B65 | U | Customer publishes two distinct requests in one app session | Both visible separately after refresh/relaunch |
| B66 | U | Groomer submits offers for two requests in one app session | Correct request/time/price for each; offers remain distinct |
| B67 | U | Customer accepts multiple nonconflicting offers | Both bookings visible; correct details and calendar dates |
| B68 | U | Cancel one of those bookings and inspect both roles | Only that booking changes; the other remains confirmed |
| B69 | H | Customer reaches three open requests, tries a fourth, then cancels one and publishes | Fourth rejected; cancellation releases one slot |
| B70 | H | With two open requests, dispatch four distinct publications concurrently | Exactly one succeeds; total remains three |
| B71 | H | Groomer sends a text in a live confirmed booking's participant conversation | New customer notification contains a destination the current client can open |
| B72 | H | With three open requests, replace one using its current revision | Atomic replacement succeeds; total open requests remains three |

## Execution And Findings

Execution date: 2026-09-10. All 72 cases executed: **69 pass, three fail with reproducible product defects**. No product fix or remote deployment is included in this audit. Fixture cleanup and local verification are complete.

| Scope | Pass | Fail | Evidence |
|---|---:|---:|---|
| B01-B64, B69-B72: authenticated HTTP | 66 | 2 | B71/F1 and B72/F2 below |
| B65-B68: iPhone Air, iOS 26.5 | 3 | 1 | B65/B66/B68 pass; B67/F3 fails after both bookings commit |

Simulator actions used one device with successive real customer/groomer sessions. Concurrent acceptance/publication cases used concurrently dispatched authenticated HTTP calls, not two-device UI synchronization. B65 published two requests on September 11/12; B66 submitted distinct $105 quotes for 12:00-14:15; B67 confirmed both in the real confirmation sheets but detected a stale Bookings list. B68 found both bookings immediately in a fresh session, cancelled only the September 11 booking, and verified the September 12 booking remained byte-for-byte unchanged in both participants' authenticated reads.

Primary artifacts are local/ignored under `artifacts/testops/TESTOPS-T387-20260910-B/`. `results.json` holds the main 66-case run. `results-B21-B22-B23-B32-B33-B34-B39-B42-B43-B44.json` holds the corrected ten-case rerun (10/10 pass); it supersedes six initial fixture/oracle failures, not additional product bugs. `results-B71-B72.json` establishes B72; the corrected exact-client message payload in `results-B71.json` establishes B71. Count unique cases, not retries.

`ui-PublishTwoRequests.json`, `ui-QuoteTwoRequests.json`, `ui-AcceptTwoRequests.json` and `ui-CancelOneRequest.json` retain actual XCTest outcomes. `ui-outcomes-*` holds authenticated readbacks, including the pre-cancellation two-booking snapshot. The acceptance UI failure is intentionally retained even though its writes and subsequent API assertions succeed. The readback enum correction to `accepted_by_customer` was validated against the saved pre-cancellation snapshot and a fresh post-cancellation read; it is not an app defect.

### F1: Chat Notification Has No Destination

Severity: P2. B71 creates a confirmed booking, sends a groomer message with the three columns used by the app, and reads the new customer notification through that customer's authenticated session. The notification exists but `related_booking_id`, `related_request_id` and `related_offer_id` are all null while the booking remains confirmed. Evidence: `chat-notification-destination.json`, booking support reference `CE0F1E59`, notification `1C046875`.

Both deployed message triggers construct notifications with null target IDs: [participant conversation migration](../../../supabase/migrations/20260713223400_t351_participant_conversations_booking_events.sql). The current customer and groomer notification stores require a booking ID for `newMessage`, so opening this destination throws `notificationNotFound`: [customer routing](../../../ios/Beckon/Beckon/Features/Customer/Notifications/CustomerNotificationsStore.swift), [groomer routing](../../../ios/Beckon/Beckon/Features/Groomer/Notifications/GroomerNotificationsStore.swift). Existing routing tests inject a booking ID, hiding the server/client mismatch. This is not a notification left behind after deleting a booking.

Resolution direction: carry and authorize the participant conversation identity in message notifications, then route to that conversation. A conversation can span multiple bookings; attaching an arbitrary latest booking would not resolve the underlying contract. Schema/client compatibility and old notifications need explicit treatment in the fix.

### F2: Atomic Replacement Fails At The Normal Open-Request Cap

Severity: P2. B72 publishes three valid open requests, then calls `supersede_grooming_request` for one with the correct revision and a valid new operation. Actual result: HTTP 400 / P0001 `open_request_limit_exceeded`; the original request and authoritative state remain unchanged. Evidence: `replacement-at-cap.json`.

The [replacement implementation](../../../supabase/migrations/20260908203810_t376_versioned_agreements.sql) creates the replacement before cancelling the original. The underlying [publication limit](../../../supabase/migrations/20260712014418_t294_postgis_private_address_locations.sql) counts the original among the three open requests and rejects the insertion. Thus editing through replacement fails at a legal, ordinary account state even though its net open count would remain three.

Resolution direction: account for the locked, owned original as a replacement within the same transaction, preserving cap enforcement, ownership, revision validation, idempotent receipts and rollback. Do not loosen the global cap or require cancel-first, which loses the original request/offers before replacement succeeds.

### F3: Second Confirmed Booking Does Not Reach The Open Bookings List

Severity: P2. B67 confirms the September 11 quote and opens Bookings, then returns to Requests and confirms the September 12 quote. Both confirmation sheets succeed and show their booking details. Returning to Bookings again leaves the second booking absent for the test's 20-second wait. Both customer and groomer authenticated reads show two confirmed bookings. In B68, a fresh customer session immediately displays both rows without scrolling, excluding a missing server record or offscreen-row explanation.

Evidence: `ui-AcceptTwoRequests.json` (real UI failure), `ui-acceptance-postfailure.json`, `ui-outcomes-AcceptTwoRequests.json`, and the explicit fresh-session assertion in `ui-CancelOneRequest.json`. Requests `56A0F928` / `46612764` map to bookings `2C7F8BFC` / `D0890BA8`. The later cancellation is a separate, passing action; it does not retroactively turn B67 green.

The [customer tab root](../../../ios/Beckon/Beckon/Features/Customer/CustomerTabView.swift) constructs a separate Bookings store and does not notify it after acceptance or on tab selection. The [Bookings view](../../../ios/Beckon/Beckon/Features/Bookings/BookingsView.swift) relies on pull-to-refresh and [foreground refresh](../../../ios/Beckon/Beckon/Core/Infrastructure/ForegroundRefreshGate.swift). That gate suppresses repeat initial loads and defaults to a 45-second fallback loop; the successful acceptance updates its own detail flow, not the already-loaded list.

Resolution direction: reconcile the authoritative acceptance receipt into shared booking state, or explicitly invalidate/refetch the affected list when returning to its tab. Keep periodic refresh as recovery, not the primary propagation path for a successful local booking action. This is stale presentation, not a lost or duplicate booking.

### Evidence Limits And Calibration

- The preliminary A run had an invalid fixture assumption allowing more than three open requests per customer. Its cascading failures are not 48 app bugs and are excluded from acceptance counts.
- In B, B21-B23 initially used a preference too short for matching the configured full-groom service; the corrected window reaches the intended quote checks. B34's fifth job initially overlapped mobile preparation, so its start was corrected to the actual occupancy boundary. B39/B44 now recognize the valid `offer_not_pending` rejection and verify one/no booking as appropriate.
- The first B71 message probe included columns the client never writes and was correctly rejected by column grants. Only the corrected three-column payload establishes F1.
- Simulator calibration corrected offscreen/occluded targets, missing XCTest accessory identifiers, horizontal request cards and obsolete navigation selectors. One default test quote was inadvertently submitted and then withdrawn; the two final quotes were entered and verified in one successful UI session. These driver failures are distinct from F3's reproduced stale list. A transient management-API TLS timeout occurred before any write and was retried sequentially.
- Concurrent HTTP dispatch verifies winners, final counts and resource invariants; it does not claim measured database lock contention. B64 verifies read-only outcome recovery, not a physical network interruption. No successful service Start/Complete or real local reminder delivery is inferred from negative fulfillment/snapshot tests.
- Mobile timing is covered. Studio timing, ambiguous/nonexistent DST input, physical devices and store/APNs delivery are not claimed tested. Dates are timezone-aware, but generating dates across DST is not itself a DST input test.
- Calibration A cleanup restored business rows/settings but advanced the two test groomers' security eligibility revision/audit timestamps through an initial preference delete/reinsert. This was a harness mistake; immutable/security metadata was not forced backwards. Six targetless test message notifications were separately verified against the original snapshot and removed. B restored preferences in place without repeating that issue.
- Early HTTP artifacts' `source` field identifies the on-disk runner at save time, not a frozen loaded-code manifest; do not use it as exact execution provenance. The current runner captures its own hash once at startup. Actual transaction traces and the explicitly identified corrected reruns establish this audit's outcomes.

### Reproduction Commands

After authorization for a fresh idle test cohort, set a unique `TESTOPS_RUN_ID` beginning `TESTOPS-T387-` and `TESTOPS_REMOTE_WRITE_APPROVED=1` in the process environment. Do not reuse this restored run ID, run concurrent linked CLI writers, or rerun the broad HTTP suite while preserving open UI fixtures.

```bash
node scripts/test-t387-booking-scenarios.mjs prepare
node scripts/test-t387-booking-scenarios.mjs run
node scripts/test-t387-simulator-sign-in.mjs customer PublishTwoRequests
node scripts/test-t387-simulator-sign-in.mjs groomer QuoteTwoRequests
node scripts/test-t387-simulator-sign-in.mjs customer AcceptTwoRequests
node scripts/test-t387-simulator-sign-in.mjs customer CancelOneRequest
node scripts/test-t387-booking-scenarios.mjs cleanup
```

An expected defect exits nonzero. Inspect its artifact and current authoritative state before continuing; do not restart successful writes just to obtain a green process exit. `TESTOPS_VERIFY_ONLY=1` rechecks an existing UI phase's authoritative outcomes without replaying UI actions and explicitly preserves its original XCTest outcome. Focused HTTP reruns use `TESTOPS_CASES`; dependent cases need their setup cases, and `TESTOPS_DAY_OFFSET` separates new fixture dates from still-live bookings.

### Closeout

- `final-results.json` reconciles the 72 catalog IDs to their final evidence: 69 pass, three fail, zero not run. Intentional defect reproductions remain red.
- B `restoration.json` matches all 15 original aggregate snapshot sets; `recovery.json` records restoration complete. Preference `updated_at` intentionally advances. No tagged requests remain; request-linked bookings, conversations, messages, operations, notifications and private request addresses were scoped and removed. Baseline data/settings hashes, including the cohort's existing notifications, match. The separate A qualification above remains.
- `original-request-preserved.json` confirms BTC-001 request `F294E9D7` remains open, with zero matches and the original September 11 09:16:11-11:16:11 UTC preference and September 12 expiry. It was never part of the write/cleanup cohort.
- `./scripts/preflight.sh` passed: 3 brand, 116 migration and 10 function checks; the UI consistency audit passed with its existing findings. All three new Node scripts pass syntax checks. `./scripts/ios-build.sh` passed (only the no-AppIntents metadata warning). The post-cleanup authentication-root Simulator smoke command completed successfully; no live test account remains signed in through this flow.
- Production app/backend behavior was not edited. Full unrelated Swift regression, real devices, signing/store work and APNs delivery were not run or claimed. Local documentation hygiene and scoped Git diff review complete the audit packaging, not the fixes for F1-F3.
