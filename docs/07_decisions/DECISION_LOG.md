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
Decision ID: D-080
Date: 2026-11-03
Task: T-463
Decision: Adopt compact actor-aligned event-time booking tickets and the approved simple Review sheet. Cancelled headers name the actor; other clear states use direction. Completion supplies a review entry, and no separate automatic text is generated.
Consequences: Reuse message sender IDs, DesignSystem primitives and BookingsStore review authorization/submission/recovery. One nullable message booking_event stores immutable display facts; existing private booking writers populate it, retaining all admission/ownership/receipt logic. Reuse existing counterpart notification triggers for cards. Legacy display normalization requires an exact same-sender card/text pair one microsecond apart; no history deletion. Review uses stars, optional text and text starters, with account/booking-scoped in-memory drafts surviving dismissal/failure. No new repository, cache manager or public writer. Supersedes earlier full-width/centered live-status booking-card presentation and inline pet-fit review input; underlying review evidence data is preserved. Scoped remote deployment was explicitly authorized and completed with transactional rollback acceptance, unchanged message RLS, and no new client event writer.
Linked files: docs/01_product/LIVELY_UI_SPEC.md; docs/03_backend/SUPABASE_CONTRACT.md; ios/Beckon/Beckon/Features/Bookings/BookingReviewSheet.swift; ios/Beckon/Beckon/Core/Models/ChatBookingEvent.swift.
```

```text
Decision ID: D-079
Date: 2026-11-03
Task: T-461
Decision: Chat delivery belongs to the outgoing message, not the Send button. Accept valid text into a local bubble immediately; show per-message sending, failure and explicit same-ID retry. Keep Send circular and available for another draft.
Consequences: Reuse the scoped chat cache and repository boundary. Pending attempts never grant permissions, mark history read or restore booking actions. Restart retains interrupted attempts for explicit retry after membership verification. Stable UUID INSERT plus exact RLS-protected duplicate lookup prevents ACK-loss retries from creating another message; only the id column INSERT grant is added, with no RLS/UPDATE/DELETE changes. The scoped migration was deployed after explicit authorization, with unchanged message RLS and retained server-field/write restrictions verified read-only. Supersedes D-078’s button-owned busy state only.
Linked files: docs/01_product/LIVELY_UI_SPEC.md; docs/03_backend/SUPABASE_CONTRACT.md; ios/Beckon/Beckon/Features/Chat/ChatStore.swift.
```

```text
Decision ID: D-078
Date: 2026-11-03
Task: T-460
Decision: Chat Send remains a fixed circular control in empty, ready and sending states. Ready changes role colors immediately; it does not morph into a pill. Align the visible face center with the input, excluding the reserved bottom ledge.
Consequences: Add the shared roundAction surface with round geometry and pill action colors. Chat opts out of surface-state morphing only; guarded activation, press travel, haptics, busy protection and other controls keep their existing behavior.
Linked files: docs/01_product/LIVELY_UI_SPEC.md; ios/Beckon/Beckon/DesignSystem/BeckonLedge.swift; ios/Beckon/Beckon/Features/Chat/ChatView.swift.
```

```text
Decision ID: D-077
Date: 2026-11-02
Task: T-448
Decision: Chat uses participant profile names, semantic status colors and tap/scroll keyboard dismissal. Service timezone remains authoritative for computation but its technical form rows are hidden. Supersede D-076's after-completion bar reveal: native push ownership plus the transition coordinator translate it vertically under the departing page during the same interactive return.
Consequences: No online-presence inference; keep read-only/error states and message actions. No composer checkmark accessory or duplicate loading surface. User explicitly authorized the bounded counterpart-name RPC deployment and read-only authorization verification. The final RPC uses SECURITY INVOKER to reuse existing conversation/profile RLS, including current-role checks; no test data writes. Preserve local prototypes/signing and let user judge appearance. Validation: 53 chat/offer cases passed (/tmp/Beckon-T448-focused.xcresult); final two native return tests passed on iOS 27.2 (/tmp/Beckon-T448-tabs-final.xcresult), including cancellation, opaque in-flight reveal, nested hidden pages and tab switches. Four migration static checks and live read-only participant/negative-authorization SQL checks passed, 130 migrations aligned and repeat dry-run empty. The user superseded the prior after-completion policy; the first flag-only approach failed return assertions; a transition-coordinated vertical reveal with a transient bottom strip fixes layering. Older iOS 26.5 test-host startup stalled after the toolchain upgrade; interrupted runs are not passing evidence. Final device build/profile/signature validation, install and actual launch passed (/tmp/Beckon-T448-device-build.log, /tmp/Beckon-T448-installed.json, /tmp/Beckon-T448-launch.json). Preflight and context hygiene passed.
Linked files: docs/01_product/LIVELY_UI_SPEC.md; docs/03_backend/SUPABASE_CONTRACT.md; ios/Beckon/Beckon/DesignSystem/BeckonTabBarOwner.swift.
```


```text
Decision ID: D-076
Date: 2026-11-02
Task: T-447
Decision: Offer progress has one button-owned presentation; duration uses the native hours/minutes wheels; tab-bar restoration follows completed navigation rather than viewWillDisappear.
Consequences: Preserve 15–720 minute precision, service defaults and submission validation. Reuse BeckonTabBarOwner for all existing hidden destinations, including cancelled returns, nested pages, inactive tabs and Reduce Motion. Use UIKit setTabBarHidden(_:animated:) after completion. Xcode 27.2 compatibility requires explicit nonisolated declarations for wire decoding and pure Shape values; conversion/validation methods retain MainActor isolation, with no backend contract or artwork change. User-owned local prototype files remain untouched and are excluded from production-only compilation. Acceptance: Xcode 27.2 build-for-testing passed; 64 Swift Testing cases and four native XCTest cases passed in /tmp/Beckon-T447-focused.xcresult, including timer bounds, retained drafts, real UIKit interactive cancellation/completion and the SwiftUI shell. No repeated screenshot review; final appearance is user-reviewed. Device build, profile membership/signature checks, installation and actual process launch on the connected iPhone passed; evidence /tmp/Beckon-T447-device-build.log, /tmp/Beckon-T447-installed.json and /tmp/Beckon-T447-launch.json. Preflight passed.
Linked files: docs/01_product/LIVELY_UI_SPEC.md; ios/Beckon/Beckon/DesignSystem/BeckonTabBarOwner.swift; ios/Beckon/Beckon/Features/Groomer/Requests/GroomerOfferForm.swift.
```


```text
Decision ID: D-075
Date: 2026-11-02
Task: T-446
Decision: Supersede only the color portion of the T-444 clarification in D-073 with one fixed warm mascot palette across all roles.
Consequences: Brown ears #92592F, honey marking #EDBD82, warm dark ink #3A2B25 and peach-rose blush/tongue #F6A29D; white fur and warm-divider paw detail remain. Shared shape, size and animation remain unchanged; BeckonPup code is untouched. Remove the unused old LaunchLockup asset; LaunchWash remains the storyboard asset. User owns visual inspection. Validation: Debug build succeeded; the two requested mascot rendering tests passed (/tmp/Beckon-T446-focused.xcresult); UI audit and all 14 ui-color tests passed. DESIGN_SYSTEM.md contains no old mascot palette names and needs no change.
Linked files: ios/Beckon/Beckon/DesignSystem/DesignTokens.swift; docs/01_product/LIVELY_UI_SPEC.md.
```


```text
Decision ID: D-074
Date: 2026-11-02
Task: T-445
Decision: Adopt handoff 5 as one independent press-feedback package, preserving screen geometry and business activation timing.
Context: The 80 ms-only visual gate suppresses quick-tap feedback. The user answered section 6 before base-action or haptic edits.
Consequences: Medium impact once for ledge/Primary activations, other types quiet; original strength including 40% touch and 70 ms pulse approved. Cards tint but photos retain original colors, so protect shared image/mascot bounds. Base actions become counting PrimitiveButtonStyle wrappers with their APIs and keyboard-tolerant behavior retained; scrolling controls keep the existing guard. Reset cancels work; accepted overlapping taps must not lose feedback. User owns final feel and physical buzz. No handoff 4 prerequisite, prototype edits, navigation hold or new dependency.
Linked files: docs/01_product/LIVELY_UI_SPEC.md; ios/Beckon/Beckon/DesignSystem/BeckonPressMachine.swift; ios/Beckon/Beckon/DesignSystem/BeckonPress.swift.
```

```text
Decision ID: D-073
Date: 2026-11-02
Task: T-443
Decision: Reuse customer account deletion and Home pup emergence on Groomer, preserving the groomer page arrangement and role palette on interface surfaces.
Context: The groomer Account used only a standalone sign-out action, and its Home deliberately disabled the shared pup.
Consequences: Inject the same authenticated Store into shared AccountDangerActions, including existing confirmations, busy/error behavior and cleanup. Both Home cards use one BeckonLoadingHero reveal owner and the unchanged illustration animation; cached content starts at rest. T-444 clarification: the pup is a single brand mascot, with the original customer shape and fixed DesignTokens.Mascot colors across roles and launch, independent of interface accent tokens. Preview auth reuses the existing in-memory adapter. Sign-out button animation changes remain deferred by explicit user request; no backend change or real account deletion is part of acceptance.
Linked files: docs/01_product/LIVELY_UI_SPEC.md; ios/Beckon/Beckon/Features/Groomer/Profile/GroomerAccountView.swift; ios/Beckon/Beckon/DesignSystem/BeckonExpressiveIllustration.swift.
```

```text
Decision ID: D-072
Date: 2026-11-02
Task: T-442
Decision: Adopt the approved retained-launch waiting and Schedule loading-layout studies by modifying production components, without importing prototype fixtures.
Context: Account loading declared launch readiness too early, exposing the Getting things ready page; Schedule inserted its calendar button and omitted its zone/header footprint during loading.
Consequences: Complete the intro once, retain the same scene until the role/onboarding/error route resolves, and delay the lower spinner 0.35 s without an extra minimum hold. Later authentication waits reuse the static final pose. Schedule shares its day-header layout, reserves the real calendar control and summary row, and masks unknown zone sizing text. Existing account calendar, verified booking reads and mutation guards remain authoritative.
Linked files: docs/01_product/LIVELY_UI_SPEC.md; ios/Beckon/BeckonTests/LaunchRoleHandoffTests.swift; ios/Beckon/BeckonTests/ScheduleContinuityTests.swift.
```

```text
Decision ID: D-071
Date: 2026-11-02
Task: T-441
Decision: Finish the launch artwork reaction and word animation before constructing routed pages or application services. Show last known Requests header counts from account-scoped local storage immediately, then refresh them.
Context: Eager service/page construction competes with the intro; reserving badge geometry alone does not display its previously known number and surface.
Consequences: Completion signals, not an added fixed delay, release startup. Keep the same artwork through the welcome handoff and honor Reduce Motion. Cache only two display counts; never infer list readiness, eligibility or mutation permission from them. Preview Stores opt out, obsolete sessions cannot write counts, and account cleanup removes them. T-428 retains full list/detail snapshot scope.
Linked files: ios/Beckon/Beckon/Features/Auth/LaunchScene.swift; ios/Beckon/Beckon/App/BeckonApp.swift; ios/Beckon/Beckon/Core/Infrastructure/GroomerRequestCountCache.swift.
```

```text
Decision ID: D-070
Date: 2026-11-02
Task: T-437
Decision: Preserve confirmed content during background refresh, remove refresh-only rows from summary cards and keep settled content on ordinary tab returns. Keep first entrance and explicit Replay.
Context: User reports counters replaced by Checking, additional refresh lines changing module height, and repeated visible refresh throughout the app. This updates the automatic-return entrance behavior of the adopted handoff while preserving its layout and first entrance.
Consequences: Unknown differs from confirmed empty, transient failure retains previous display, explicit access loss still revokes it. Session-scoped profile reuse and photo-only retry reuse existing Stores/image loading; no new disk cache, remote change, offline write or suppression of business checks. T-428 retains its separate persistence scope.
Linked files: docs/01_product/LIVELY_UI_SPEC.md, docs/superpowers/plans/2026-11-02-refresh-continuity.md.
```

```text
Decision ID: D-069
Date: 2026-11-01
Task: T-430
Decision: Adopt handoff 4 remaining P2-P8 continuously. User explicitly approves D2 removing timing buffers through a new migration and frontend/backend/test-backend updates, retaining overlap, weekly hours, time-off, daily cap and notice guards; remove the inert Auto-ready UI while retaining its compatibility field. D3 supersedes manual history retention in T-423: reset only the outgoing tab's path/deep links, preserve root/Store identity, no generation-based rebuild.
Context: User answered the three questions after requesting all remaining packages. P1 is complete; T-428 remains an independent planned cache change, not a prerequisite for this handoff.
Consequences: P7 owns timing migration and verification, never edits applied history. P2 owns stable navigation reset. D5 extends the bounded chronological nearest-booking read to four rows; the prototype's paused action keeps its Account-root landing. User reiterated that approved handoff UI/UX supersedes old app design rules, including the bounded count-tile scale, while authorization/data guards remain. P8 completes shared adoption and removes its runtime switch; destination-based pushes subscribe to outgoing reset as well as typed paths. D6 follows the accepted prototype stages. D4 may only display pet/visit notes already authorized in immutable booking snapshots. D8 preserves current thread Updating/no skeleton; D10 uses pet owner in user-facing copy.
Linked files: docs/superpowers/plans/2026-11-01-groomer-ui-p2-shell.md.
```

```text
Decision ID: D-068
Date: 2026-11-01
Task: T-429
Decision: Adopt handoff 4 P1 shared foundations: bridged role trait with presentation carrier (handoff D1), dynamic accent/scene tokens, highlight ledge, fixed ledge button room, shared state strip/error card/foot note, stable failed pagination button, equal primary/quiet booking action heights (handoff D9).
Context: User requested P1 only and explicitly requires answers before D2 timing or D3 tab-restart code. Shared primitives must preserve newer T-423 through T-427 plumbing rather than overwrite their prototype twins.
Consequences: Keep UIKit tab bitmap rendering, strict business timezone, launch/cancellation/visibility guards, Store/repository validation, role-specific legacy branches until P8, and thread Updating without skeleton. P1 adds the tab-bar owner but P2 integrates it. Role-aware presentation wrappers preserve onDismiss. No D2/D3 policy change or T-428 implementation; later packages own groomer screen adoption. Visual inspection belongs to the user.
Linked files: docs/superpowers/plans/2026-11-01-groomer-ui-p1-foundations.md; docs/01_product/LIVELY_UI_SPEC.md.
```

```text
Decision ID: D-067
Date: 2026-10-29
Task: T-423
Decision: Customer cross-feature navigation belongs to the destination tab. Home glance selects Grooming's card; successful publication selects the new card after dismissal. Wizard Add pet suspends/resumes its existing draft through Home; ordinary no-pet creation still stays on Home after save. Recovery is a root surface preserving its isolated authentication context. Launch runs once, and loading/entrance clocks only run when visible.
Context: The user adopted the 57-route register's eight problem areas and requested smooth, reusable navigation/startup behavior. T-422 hid startup-time animations and allowed repeated launch gating; programmatic navigation rebuilt the Grooming root and left foreign pages in Home.
Consequences: Existing stores, publication recovery and authorization remain; stable path changes replace root recreation, independent reads overlap, and log I/O leaves the main actor. Existing UI spec owns the reusable standard. No new dependency or backend contract.
T-425 refinement: Keep one visible, noninteractive lockup across launch/welcome; remove it from accessibility after handoff. Use the brandWords spring for a subtle whole-word lift/fade instead of clipping letters. Account resolution uses a delayed role-neutral indicator, leaving Home to own its only skeleton reveal. Authentication, role checks and recovery remain unchanged.
T-426 refinement: Booking Message opens one chat-shaped loading destination, prepares the first thread snapshot before reveal, and reuses the existing Store, header/composer and DesignReveal. Keep the owning Messages tab and participant checks; avoid the intermediate conversation-list skeleton and second first-load spinner.
T-427 supersedes T-426's loading visuals: the user prefers status text beneath the recipient name. Show the chat frame immediately with “Updating…”, remove the thread skeleton/whole-page reveal and central loading panel, and retain T-426's preparation, cache and read-acknowledgement behavior. The Messages list is unchanged.
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


