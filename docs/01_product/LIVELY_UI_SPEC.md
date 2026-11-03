# Lively UI Spec

**Status: Adopted** by D-063 (T-419, 2026-10-23), extended across the customer app by D-064 (T-420, 2026-10-25). It amends [Design System](DESIGN_SYSTEM.md), [Accessibility Rules](ACCESSIBILITY_RULES.md) and [UI Code Governance](../04_ios/UI_CODE_GOVERNANCE.md) as listed in section 9; everything not amended there is unchanged. Tier C screens keep the existing contract.

Source of truth in code: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift` (`Ledge`, `Motion`, `CornerRadius`, `Metrics`, `Typography.Expressive`) and `BeckonLedge.swift`, `BeckonMotion.swift`, `BeckonExpressiveComponents.swift`, `BeckonJourney.swift`, `BeckonExpressiveIllustration.swift`, plus `SharedFeatures/Notifications/BeckonExpressiveNotificationBell.swift`. Numbers live in code; this document owns the rules. If they disagree, fix one of them in the same change.

Initial adopter: Customer Home (`Features/Customer/Home/CustomerHomeView.swift`) and its request summary card (`Features/Customer/Grooming/GroomingCard.swift`). Preview: `CustomerHomeFlowSandbox.swift`, three Canvas previews (posted, offers waiting, booked).

## 1. Feeling

Lively means the interface behaves like a physical object that answers back, and always says what to do next. It is a feeling to reproduce, not a layout to copy from any other app.

1. **Tactile.** Tappable surfaces have a solid ledge (lip). Pressing sinks the face into the lip, then springs back, with a medium haptic.
2. **Springy.** Things arrive with a small overshoot and settle. Nothing slides linearly into place.
3. **Characterful.** One recurring character (the pup) and a few bounded decorative loops give the screen a pulse. The mascot has one shared shape and fixed brand colors in launch, Customer and Groomer; role themes never recolor its ears, markings, face or paws. Character lives in illustration, never in controls or data.
4. **Guided.** Each module tells the user the next step in one line, and progress is a path with a current step, not a bar.
5. **Earned restraint.** Lively is spent where the user decides or celebrates. Where the user types, pays, reads a thread or works a schedule, the existing calm contract applies.

Test for any new element: does it feel like a thing you can push, and does it help the user know what happens next? If it only decorates, it needs a place in section 6's budget or it does not ship.

## 2. Where it applies (tiers)

| Tier | Screens | Allowed |
|---|---|---|
| **L Lively** | Customer and Groomer Home; empty states; success and celebration moments | Ledge surfaces, entrance pop, bounded idle loops, callouts, stage path; character only at its explicitly adopted locations, never Groomer Home |
| **M Moderate** | Both roles' lists/details, form chrome, account/settings, notifications and dialogs | Ledge surfaces, rounded type, entrance by screen family, explicit action feedback. Input controls remain stable |
| **C Calm** | Text entry and chat-thread content | Stable inputs and thread scrolling; no page entrance for chat |

- Input controls remain calm even inside expressive form chrome. Both roles use the adopted shared kit; `beckonRole` supplies mint or coral, including presented content.
- A screen's tier is recorded in `SCREEN_INVENTORY.md` and, for ledge use, in `LEDGE_TIER_PATHS` in `scripts/ui-consistency-audit-core.mjs`. Undeclared means C. Raising a tier needs a Decision Log entry.
- Handoff 4 (D-069, T-429–T-436) adopts the shared kit throughout both roles. The runtime adoption switch and legacy appearance branches are retired. A DEBUG-only always-true compatibility accessor remains solely for the protected prototype's old call sites; shipping views neither set nor read it.

## 3. Tokens

All values come from `DesignTokens`. A literal elsewhere is drift.

Tokens are defined once in `DesignTokens.swift`: `Ledge` owns lip depth and border width, `CornerRadius` owns surfaces and message bubbles, `Metrics` owns touch targets, fixed media and dialog width, and `Motion` owns press, springs, reduced fades and the three entrance profiles. `ExpressiveTokenTests` checks the adopted values and contrast; do not duplicate the numeric palette here.

Type roles `DesignTokens.Typography.Expressive`: display, hero, section, title, headline, body, supporting, emphasis, label, labelMuted, caption, chip, micro, glyph, glyphLarge. They are SF Rounded through semantic text styles, so Dynamic Type applies. Fixed point sizes are allowed only for decorative glyphs inside the DesignSystem illustration layer and the journey node.

Surfaces are a closed set, `BeckonLedgeSurface`: `card`, `round`, `primary`, `pill`, `dashed`, `highlight`. `highlight` uses the role Tint face and Fill edge/lip for a few important cards, never most of a list. Every ledge button reserves `Ledge.room` beneath its face; its lip and press travel keep the surface's own depth. Shared booking/request primary and quiet actions both use `ledgePrimaryButtonHeight`; the older Primary/Secondary button family retains its existing heights. A screen picks one and never assembles its own face, lip, radius or depth.

## 4. Color

Role meaning is unchanged: mint is Customer action and selection, coral is Groomer, status uses status Text/Fill/Border with symbol and label.

- **Ledge is opaque.** Card ledge `border`, round control ledge `border`, dashed slot `borderSoft`, primary button and pill ledge `customerDeep`, hero ledge `customerFillPressed`. No blur, no glow, no translucent lip. It is a lip, not a shadow.
- **Allowed decorative exceptions, nothing else:** amber `ratingStar` for sparkles and the greeting hand (never state, text or a fine line); coral inside the pup illustration only; the hero's drifting bubbles. All decorative pieces are accessibility-hidden and cannot take touches.
- **Never:** white text on a light role Fill; token `.opacity()` as a fill; Groomer coral for Customer content that is not groomer-owned; gradient buttons; a new hue.

Pairs the kit uses (all asserted in `ExpressiveTokenTests`):

| Foreground on background | Ratio | Use |
|---|---|---|
| Customer Ink on Fill / Hero end / Hero bubble | 6.75 / 7.97 / 8.82 | Hero copy, Review pill, countdown strip |
| Customer Ink on Tint / surface | 10.70 / 12.07 | Chips, bell glyph, primary label |
| Customer Deep on surface / Tint | 6.09 / 5.39 | Current node, scissors glyph, count pill |
| Customer Deep on Fill | 3.40 | Ledge against its face (graphic only) |
| Text primary / secondary / tertiary on page | 13.32 / 6.26 / 4.76 | Hierarchy |
| Tertiary on placeholder | 4.32 | Upcoming node glyph (graphic only) |
| Warning text on warning Fill, success text on success Fill | 5.24, 5.65 | Callouts |
| White on unread dot | 6.57 | Notification count badge (approved by D-063) |

## 5. Components

| Component | Purpose | Tier | Notes |
|---|---|---|---|
| `BeckonLedgeButtonStyle(_:)` | Button style with ledge and press travel | L, M | Takes a `BeckonLedgeSurface`. Haptic after a settled press; travel removed under Reduce Motion |
| `beckonLedge(_:)` | Same surface for non-button content | L, M | Notes, tiles, pills |
| `beckonEntrance(_:)`, `BeckonCascade`, `beckonEntranceClock()` | Synchronized entrance by step/detail/list family | L, M | First active arrival and explicit Replay only; ordinary tab returns stay visible; fade under Reduce Motion |
| `beckonAnimation(_:value:)`, `beckonScrollEase()`, `beckonCarouselTilt()` | Reduce-Motion-aware animation and scroll-linked scale and tilt | L, M | Collapse or switch off under Reduce Motion |
| `BeckonLedgeHeading` | Section title with icon tile and count | L, M | Header trait |
| `BeckonMetaChip`, `BeckonUnreadCountBadge` | Info capsule, unread count | L, M | Not interactive; chips wrap instead of truncating |
| `BeckonLedgePrimaryLabel` | Hero button label with periodic shine | L | Stacks at accessibility sizes |
| `BeckonJourney` | Posted, Offers, Booked path with pulse and callout | L, M | Hidden from VoiceOver; the owning card exposes one combined label |
| `BeckonJourneyCallout` | Bubble over the current step | L, M | Status colors, always icon plus text |
| `BeckonLedgeNote`, `BeckonLedgeAddSlot` | Empty/info note, dashed add slot | L, M | |
| `BeckonDateTile`, `BeckonCountdownStrip` | Booking date tile and countdown strip | L, M | `BeckonBookingCountdown` (Core) computes labels in the booking's time zone |
| `BeckonPortrait` | Pet tile with halo and hop | L | A photo replaces the artwork |
| `BeckonLedgeHero`, `BeckonPup`, `BeckonBubbles`, `BeckonShine`, `BeckonSparkle`, `BeckonWaveHand` | Illustration layer | L only | Pup is the only coral in Customer UI |
| `BeckonExpressiveNotificationBell` | Ledge bell with swing and badge pop | L, M | Groomer keeps `BeckonNotificationBellButton` |
| `DesignPage`, `DesignSection`, `DesignIconDisc`, `DesignValueRow`, `DesignStepPath`, `DesignActionBar` | Shared page/chrome composition | L, M | Inputs and business actions stay feature/Store-owned |
| `DesignDialog`, `DesignSnackbar`, `FeedbackTimingPolicy` | Decisions, choices, Undo and readable expiry | M | One shared presenter and timing policy; no duplicated screen timers |

## 6. Motion

- Springs come from `DesignTokens.Motion`; a motion primitive in a Feature file is a UI015 error.
- Entrance families: step (wizard/pet form, 45 ms per beat), detail (85 ms), list/tab (55 ms). `beckonEntranceActive` and onscreen state jointly gate replay; all six wizard steps share the step rhythm. Programmatic tab changes use one plain-cut shell function. Chat threads and system photo sheets have no entrance.
- Idle budget: at most one idle loop per component and three distinct loops in view. Tier M and C have none. Loops redraw at 30 fps and stop under Reduce Motion and when the scene is not active.
- Haptic: medium impact after an 80 ms settled press; scrolling cancels press feedback and accidental release taps. Decoration never intercepts touches. Quiet disabled actions use 0.4 opacity.
- Motion never carries meaning alone (A11Y-R9). Stage, status and unread state always have a glyph and text.

| Motion | Reduce Motion |
|---|---|
| Step/detail/list entrance | Fade 0.15 s |
| Press travel | None; haptic kept |
| Pulse, hop, bobbing, shine, bubbles, wave, bounce | Static |
| Scroll ease and tilt | Off |
| Stage and state springs | Ease-out 0.15 s |

## 7. Voice

One short line that names the next step ("Groomers are looking at your request"). At most one exclamation mark per visible module. Sentence case. SF Symbols, no emoji. No jokes in errors or destructive flows.

## 8. Accessibility on top of A11Y-R1..R10

- AX3: stack with `isAccessibilitySize` (`AnyLayout`). A `dynamicTypeSize` cap is allowed only on glyph-like labels whose full text is in the owning element's combined VoiceOver label (journey labels, callouts, heading icon, bell glyph). Never on body or title text in Tier M or C.
- Decorative layers: accessibility-hidden and not hit-testable.
- Cards read as one element with a model-derived label; secondary pills are not separate stops.
- Evidence per slice: AX3 screenshots, a Reduce Motion pass, VoiceOver walkthrough, `ExpressiveTokenTests`.

## 9. What D-063 amended

| Previous rule | Amendment |
|---|---|
| Design System: no decorative animation outside the brand illustration | Allowed in Tier L within section 6, only through the DesignSystem illustration layer |
| Design System: one quiet card shadow, depth from borders | Ledge is the depth language for tappable surfaces in Tier L and M. Tier C keeps `softCard`. No blur or colored shadow either way |
| UI-R2, UI001, UI002: semantic typography only | `Typography.Expressive` rounded roles added; fixed sizes only for decorative glyphs |
| UI-R6: one elevation tier | Two: quiet (Tier C) and ledge (Tier L/M), never both on one surface |
| Avoid nested cards | A tile inside a card uses border only, no ledge |
| Approved pairs | White on unread dot added |
| A11Y-R1 | Section 8 caps permitted |

UI-R3, role color meaning, status rules, touch targets and the Groomer contract are unchanged.

## 10. Drift guards

1. **One source in code.** `DesignTokens`, the closed `BeckonLedgeSurface`, `Typography.Expressive`. Adding a surface, type role, spring or decorative loop is a spec change plus a Decision Log entry.
2. **Executable contrast and tokens.** `ExpressiveTokenTests` fails if any declared pair drops below its floor, white lands on a light Fill, or a ledge, radius or motion token drifts.
3. **Source audit.** UI015 motion primitives in Features, UI016 Feature-local rounded type, UI017 ledge surfaces outside the Tier L/M allowlist. The existing authentication artwork entrance retains its bounded exception; the obsolete discovery deck exception is removed.
4. **Tier declaration** in `SCREEN_INVENTORY.md` and `LEDGE_TIER_PATHS`.
5. **Review checklist.** For any change touching Lively UI: Is the screen Tier L or M? Only kit surfaces and type roles? Only token springs? Any new color pair added to `ExpressiveTokenTests`? Decorative pieces hidden and untouchable? Reduce Motion table honored? AX3 screenshot attached? At most one exclamation per module?

## 11. Extending to another screen

1. Decision Log entry naming the screen and its tier.
2. Record the tier in `SCREEN_INVENTORY.md` and add the file to `LEDGE_TIER_PATHS`.
3. Compose existing `Beckon*` expressive pieces; a missing piece enters `DesignSystem/` and the tokens first.
4. Validate per the [Development Guide](../05_workflow/DEVELOPMENT_GUIDE.md): full `./scripts/ios-test.sh`, preflight, and the section 8 evidence.

## 12. Feedback and acceptance

- Toast: no action. The feedback center owns timing, queue/deduplication and announcement consumption; the overlay has no second error cache or expiry timer.
- Snackbar: one expiring Undo/Retry action, owned by the page. Favorite Undo uses `setFavorite`; leaving the page dismisses it. Pet removal uses confirmation because no restore operation exists.
- Alert dialog: one decision, no Close or scrim dismissal. Modal: small choice/explanation or validated note/time entry, with Close and scrim dismissal. Text scrolls at accessibility sizes while actions stay reachable.
- Reading time is `1.5 + 0.35 × wordCount` seconds. Notice floors/caps at 4/8; error adds 1 and clamps to 5/9; snackbar adds 2 and clamps to 6/10. Production error copy and actionable persistent recovery remain intact.
- The customer sandbox now hosts real views with existing local mock repositories. Prototype files are a frozen reference; no release route or real service is introduced by the host.
- T-420's plan records integrated runtime, Dynamic Type, VoiceOver semantics, Reduce Motion and keyboard evidence. Simulator is the adopted target; hardware haptics and dark mode are outside it. Strings remain English only.

## Handoff 2 motion and module update (D-065)

`BeckonPeekCarousel` shows whole cards plus a 44pt peek and fractional dots; neighboring cards stay straight. `BeckonJourney` supports four stops and its live bubble. `BeckonWhen` formats in a known service zone and does not substitute the device zone. `BeckonTabIcons` owns the four template icons. `BeckonTickCircle` draws selection and `BeckonLedge` morphs the selected surface. `DesignSheetBar` and `BeckonPinnedBar` own sheet chrome and pinned actions.

Customer lists and detail pages retain their entrance family; wizard steps share directional travel. Selection mode shifts the same cards, without inserting extra content inside each card. Portfolio covers fade/scale, with horizontal-only drag and explicit Previous/Next accessibility actions. Idle loops stop when inactive or Reduce Motion is on; delayed landing effects are owned by view tasks. Decorative portfolio-placeholder and selection glyph sizes are tokenized; they carry no text meaning and their labels live on the enclosing control.

## Loading and Home adoption (D-066)

The S-103 handoff adds `DesignSkeleton` / `DesignReveal`, `BeckonHomeScene`, `BeckonLockup` and `LaunchGate`. Home, Grooming/detail, customer Messages and Account reserve their first-response layout with bars. Page titles, notification bell and tabs stay real. Body actions wait with the data; no-pet request actions then open the shared Add pet / Not now dialog. Grooming selects Home before presenting its existing pet editor; saving stays on Home.

Stores own first-answer completion, including actual failure. Cancelled or invalidated reads do not settle; cached content can render immediately. Placeholder delay is 0.15 s, visible minimum 0.45 s and in-place reveal 0.32 s. Refresh/load-more retains content. One screen-aligned shimmer pauses when hidden, inactive or Reduce Motion is enabled; bars expose one region label and no controls. Launch and account-resolution timing follow D-067 below; the system storyboard uses the shared wash, and SwiftUI owns the animated lockup.

Home uses the approved 46 pt scaled greeting, no wave/subtitle, a 54 pt pup band and mint sky/clouds/mountain/lawn scene. Decorative clouds run at 12 fps only on the active visible tab. Pulling pins the title/bell and clouds while the card, mountains and lawn move together; upward scrolling uses the adopted depth factors. A 72 pt release triggers the existing Home reload once, with a light threshold haptic and minimum 1 s in-flight time, without a spinner. Pending pet recovery sits below the hero. Empty pets use the same carousel's dashed Add pet tile.

Grooming, Messages and Account use a 52 pt minimum title row, 24 pt top inset and 24 pt section gap. The two customer empty cards have no pup. Shared title/component changes are authorized across roles; groomer business pages and role-specific actions/empty states retain their existing ownership. See [T-422 evidence](../superpowers/plans/2026-10-29-loading-home-flow-adoption.md) for adoption checks and limits.

## Navigation and visible motion (D-067)

`CustomerNavigation` is the customer shell's route owner. Home Next up selects the corresponding Grooming carousel card; explicit details, notification targets and appointment reminders open the owning tab's destination. Manual tab selection preserves independent history. Action-driven handoffs clear the source and destination paths in one transaction, without `.id`-rebuilding tab roots or their Stores. Local Account editors respond to the same handoff generation. Use lightweight destination values and `CustomerNavigationLink`; standalone previews retain their existing destination fallback.

A completed publication closes its wizard, then selects the new Grooming card. A failed/partial send retains existing retry/recovery behavior. Adding a pet from the wizard suspends its draft and time choices, dismisses the wizard, opens Home's existing editor, and resumes only from the editor's dismissal callback; saving selects the new pet, cancelling keeps the previous selection. Ordinary no-pet entry still saves on Home. Never use a fixed delay to sequence these presentations. Notification/reminder routes keep repository participant checks and account/role scoping. Password recovery is an isolated root surface while the prior session is preserved, never a cover stacked over its business pages.

One visual transition owns each handoff: a native push within a feature, an immediate tab selection for a cross-feature action, or the existing sheet dismissal before the destination is selected. Avoid overlapping whole-page rebuilds, custom travel and native navigation. Destination builders are lazy; independent initial reads may run concurrently behind existing Store cancellation/revision guards. Main-thread rendering and button actions do not read/trim log files; existing sanitized logs use a serial utility queue with the same retention bounds.

Booking Message entry uses the Messages-owned thread destination. Show its real header and disabled composer immediately while resolving; the status beneath the recipient name reads “Updating…”. This thread entry has no skeleton, shimmer, minimum placeholder hold or whole-page loading reveal. Resolve the authorized conversation and prepare its first message snapshot, subscribing before reading; the visible thread adopts this work without fetching the same initial snapshot again. Preparation does not acknowledge unread messages until the thread appears. Subsequent thread updates use that same header status while retaining cached messages, including an empty chat. The body has no central loading panel; show the empty state only after a successful empty snapshot. Cancellation/backgrounding stops subscriptions; returning to the foreground refreshes normally. Failure retains a truthful header status, Retry and the return route. The Messages list retains its separate list-loading presentation.

A newly mounted tab applies its stored deep-link path after the native stack's first layout turn, with cancellation checks and no fixed delay. Keep heterogeneous route construction behind `CustomerRouteDestination`; type erasure is confined to that boundary, not list rows. Reuse wire-date parsers safely across threads, and render cached tab artwork directly from its paths rather than re-entering SwiftUI layout through `ImageRenderer` inside a tab update.

The launch animation owns the brand entrance once per app opening. The name and tagline fade in with an 8 pt lift, 0.98-to-1 scale and the gentle `brandWords` spring; no clipping mask cuts through letters. Reduce Motion removes the lift/scale. The system launch storyboard matches its first frame's background, without displaying a completed wordmark that would disappear when the intro begins. Launch and the signed-out landing reuse `AuthenticationLanding` geometry, reserving its hidden action area instead of estimating its height, so the wordmark does not double during the fade. Its dismissal reads current readiness and completed animation state; asynchronous completion closures must not capture an early readiness verdict. Account/role resolution retains the finished launch artwork, with a quiet lower-screen progress indicator after 0.35 s of waiting. It has no minimum hold and goes directly to the authoritative role destination; no “Getting things ready” page is mounted. Later sign-in/retry waits reuse the final artwork pose without replaying its entrance. Only resolved role, onboarding or actionable failure releases cold launch. Home alone owns its skeleton-to-content reveal; fast/cached reads skip unnecessary placeholders. Profile failure/retry and onboarding retain their existing routing. Child visibility is combined with ancestor visibility, and skeleton/reveal clocks wait until their region is visible. Cached data need not invent a loading animation. Reduce Motion, errors and recovery remain available.

These conventions follow [Apple's motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion) and [responsiveness guidance](https://developer.apple.com/documentation/xcode/improving-app-responsiveness). Verify changed routes in the existing isolated Simulator host, plus cancellation, repeated activation, modal completion and account boundaries; source review or scheduling-gap measurements alone are not a frame-rate guarantee.

The same lockup instance stays visible from launch into the signed-out welcome page; only its backdrop leaves. This preserves the pup's reaction and idle timeline instead of cross-fading two different poses. The real welcome page owns buttons and scrolling; its hidden lockup reserves geometry and brand semantics, and a lightweight preference forwards press/scroll state to the decoration. The decoration never receives hits, its reserved action layout is hidden from accessibility, and the whole decoration leaves the accessibility tree after handoff so it cannot obstruct the real controls. Returning from the form does not replay the arrival. For destinations without the welcome brand, composite the outgoing launch scene before fading it to avoid pale artwork. Visibility/foreground changes do not replay the arrival; explicit button-press reactions remain independent.


## Handoff 4 foundations (D-068, P1)

`BeckonRole` bridges the SwiftUI environment to a UIKit trait. Customer remains the default mint palette; the groomer role resolves the accent, hero, scene and skeleton tokens to coral/peach. Presentations use `beckonSheet`/`beckonCover`, preserving their original bindings and onDismiss handlers. Their shared carrier writes the role on presented hosting controllers, and DesignDialog uses that carrier too. UI018 rejects native sheets/covers/popovers outside these two presenters, including shared components. The groomer shell selects its role in P2. Coral Deep on Fill is a decorative lip (2.90:1), not a semantic glyph/text pair; use Ink on Fill or Deep on white for meaningful content.

`BeckonStateStrip` is the shared symbol/title/optional-reference band (accent, neutral, success, warning, error). At accessibility sizes its reference stacks. Grooming needs cards and errors use it now; booking chat cards adopt it in P5. `BeckonErrorBanner` is a white ledge card with red confined to its strip and the original retry action below. A failed Load more remains the same button, says “Couldn't load more · Try again”, and keeps its footprint in normal/loading/failed states; full page failures retain the error card. Action errors remain feature-owned and must not be relabelled as pagination failures.

`BeckonFootNote` carries one warm attention or neutral waiting note along a card foot, wrapping at accessibility sizes. `BeckonLedgeHeading` accepts trailing detail; `BeckonDateTile` supports a muted date; `BeckonLedgeHero(showsPup: false)` draws no pup. `BeckonWhen.day` and `.start` split the existing short form without substituting a device timezone. Journey primitives add groomer request/service paths and status/attention/waiting bubbles; role screens bind them in later packages. Requests and Schedule icons join the existing template family, retaining UIKit bitmap rendering. `BeckonTabBarOwner` is available for P2 integration; it does not reset navigation.

Customer-visible P1 effects: the shared error card, pagination retry in Notifications/Offers, constant button room (pill +3pt, card +1pt, round +2pt), quiet booking/request actions growing from 44pt to 58pt before ledge room, and the shared strip in Grooming needs cards. Launch, chat loading, timing buffers and manual tab history are unchanged. Visual confirmation is user-owned; geometry, role resolution, presented-controller traits and contrast have executable checks.


## Handoff 4 shell and Home (D-069, P2)

Groomer Home is Tier L and Notifications Tier M, with coral role selected once on the groomer shell. Shared HomeHeader retains the production greeting and accepts the bell identifier. Both Home hero cards reuse BeckonLoadingHero and the existing pup illustration: hidden during the first wait, emerging only after the content reveal, with the same stretch, ears, paws and card dip. Cached content starts at rest; ordinary refresh/tab return does not replay the emergence. Groomer Home shows up to three confirmed forthcoming bookings after the nearest appointment (sorted by start), and shows availability only when requests are paused or weekly hours are missing. Paused opens Account, as the prototype's Open Account action specifies; missing hours opens Availability. Load issues follow handoff item 13: inline error cards, not competing load-error toasts. The Home count tile alone uses the approved homeCountMinimumScale token; this does not permit shrinking body or form text. Notifications retain production destination/participant checks and show source-specific pagination retry.

Manual selection pops only the outgoing tab to its root and clears its pending detail links, preserving root and Store identity. Programmatic cross-tab handoffs use the same plain cut, retain the incoming target and never apply a generation id. This supersedes D-067 manual history retention; it does not implement T-428 cache changes. The tab owns its bar through BeckonTabBarOwner and pages request hiding via beckonHidesTabBar.


## Handoff 4 requests (D-069, P3)

Groomer Requests is Tier M: Matches holds unanswered requests; Offers groups Needs attention, Pending, Booked and collapsed Earlier. One row and one request detail follow new → offered → booked/closed, retaining the backend's raw records for notifications/history. The row stacks at accessibility sizes, preserves the invited highlight/new mark and shares the detail's stage. The request's deadline is evaluated from the clock, including stale raw-open records: exactly at expiresAt the request closes, cannot be answered and says Expired. Accepted offers retain booking history.

The merged page uses the existing offer form state, session validation, participant/eligibility checks, assessment confirmations, service wall time and operation recovery. Full reads, pagination and actions have independent error channels: page cards/counts use read errors, Load more its page error, and toasts action failures. A read failure cannot become a submit toast, nor an invalid quote a pagination error. Old offer-detail/view-request ids and pagination-error-box ids are retired; withdrawal confirms then remains on the same request with its activity record.

## Refresh continuity (D-070, T-437)

Background reads preserve confirmed data and confirmed empty results. Loading state must not clear counters, remove known count badges, swap an empty result for a first-load placeholder, or insert a status line into a summary card. Groomer Home's tiles contain their count and title only; the appointment card adds no refresh-status row. First unavailable values remain unknown, never invented zero. Existing read errors/retry and explicit access loss remain meaningful states.

Saved groomers adds no refresh-only spinner row once its list is known. Fit signals and portfolio fit notes retain their loaded editors without inserting loading rows; their existing write controls remain disabled while verification is pending. Evidence readiness follows its own successful read, including an empty result, independently of fit claims.

Entrances run on first activation or explicit Preview Replay. A normal tab return keeps settled content and its layout visible, with decorative background work still paused while inactive. Manual pull refresh retains its existing feedback; chat retains its existing recipient subtitle status. Freshness checks, real-time fallback, business deadlines and write authorization are unchanged. These are presentation rules, not authorization or cross-restart cache guarantees.

Skeleton parity (T-438): reuse the loaded component's layout where possible, including its surface, padding, font line boxes and Dynamic Type reflow. Keep known static text in the sizing layout and overlay placeholders; do not assume applying system redaction to a whole component preserves wrapping. A skeleton line is always one line. Shortcut labels/descriptions, Home counts, Schedule dates, request paths and large-type row arrangements follow their real owners. Unknown data length, stage and collection size cannot be predicted; retain natural loaded content instead of clipping it to a placeholder.

Schedule title always reserves its real calendar button; it is disabled until the account calendar is known. Loaded and placeholder day headers share native date/Today/zone/summary layout and Dynamic Type reflow, reserving the summary row on an empty day. A known account zone remains visible while bookings load; an unknown zone is masked, never replaced by a visible device zone or hard-coded PST. The hour-strip placeholder uses the loaded strip’s height and hour-label line boxes.

Schedule uses one gated page refresh plus scoped range reads. Pending same-week reads retain the calendar, hours, appointment rows, day summary and occupancy bars without adding a loading row. First/new-scope reads use placeholders and never announce an unread day as empty. Transient metadata failures retain the display with verification feedback; explicit access loss revokes it. Automatic concurrent/recent same-scope reads coalesce; manual refresh and stale write invalidation still read, and cancellations cannot become spurious verification failures.

Groomer Account reuses the customer AccountDangerActions through the authenticated session Store, including both deletion confirmations, busy protection, failure copy and successful local cleanup/sign-out. Keep the groomer sign-out accessibility identifier. Profile read failure does not block account deletion; auth failure stays visible. Both roles retain the existing sign-out button animation; its revision is deferred by the user. Preview auth remains in memory and never deletes a real account.
