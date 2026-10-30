# Decision Log

Use this for durable architecture/product/workflow decisions. Keep active entries compact; full historical text lives in frozen snapshots.

Full pre-T-174 snapshot: `../09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.

## Format

```text
Decision ID:
Date:
Decision:
Context:
Consequences:
Linked files:
```

## Active Decisions

```text
Decision ID: D-067
Date: 2026-10-29
Task: T-423
Decision: Customer cross-feature navigation belongs to the destination tab. Home glance selects Grooming's card; successful publication selects the new card after dismissal. Wizard Add pet suspends/resumes its existing draft through Home; ordinary no-pet creation still stays on Home after save. Recovery is a root surface preserving its isolated authentication context. Launch runs once, and loading/entrance clocks only run when visible.
Context: The user adopted the 57-route register's eight problem areas and requested smooth, reusable navigation/startup behavior. T-422 hid startup-time animations and allowed repeated launch gating; programmatic navigation rebuilt the Grooming root and left foreign pages in Home.
Consequences: Existing stores, publication recovery and authorization remain; stable path changes replace root recreation, independent reads overlap, and log I/O leaves the main actor. Existing UI spec owns the reusable standard. No new dependency or backend contract.
T-425 refinement: Keep one visible, noninteractive lockup across launch/welcome; remove it from accessibility after handoff. Use the brandWords spring for a subtle whole-word lift/fade instead of clipping letters. Account resolution uses a delayed role-neutral indicator, leaving Home to own its only skeleton reveal. Authentication, role checks and recovery remain unchanged.
Linked files: docs/superpowers/plans/2026-10-29-navigation-launch-reliability.md.
```


```text
Decision ID: D-066
Date: 2026-10-29
Task: T-422
Decision: Adopt handoff 3's latest customer flow and visual states. One launch scene spans startup/session/profile resolution; real failure and retry remain reachable. Existing Stores expose first-load completion instead of a timed assumption; skeletons delay 0.15s, remain at least 0.45s and reveal content in place, never return for refresh/load-more. Home's 72pt pull refresh is explicitly approved, as is lawn color B1E0C5. Request entry with no pet opens one Add pet first dialog; Grooming routes to Home's existing form and saving remains on Home.
Context: The user prioritizes the refined interaction flow, delegates D1/D2/D6, and permits shared component updates across roles because groomer UX will be redesigned later. This supersedes handoff 3's customer-only restriction for shared primitives, not its data safety constraints.
Consequences: Adopt the new Home scene/header/hero, reserved loading layouts, plain empty cards and aligned tab title rows. Shared title/loading primitives may evolve together; preserve role semantics, actions and accents. Reuse tokens and existing repositories/fixtures; no six-second false success, new backend state, broad audit exemption or groomer-page redesign.
Linked files: docs/superpowers/plans/2026-10-29-loading-home-flow-adoption.md.
```

```text
Decision ID: D-065
Date: 2026-10-29
Task: T-421
Decision: Adopt handoff 2 as the customer flow authority, including necessary backend adaptation. D1: verified completion or the later of service-zone next midnight and scheduled end makes grooming Finished; unresolved reported outcomes remain actionable. Elapsed reviews use an empty unverified evidence context and never complete the booking or fabricate professional evidence; 14 days is active-card retention only. D2: customer-safe groomer profile RPC reads existing services, portfolio, active claims and public schedule summaries; private time-off titles and precise addresses remain excluded. D3: Confirm booking replaces the selection stack with one booking detail. D4: keep internal requests and customer.tab.requests titled Grooming; legacy bookings is absent from visible customer tabs. D5/D6: adopt the refined wording and information density, retaining precise operational errors.
Context: The user explicitly authorized frontend/backend work and clarified that the refined UX changed the actual flow. Customer pages need not connect to existing groomer UI; that UI will be updated later.
Consequences: Four customer tabs, one grooming feed/card/detail, combined History, Home Next up. First address timezone preserves wall-clock choices; editable Review returns directly. Clean Send closes the wizard immediately on its originating tab, superseding D-064's prior completion routing. Favorites starts unselected, uses batch Select mode, and opens the same real profile as discovery. Authentication adopts the drawn pup and pinned forms. Existing ownership, session, quota, recovery, RLS and private image safeguards remain. This updates D-064's scope without redesigning groomer pages.
Linked files: docs/superpowers/plans/2026-10-29-customer-ui-flow-adoption.md, docs/01_product/SCREEN_INVENTORY.md, docs/01_product/LIVELY_UI_SPEC.md.
```

```text
Decision ID: D-064
Date: 2026-10-25
Task: T-420
Decision: Adopt the reviewed customer prototype across production customer pages, plus authentication, shared account actions and booking confirmations. Extend D-063's ledge/rounded treatment to customer form chrome, settings and dialogs; input and thread content remain calm. Shared Bookings/Chat/kit consumers select customer appearance explicitly, preserving groomer layouts.
Context: The user approved the complete prototype and its six-step request flow, feedback layers, active-request root, customer booking journey, pet-removal confirmation and saved-groomer Undo. The prototype is a visual source; Stores, repositories, authorization, recovery, error copy and identifiers remain production contracts.
Consequences: CustomerTabView owns plain-cut routing and active-tab wizard presentation. Step/detail/list entrance families replay only while active and onscreen; Reduce Motion fades. Request creation ends in one selectable groomer list with explicit pool consent and a server-enforced five-outstanding limit. Capacity is labelled unknown until reliable quote evidence is complete; extrema badges require complete current offers. Closed requests live in history. Toast timing belongs to the feedback center; page-owned Undo uses the existing favorite mutation. Decision alerts and dismissible modals share the kit. Sandbox hosts use real views with existing isolated mocks; frozen prototype sources stay untouched. No backend, persistence capability, signing or groomer-layout redesign.
Linked files: docs/superpowers/plans/2026-10-25-customer-ui-adoption.md, docs/01_product/LIVELY_UI_SPEC.md, docs/01_product/SCREEN_INVENTORY.md, ios/Beckon/Beckon/DesignSystem/DesignDialog.swift.
```

```text
Decision ID: D-063
Date: 2026-10-23
Task: T-419
Decision: Adopt the Lively style as a tiered, Customer-side extension of the design contract: ledge surfaces, SF Rounded expressive type and bounded motion for Tier L (Customer Home, empty and celebration states) and Tier M (Customer request, booking and pet lists and details). Tier C (forms, chat, settings, payments, destructive confirmations, every Groomer screen) keeps the existing calm contract.
Context: The user approved the sandbox prototype as the direction and asked for adoption starting with Customer Home. The prior contract forbade decorative animation outside the brand illustration, allowed one quiet shadow tier, and required semantic system type.
Consequences: DesignTokens gains Ledge, Motion, expressive CornerRadius and Metrics, and Typography.Expressive. DesignSystem gains the ledge surfaces, entrance and motion modifiers, journey, expressive components and the illustration layer. Customer Home, the Home request summary and the Customer notification bell use them; D-062's Playful sandbox hooks are retired. Audit rules UI015 (motion), UI016 (rounded type) and UI017 (ledge tier allowlist) hold the boundary; a new surface variant, type role, spring, decorative loop or Tier L/M screen is a spec change plus a Decision Log entry. White on the unread dot becomes an approved pair. Amends the Design System visual direction, UI-R2/R3/R6, A11Y-R1 and the approved pairs as listed in the spec.
Linked files: docs/01_product/LIVELY_UI_SPEC.md, docs/01_product/DESIGN_SYSTEM.md, ios/Beckon/Beckon/DesignSystem/BeckonLedge.swift, scripts/ui-consistency-audit-core.mjs.
```

```text
Decision ID: D-062
Date: 2026-10-20
Task: T-418
Decision: Route isolated SwiftUI Flow Sandbox work through one lightweight workflow instead of production lifecycle and closeout gates.
Context: T-417 took about 28 minutes; repeated Canvas interaction and broad/redundant validation delayed a small local UX experiment. The user requested distinct execution rules.
Consequences: Default to local Preview delivery, focused isolation/state evidence and one core walkthrough; no automatic full regression, duplicate build, task paperwork or Git delivery. Escalate actual production-affecting changes only. Preserve data isolation, user work and authorization. AGENTS, Development Guide, build instructions and the docs index route to one authority.
Linked files: docs/05_workflow/SWIFTUI_FLOW_SANDBOX_WORKFLOW.md.
```

```text
Decision ID: D-061
Date: 2026-10-18
Task: T-416
Decision: Keep authentication brand artwork separate from D-060's control surfaces and card elevation. Preserve its small bubbles; use a borderless mint main bubble, translucent highlight, soft shadow behind the icon layer, one-time opening animation and bounded continuous float.
Context: Color migration turned translucent artwork into opaque control colors and reused the flattened card shadow. The user requested repair and explicitly retained the surrounding small bubbles.
Consequences: One DesignSystem artwork component and named material tokens, no general Feature opacity exception or new motion framework. Keep authentication flows and global control/card tokens unchanged. Require rendered material and motion evidence, not just source checks.
User clarification (2026-10-18): The opening animation must remain. "Below the icon" means behind its layer, not an ellipse on an imagined ground plane. The initial T-416 interpretation is superseded; Reduce Motion skips entrance and stops float.
Linked files: docs/01_product/DESIGN_SYSTEM.md; docs/08_design/UI_IMPLEMENTATION_NOTES.md
```

```text
Decision ID: D-060
Date: 2026-10-17
Decision: Adopt the UI color handoff's D1-D3: retain light mint/ coral role fills and warm backgrounds; use role Ink on Fill, Deep for text/controls and opaque Tint for selection. Domain status uses shared semantic presentation, independent of viewer role. Exact sRGB values and contrast pairs belong to Swift tokens and tests, not duplicate JSON palettes.
Context: The user requested implementation of the handoff. The earlier white-text solid-button proposal is superseded. The concern in 10-existing-visual-language-audit.md that coral must not become a second brand is satisfied by common components/layout and restricted Fill/Ink/Deep/Tint usage, not by removing the Groomer role color.
Consequences: No white text on light role fills, accent-opacity surfaces, gradient buttons or colored action shadows. One quiet card elevation; semantic status includes text and symbols. Implementation proceeds through the adopted plan; this decision is not a claim that all Feature consumers have migrated. No backend, navigation, signing or dark-mode work.
Linked files: docs/superpowers/plans/2026-10-17-ui-color-implementation.md; docs/01_product/DESIGN_SYSTEM.md; docs/01_product/ACCESSIBILITY_RULES.md
```

```text
Decision ID: D-059
Date: 2026-09-21
Task: T-397
Decision: Design one request-first transaction with customer-selected groomer invitations and an explicitly optional eligible-groomer request pool. Use a reversible recommendation carousel, complete candidate list and private account favorites; browsing and saving never send or reject requests.
Context: The user chose this combined direction after reviewing the limits of passive waiting and a separate alternative-slot model. Existing publication automatically distributes matches, so pre-publication discovery and new access boundaries require explicit design rather than only new cards.
Consequences: The linked spec and plan define private preview, atomic send/recovery, shared quotes and unique booking, pool-close semantics, safe media/legacy access, and Simulator acceptance. Eight cards, opt-in pool, five outstanding invited counterparts and response/preview lifetimes are proposed first-version defaults for review. This records the design direction and documentation delivery only; implementation, remote writes and deployment are not authorized or claimed complete. Existing matching evidence formulas and booking safety remain; D-055's former exclusion of discovery is superseded only for this adopted design scope.
Refinement (T-398, 2026-09-21): Reuse existing frontend publication recovery through one feature-owned coordinator and backend rules through trusted-context adapters. First publication has one authoritative publish receipt; later distribution actions have their own ledger. Share safe profile projections, evidence, pagination and scoped state, not private owner models or broad authorization. The linked spec section 7 and original work packages own these constraints; no product implementation is claimed.
Linked files: docs/superpowers/specs/2026-09-21-request-discovery-invitations-design.md; docs/superpowers/plans/2026-09-21-request-discovery-invitations-plan.md.
```

```text
Decision ID: D-058
Date: 2026-09-21
Task: T-396
Decision: Separate generic DesignSystem primitives, reusable SharedFeatures business UI, and feature-specific flow state; retain existing Stores/repositories and native navigation.
Context: Address resolution lived among visual primitives, quote/wizard async state lived in views, fit evidence was duplicated, and Home dropped the selected booking at the tab boundary.
Consequences: Share display only, preserve role-specific evidence/privacy mapping, pass the selected booking to an exact-read detail destination, and remove non-rendering style flags. No new packages, routing framework, backend changes or broad legacy visual redesign. Source audit passing is a debt ratchet, not proof of complete visual acceptance.
Linked files: docs/01_product/DESIGN_SYSTEM.md; docs/04_ios/UI_CODE_GOVERNANCE.md.
```

```text
Decision ID: D-057
Date: 2026-09-15
Task: T-394
Decision: Use one on-demand app demo video workflow with a motion-rich sample gate before bulk capture and full-length production. Reuse valid genuine UI media first; separately assess information, visual quality, technical validity and scoped restoration.
Context: T-393 rendered and restored successfully, but the user found the film visually flat. Technical sample approval did not establish launch-film quality; serial fixture discovery, capture mistakes, VFR edits and excessive tool output added rework.
Consequences: Keep a compact production record, a shot-to-asset map, preflight for necessary data operations, exact cleanup and change-scoped QA. A toolkit change alone is not aesthetic acceptance. The workflow adds no install, account, remote-write, upload or video-remake authorization. Existing host and Development Guide rules remain authoritative.
Linked files: docs/05_workflow/APP_DEMO_VIDEO_WORKFLOW.md; docs/README.md; docs/05_workflow/DEVELOPMENT_GUIDE.md.
```

```text
Decision ID: D-056
Date: 2026-09-15
Task: T-392 / V-04
Decision: Use a marketplace-only, short-lived soft-evidence snapshot for new ranked v2 POST reads, under the adopted plan's delegated consistency decision. Preserve the current algorithm and explicit sort priorities. A fresh browse/refresh captures current scores, public rating aggregates and explanations; continuation keeps that same score_as_of for at most five minutes, shortened by existing hard deadlines.
Context: Recomputing changed professional evidence on every page makes ordinary review arrivals interrupt browsing. Merely omitting soft fields from the revision could silently mix ordering/versions; eager full-list client reads would evade the real paging requirement. Neither is accepted.
Consequences: Retain stable, single-statement authorized candidate evaluation in a private core. A narrow volatile v2 wrapper persists only candidate score/aggregate data, never credentials, coordinates, request text or individual review/customer details. Every page revalidates live hard facts, membership, role/ownership, mode, algorithm and privacy epoch; hard changes still return list_changed and booking admission remains uncached. Signed cursors bind an opaque snapshot ID. Existing stable endpoints/cursors remain compatible. Private RLS/no-client-grant storage expires after five minutes, caps each entry at256KiB and each viewer at32 entries, and uses bounded scheduled expiry cleanup. Oversized scopes keep all candidates using the legacy strict-consistency path, never truncate the pool. Privacy redaction changes the epoch immediately; expired/evicted/missing snapshots recover through the existing one-refresh path. Validate actual soft/hard/privacy behavior and original performance budgets before claiming deployment or acceptance.
Linked files: docs/superpowers/plans/2026-09-15-synthetic-multi-simulator-acceptance-plan.md; docs/04_ios/testops/T-392_CLIENT_ACCEPTANCE.md.
```

```text
Decision ID: D-055
Date: 2026-09-10
Task: T-389
Decision: Design matching as explicit eligibility, trustworthy contextual evidence, role-specific explicit-preference ranking and authoritative booking admission. Retain request-first distribution and all lawful candidates; raw public ratings remain exact and separate from internal smoothed scores. No implicit customer-value or behavioral-learning model is adopted.
Context: The user approved the conceptual rules and requested continued discovery of defects or simpler approaches while preparing the detailed design. Review uncovered refinements to decay under repeat-customer caps, partial evidence, custom-service comparability, historical service timestamps and globally ranked pagination.
Consequences: Publish one detailed spec with counterexamples, tunable parameters and implementation acceptance boundaries. Reuse existing Store/repository/SQL and refresh ownership. This is a design decision, not deployment or implementation approval; source-integrity fixes cannot be rolled back merely to revert ranking. Written refinements remain reviewable before the detailed execution plan.
Linked files: docs/superpowers/specs/2026-09-10-matching-rating-system-design.md.
```

```text
Decision ID: D-054
Date: 2026-09-10
Task: T-388
Decision: Text-message notifications target the participant conversation, not one of its bookings. Customer Requests and Bookings share a session-owned Store; acceptance receipts require an exact current Booking read before publication because confirmed receipts do not distinguish first execution from replay after rescheduling. Atomic request replacement retires the locked original before invoking the unchanged quota-checked publication in the same transaction.
Context: T-387 confirmed three defects. The adopted remediation retains the three-open-request limit, role boundaries, existing repositories and Simulator-only acceptance.
Consequences: Add a nullable conversation target with no historical guessing; deploy its schema before the client's explicit select. One bounded booking read replaces unsafe quote projection; read failures preserve acceptance recovery identity. Invalidate stale list/exact reads after committed mutations. Migrations and real TestOps acceptance remain separately authorized and are not claimed deployed by this decision.
Linked files: docs/superpowers/plans/2026-09-10-booking-defect-remediation-plan.md.
```

```text
Decision ID: D-053
Date: 2026-09-10
Task: T-386
Decision: Adopt the revised lean-governance plan: one on-demand Development Guide and one structured Current State with scoped pending-task recovery. Retire daily ledger/worklog writes, fixed cadence/wording gates, forced session boundaries and automatic closeout rotation.
Context: User requested lower coordination overhead and approved implementation after four review corrections. Existing dirty originals were preserved before cutover; historical T-365 through T-367 drafting closure is not functional incompletion or a fabricated old Git commit.
Consequences: Continue adopted objectives with risk-based validation and reusable valid evidence. The read-only checker validates structure, safe paths and active/changed links, including search-hidden current plans. Keep task authorization isolated, user edits and credentials protected, backend freshness verified by relevant evidence, and existing completion-only Git authorization unchanged. No app/backend/signing/store or host-plugin changes.
Linked files: docs/05_workflow/DEVELOPMENT_GUIDE.md; docs/superpowers/plans/2026-09-10-lean-governance-plan.md.
```

```text
Decision ID: D-052
Date: 2026-09-09
Task: T-384 / original WP-13, G-10 loading budget
Decision: Publish authoritative profile/services/schedule and request/booking facts before optional metadata or images. Each load uses at most four independent metadata reads and each image batch at most three concurrent downloads within existing Store/repository ownership. Failed or unfinished fit metadata cannot become an empty replacement; preserve dirty forms and reject cancelled, superseded or pre-mutation loads. Do not start profile refreshes during a save/upload.
Evidence: Fixed six-image/192KiB fixture with 20ms per repository read: baseline core 160.8ms, total 311.2ms, 14 reads; first core-first run core 68.5ms, total 159.5ms, same 14 reads and 196608 image bytes. These are controlled repository measurements, not production HTTP latency or total wire-byte claims.
Acceptance: No optional read on the core publication path, no increased reads/image payload for the fixed fixture, bounded image concurrency and failure/dirty-edit/session/mutation tests. Preserve unchanged backend query shapes and critical missing-data rejection; complete request-list measurements and shared regression before acceptance. No invented global speed or matching-quality target.
```

```text
Decision ID: D-051
Date: 2026-09-09
Decision: WP-12 uses a dedicated PKCE recovery client with its own Keychain storage key and exact com.hellobeckon.beckon://auth/recovery callback; the normal marketplace session is never replaced by a recovery callback.
Context: Installed SDK defaults to PKCE and namespaces its verifier by storageKey. Existing recovery-like callback handling can replace a signed-in account. Hosted SMTP is verified Resend; OTP lifetime is 3600 seconds and the old exact callback remains configured.
Consequences: Request/resend, callback retry, verified new-password submission and session cleanup stay behind AuthSessionRepository/AuthenticationStore. Recovery survives restart in isolated secure SDK storage, but never grants marketplace entry. Success returns to the existing account or sign-in, without inventing role/session state. Append only the exact recovery URI to the allow list. Verify delivery/callback using a newly created disposable alias account, never reset an existing user's password; remove the identified test account afterward. Keep full links, PKCE verifiers and credentials out of logs.
Linked files: docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md; docs/03_backend/AUTH_EMAIL_DEEP_LINK_DESIGN.md.
```

```text
Decision ID: D-050
Date: 2026-09-08
Decision: WP-11 reconciles local reminders from one owned, complete 30-day server snapshot; partial UI pages cannot prove removal. Retain at most the nearest 60 local alerts, with explicit account/session ownership and current-state tap resolution.
Context: Existing scheduling is add-only, role/booking identifiers omit account scope, and exit leaves pending/delivered alerts. Multi-page reads can shift during remote changes; a single invoker snapshot avoids that inconsistency.
Consequences: A bounded scalar JSON RPC returns narrow booking facts and a server horizon/as-of under unchanged participant RLS; excessive snapshots fail rather than masquerade as complete. Scheduler retains 60 nearest eligible alerts to leave platform headroom, clears only app-owned obsolete/exit alerts, uses absolute UTC triggers and rejects late account-generation work. Foreground/reconnect refresh and explicit mutations request the same snapshot. Offline remote cancellation cannot withdraw an already scheduled local alert immediately. No timezone-settings or APNs changes.
Linked files: docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md.
```

```text
Decision ID: D-049
Date: 2026-09-08
Decision: WP-10 retains the existing server-owned booking-handoff acknowledgement independently of notification read state, and marks a selected notification read after its current owned destination resolves.
Context: Acknowledgement suppresses a cross-device confirmation handoff, not fulfillment. Existing local-first writes suppress retries after server failure. Customer notifications are inert and Groomer routes rely on partially loaded destinations.
Consequences: Cache only server-confirmed acknowledgement IDs under a versioned account key; ignore unverified legacy local hints and retain server history. Failure remains retryable. Resolve exact request/offer/booking/conversation targets using repository/Store boundaries; missing or inaccessible targets remain explicit without consuming another business action. Exact groomer-match reads preserve the installed pending-refresh masking and participant guard. No notification tap starts, completes or cancels a booking.
Linked files: docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md.
```

```text
Decision ID: D-048
Date: 2026-09-08
Decision: WP-09 uses a bounded SECURITY INVOKER summary RPC under unchanged participant RLS, plus exact participant-pair conversation lookup.
Context: Installed metadata confirms unique participant pairs and a message conversation/time/ID index. Global history reads can exhaust the API cap before quiet conversations appear.
Consequences: At most 100 requested conversation IDs; inaccessible/missing IDs fail together. Each conversation gets one latest message and one latest pair booking using deterministic timestamp/ID order and indexed lateral limits. No high-privilege reader, new persistence or cross-device read receipts. Summary failure stays an error; private avatars and thread history retain existing ownership.
Linked files: docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md; supabase/migrations/20260908234932_t380_bounded_chat_summaries.sql.
```

```text
Decision ID: D-047
Date: 2026-09-08
Decision: WP-08 uses purpose-specific nearest/date/exact repository reads behind existing participant RLS, not unbounded history loading or a new general query framework.
Context: Descending page one cannot prove the next appointment or an empty day; a missing locally cached original request cannot prove deletion.
Consequences: Nearest eligible confirmed booking is ordered by start then ID; date scopes use half-open service overlap and bounded pages with stable tie ordering. Only a completed scope can show confirmed empty; loading/failed/stale reads remain explicit and changing dates invalidates older responses. Republish fetches the exact owned source and still requires new address confirmation. No new persistence/schema/role capability is introduced; backend read changes require actual contract/access evidence.
Linked files: docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md.
```

```text
Decision ID: D-046
Date: 2026-09-08
Decision: Adopt G-07 as time-only bilateral rescheduling under delegated judgment, with one live proposal and no speculative second reservation.
Context: Original WP-07 requires self-overlap exclusion, date-capacity revalidation, expiry and competing-action safety. Existing agreement/admission/timing guards intentionally reject in-place changes.
Consequences: Preserve duration/participants/pet/service/price/address/buffers. Deadline is the earliest of 24 hours, original start and proposed start minus five minutes; latest notice still applies. Expected fulfillment revision binds consent. Acceptance atomically replaces only the original booking's timing/agreement, retaining both snapshots and original request/quote. Failure preserves the old reservation. Unsupported history is not fabricated.
Linked files: docs/03_backend/BOOKING_RESCHEDULING_CONTRACT.md; docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md.
```

```text
Decision ID: D-045
Date: 2026-09-08
Decision: Adopt remaining G-02 and G-06/G-09 for original WP-06 under delegated judgment, using the Booking fulfillment contract rather than a general workflow engine.
Context: Installed completion permits future appointments and cancellation immediately removes occupancy. Actual-time and bilateral outcome evidence are missing. Preserve request-first locking, immutable agreements and receipt recovery.
Consequences: Server-timed Start, early completion retaining buffers, pre-start cancellation, non-releasing unilateral reports, bilateral stop/completion confirmation, elapsed closure without blame, and immutable observations/receipts. Effective release feeds every resource consumer without modifying planned intervals. Unknown actual history stays unknown. No penalties, staffing promise, paid services or account-timezone settings.
Linked files: docs/03_backend/BOOKING_FULFILLMENT_CONTRACT.md; docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md.
```

```text
Decision ID: D-044
Date: 2026-09-08
Decision: Adopt G-03/G-04 for WP-05 under delegated judgment. Pending quotes reserve no capacity. Confirmation expires at the earliest of request/quote expiry and the current earliest-start cutoff; reads and mutations evaluate it without relying on cron. Capacity-only conflicts are retryable while unchanged terms remain valid; withdrawal, request replacement and revoked explicit eligibility are terminal for that quote.
Context: Installed request timing is immutable but other critical terms lack a complete guard. Quotes lack a request revision, booking hydration reads mutable profiles and omits Address Line 2. Existing participant tables are read-only to clients, mutations use controlled RPCs.
Consequences: Keep published request intent immutable and replace open requests through an owned, atomic, idempotent supersession operation using the existing publication contract. Bind quotes to an immutable request revision and give each immutable quote a revision. Acceptance sends the displayed quote revision and preserves original-receipt replay. Persist one complete versioned quote/booking agreement (pet, service, location including unit, timezone, time and price) with source provenance. Unsafe legacy writers require an actionable update; old bookings remain usable but unproven original locations are explicitly unverified, never inferred from today's profile. Reconfirmation requires both participants, not unilateral historical backfill. WP-07 owns later agreement changes. No deployment is implied by this decision.
Boundary clarification: An advance-notice policy change revokes pre-change quotes through the existing eligibility revision, even if changed back; ordinary schedule/time-off capacity changes do not. A visible confirmation also enforces its deadline locally without polling, but an unresolved acceptance remains eligible for read-only outcome recovery after expiry.
Linked files: docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md; ios/Beckon/Beckon/Core/Models/ServiceAgreement.swift.
```


## Archived Decision Index

Full text for the entries below is preserved in `../09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.