## T-466 — Adopt the approved Groomer Grooming flow

The user approved promotion of the current independently editable Groomer sandbox to production, including the corresponding backend rules. `Features/Groomer/Grooming/` is Tier M; shared row geometry, press surfaces and animated bubble geometry live under `DesignSystem/GroomerVisit/`. Production uses real account-bound Stores/repositories and server-filtered pages. The sandbox remains independent. The six scoped backend migrations are deployed; detailed acceptance evidence belongs to the T-466 plan.

Services enter In service by scheduled time; either participant may mark Finished after start. End-time passage alone does not complete a booking or permit a review. New actions no longer expose interruption/outcome confirmation. Offers remain independent records under one request, withdrawn offers leave Offers, and an overlapping accepted booking closes affected offers permanently. Prebooking first contact requires a valid invitation (groomer) or offer (customer); existing text conversations remain available under existing restrictions. Activity uses immutable backend operation timestamps. Backend changes use six append-only migrations deployed with explicit user authorization, transaction rollback checks and HTTP concurrency/contact verification.

## T-473 — Chat viewport ownership

Chat content uses its own viewport width with bottom native scroll anchors. Horizontal padding belongs inside each message row, not outside the scroll-target layout: the latter produced a 20pt horizontal offset during viewport resizing in the runtime check. This avoids horizontal centering of a lazy stack whose measured content changes during navigation or refresh. Cached entry relies on the initial layout anchor, not a second `onAppear` scroll. The first asynchronous snapshot is positioned without animation; subsequent bottom-following targets the content edge instead of a variable-height message ID. Explicit IDs remain for restoring the reading position when loading earlier history. Reading older messages must not be interrupted by incoming messages. Geometry callbacks update following intent only when the user scrolls and the value changes, avoiding layout-to-state feedback during resizing. The thread alone owns subscription lifecycle; route resolution does not stop the same subscription again.

