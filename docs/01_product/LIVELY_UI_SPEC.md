# Lively UI Spec

**Status: Adopted** by D-063 (T-419, 2026-10-23), extended across the customer app by D-064 (T-420, 2026-10-25). It amends [Design System](DESIGN_SYSTEM.md), [Accessibility Rules](ACCESSIBILITY_RULES.md) and [UI Code Governance](../04_ios/UI_CODE_GOVERNANCE.md) as listed in section 9; everything not amended there is unchanged. Tier C screens keep the existing contract.

Source of truth in code: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift` (`Ledge`, `Motion`, `CornerRadius`, `Metrics`, `Typography.Expressive`) and `BeckonLedge.swift`, `BeckonMotion.swift`, `BeckonExpressiveComponents.swift`, `BeckonJourney.swift`, `BeckonExpressiveIllustration.swift`, plus `SharedFeatures/Notifications/BeckonExpressiveNotificationBell.swift`. Numbers live in code; this document owns the rules. If they disagree, fix one of them in the same change.

Initial adopter: Customer Home (`Features/Customer/Home/CustomerHomeView.swift`) and its request summary card (`Features/Customer/Grooming/GroomingCard.swift`). Preview: `CustomerHomeFlowSandbox.swift`, three Canvas previews (posted, offers waiting, booked).

## 1. Feeling

Lively means the interface behaves like a physical object that answers back, and always says what to do next. It is a feeling to reproduce, not a layout to copy from any other app.

1. **Tactile.** Tappable surfaces have a solid ledge (lip). Pressing sinks the face into the lip, then springs back, with a medium haptic.
2. **Springy.** Things arrive with a small overshoot and settle. Nothing slides linearly into place.
3. **Characterful.** One recurring character (the pup) and a few bounded decorative loops give the screen a pulse. Character lives in illustration, never in controls or data.
4. **Guided.** Each module tells the user the next step in one line, and progress is a path with a current step, not a bar.
5. **Earned restraint.** Lively is spent where the user decides or celebrates. Where the user types, pays, reads a thread or works a schedule, the existing calm contract applies.

Test for any new element: does it feel like a thing you can push, and does it help the user know what happens next? If it only decorates, it needs a place in section 6's budget or it does not ship.

## 2. Where it applies (tiers)

| Tier | Screens | Allowed |
|---|---|---|
| **L Lively** | Customer Home; empty states; success and celebration moments | Ledge surfaces, entrance pop, bounded idle loops, character, callouts, stage path |
| **M Moderate** | Customer lists/details, form chrome, account/settings, notifications and dialogs | Ledge surfaces, rounded type, entrance by screen family, explicit action feedback. Input controls remain stable |
| **C Calm** | Text entry, chat-thread content and Groomer workspaces | Stable inputs and thread scrolling; no page entrance for chat. Groomer layout stays unchanged except approved shared account actions and booking dialogs |

- Input controls remain calm even inside expressive form chrome. A shared file may contain customer and groomer presentation; `beckonCustomerDesign` scopes the adoption.
- A screen's tier is recorded in `SCREEN_INVENTORY.md` and, for ledge use, in `LEDGE_TIER_PATHS` in `scripts/ui-consistency-audit-core.mjs`. Undeclared means C. Raising a tier needs a Decision Log entry.
- Groomer color and Groomer-owned surfaces stay schedule/action oriented; Lively is a Customer-side expression.

## 3. Tokens

All values come from `DesignTokens`. A literal elsewhere is drift.

Tokens are defined once in `DesignTokens.swift`: `Ledge` owns lip depth and border width, `CornerRadius` owns surfaces and message bubbles, `Metrics` owns touch targets, fixed media and dialog width, and `Motion` owns press, springs, reduced fades and the three entrance profiles. `ExpressiveTokenTests` checks the adopted values and contrast; do not duplicate the numeric palette here.

Type roles `DesignTokens.Typography.Expressive`: display, hero, section, title, headline, body, supporting, emphasis, label, labelMuted, caption, chip, micro, glyph, glyphLarge. They are SF Rounded through semantic text styles, so Dynamic Type applies. Fixed point sizes are allowed only for decorative glyphs inside the DesignSystem illustration layer and the journey node.

Surfaces are a closed set, `BeckonLedgeSurface`: `card`, `round`, `primary`, `pill`, `dashed`. A screen picks one and never assembles its own face, lip, radius or depth.

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
| `beckonEntrance(_:)`, `BeckonCascade`, `beckonEntranceClock()` | Synchronized entrance by step/detail/list family | L, M | Replay on active tab arrival; fade under Reduce Motion |
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

Stores own first-answer completion, including actual failure. Cancelled or invalidated reads do not settle; cached content can render immediately. Placeholder delay is 0.15 s, visible minimum 0.45 s and in-place reveal 0.32 s. Refresh/load-more retains content. One screen-aligned shimmer pauses when hidden, inactive or Reduce Motion is enabled; bars expose one region label and no controls. One launch overlay spans bootstrap/session/profile resolution, with a 0.7 s minimum and actionable failures counted as ready. The system launch artwork is exported from the same SwiftUI lockup into the launch storyboard; no second brand drawing.

Home uses the approved 46 pt scaled greeting, no wave/subtitle, a 54 pt pup band and mint sky/clouds/mountain/lawn scene. Decorative clouds run at 12 fps only on the active visible tab. Pulling pins the title/bell and clouds while the card, mountains and lawn move together; upward scrolling uses the adopted depth factors. A 72 pt release triggers the existing Home reload once, with a light threshold haptic and minimum 1 s in-flight time, without a spinner. Pending pet recovery sits below the hero. Empty pets use the same carousel's dashed Add pet tile.

Grooming, Messages and Account use a 52 pt minimum title row, 24 pt top inset and 24 pt section gap. The two customer empty cards have no pup. Shared title/component changes are authorized across roles; groomer business pages and role-specific actions/empty states retain their existing ownership. See [T-422 evidence](../superpowers/plans/2026-10-29-loading-home-flow-adoption.md) for adoption checks and limits.