| Date | Decision | Current entry point |
|---|---|---|
| 2026-09-10 | Archived decisions D-037 to D-043. | `../09_frozen/decisions/DECISION_LOG_D-037_TO_D-043_2026-09-10.md` |
| 2026-09-08 | Archived decisions D-030 to D-036. | `../09_frozen/decisions/DECISION_LOG_D-030_TO_D-036_2026-09-08.md` |
| 2026-09-07 | Archived decisions D-023 to D-029. | `../09_frozen/decisions/DECISION_LOG_D-023_TO_D-029_2026-09-07.md` |
| 2026-07-12 | Archived decisions D-016 to D-022. | `../09_frozen/decisions/DECISION_LOG_D-016_TO_D-022_2026-07-12.md` |
| 2026-07-09 | Replace the active Markdown 85% cleanup trigger with structural context-budget tooling. | `../09_frozen/decisions/DECISION_LOG_D-015_2026-07-10.md` |
| 2026-07-09 | Superseded by D-016/D-017: treat the active Markdown 85% waterline as a cleanup trigger. | `../09_frozen/decisions/DECISION_LOG_D-014_2026-07-09.md` |
| 2026-07-08 | Treat task-completion commit and push as standing user-authorized Git actions. | `../09_frozen/decisions/DECISION_LOG_D-013_2026-07-09.md` |
| 2026-07-08 | Reduce active Markdown before raising the 32k total budget. | `../09_frozen/decisions/DECISION_LOG_D-012_2026-07-09.md` |
| 2026-07-08 | Keep branch baseline as a single active fact in CURRENT_STATE. | `../09_frozen/decisions/DECISION_LOG_D-011_2026-07-09.md` |
| 2026-07-08 | Track meta-review cadence by completed-task distance, not wall-clock age. | `../09_frozen/decisions/DECISION_LOG_D-010_2026-07-09.md` |