Keep the existing account-scoped cache, immutable message merging, outbox identity/retry and pagination. Do not add delays, repeated scroll corrections, hidden loading pages, or a second messaging data model to compensate for layout. Apple's [role-specific scroll anchors](https://developer.apple.com/documentation/swiftui/view/defaultscrollanchor(_:for:)) distinguish initial positioning, content alignment and size changes; these are separate from intentional scrolling for a newly sent message. Runtime viewport checks cover cold/cached mixed history, animated route reentry and safe-area resizing; actual phone visual acceptance remains with the user.

Validation evidence: `artifacts/evidence/T-473/chat-tests.log` (11 focused viewport/back/cache/outbox checks) and `viewport-row-insets.log` (final viewport checks after the resize regression was corrected). The resize check uses safe-area changes, not an automated physical keyboard interaction. SwiftUI still emits an `OnScrollGeometryChange` multiple-updates diagnostic during lazy layout; the final measured horizontal origin, viewport width and bottom position pass, so this is not claimed as a warning-free runtime or a substitute for phone visual acceptance.

Release device build, preflight and context hygiene passed; installed on the paired iPhone for user acceptance. Build/install logs are in the same T-473 evidence directory.

## T-474 — Explain rescheduling availability rejections in Toasts

Both roles show the groomer's actual weekly hours for the proposed service dates in the existing bottom Toast when `reschedule_outside_availability` rejects a submission. Cross-midnight intervals show both affected dates; ending exactly at midnight excludes the next date. Disabled days say Closed; known time off overrides regular hours without revealing its private title. These hours explain the schedule, not a guarantee that an individual slot is free.

Only on this rejection, the repository reads the existing booking-scoped snapshot and reuses the owner's availability API or the customer's safe public-profile API. No new endpoint, permission, scheduling rule or backend write. The customer projection exposes only its next public time-off range, so the message must not promise exhaustive availability; other time off and booking conflicts remain server-checked. If explanation reads fail, use the shared fallback: the service is outside the groomer's working hours or overlaps time off; choose another time. Never mention removed buffers or misclassify time off as an overlapping booking.

Do not duplicate the Toast with an inline banner. Groomer proposal errors leave the editor open; the customer's existing confirmation closes on submission and retains the attempted time for reopening after rejection.

Validation: four reschedule logic checks, the current-dialog rendering check and three hours/date/time-off checks passed. The rendering harness now targets the current dialog and disables UIKit transition animation for stable capture. Preflight, hygiene and Release device build passed; the paired-device installer reports success. Evidence: `artifacts/evidence/T-474/`. Actual rejection Toast appearance remains user acceptance; no remote booking was mutated for testing.

## T-475 — Native offer-editor keyboard accessory

The adopted Groomer offer form uses one native `inputAccessoryView` for both UIKit editors, reusing the existing circular Done control (52pt control, 12pt keyboard gap). UIKit attaches it to the keyboard; the page disables its duplicate safe-area Done accessory. The entire otherwise-empty accessory area dismisses editing. Done clears editor focus and resigns the actual input; restricting price selection/edit menus must not reject `resignFirstResponder` through the responder chain. See Apple's [inputAccessoryView contract](https://developer.apple.com/documentation/uikit/uitextfield/inputaccessoryview).

While an offer editor is focused, its page action bar is hidden and consumes no safe-area reservation. It stays hidden while the scene is inactive. Entering the background ends editing without clearing the form; returning starts with a stable page rather than replaying keyboard-frame offsets. Existing keyboard-aware pages keep their default accessory behavior. No offer submission or backend rules change.

Validation: 17 focused checks passed, including native input/accessory/responder checks and an opt-in production-page UI test tapping both Done buttons, the blank accessory area, and background/foreground return. No offer was submitted. Preflight, hygiene and Release device build passed; paired iPhone installation reported success. Evidence: `artifacts/evidence/T-475/keyboard-runtime.log` and sibling build/install logs. Phone visual acceptance remains with the user.


## T-476 — One owner for offer keyboard movement

Make an offer uses native editor/scroll-view keyboard avoidance, without the additional unanimated ScrollViewReader reveal. The hidden footer keeps its layout reservation stable across focus changes. Message collapse follows keyboard dismissal duration instead of running an independent spring; ordinary date/duration expansion remains unchanged. The native Done accessory is transparent (including its UIKit input-view style), retaining the circular button and blank-area dismissal. This supersedes T-475's focus-dependent footer reservation and opaque accessory backing. No offer validation, draft or backend behavior changes.

Validation: six focused checks passed (native accessory/responder, amount precision and production-page keyboard interactions); preflight/hygiene and Release build passed, paired iPhone install reported success. Evidence: `artifacts/evidence/T-476/`. Physical animation/visual acceptance remains with the user; click-path tests alone do not prove perceived smoothness.

## T-477 — Offer form keyboard dock and visible message editor

Supersedes T-475/T-476's native full-width Done accessory: remove the accessory entirely, retaining the price-row keyboard toggle, message-row toggle, outside-input taps and interactive scroll dismissal. A transparent inputAccessoryView still owns a full-width hit region and is not a floating pass-through button.

The request editor opts into a single keyboard-aware bottom safe-area inset instead of the measured spacer plus translated stationary overlay. Its actions remain hidden until keyboardDidHide; inset collapse/restoration follows the keyboard transition. Other footer consumers retain their existing implementation. Reuse the existing measured focus-target visibility calculation after keyboardDidShow, with a short animated reveal only when the field is obscured; do not issue unanimated scroll corrections during the keyboard's changing geometry. Drafts and submission rules are unchanged.

Six focused checks, preflight/hygiene and Release compilation passed; paired iPhone installation reported success. Evidence: `artifacts/evidence/T-477/`. Runtime acceptance checks include message-editor visibility above the keyboard, outside tap/row-toggle dismissal, restored footer position and foreground return. Physical animation quality remains user acceptance.
