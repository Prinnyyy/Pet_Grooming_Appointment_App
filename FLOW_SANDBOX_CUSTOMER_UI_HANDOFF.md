# Flow Sandbox: Customer UI/UX handoff (Claude and Codex)

Shared handoff between Claude (design) and Codex (implementation). Originally a local draft; retained here as the delivery record for the user-authorized T-420 production adoption. Historical instructions below remain labelled by date; current results and boundaries are at the start of section 5.

**Status:** `DONE`
Codex changes this to `IN_PROGRESS`, then `DONE` (or `BLOCKED` with the reason in section 6). Claude is paused until the user says Codex is done and Claude has read section 5.

**Current architecture, approved adoption 2026-10-25:** Customer UI is adopted into production. Active Preview hosts open real `Features/` Views with isolated fixtures/Stores/session for acceptance. Independent UI snapshots in `FlowSandbox/Prototype/` remain unchanged and local for future design work; editing real Views affects the App. This supersedes the 2026-10-23 host arrangement; see the start of section 5.

## 1. The user's rules (apply to both agents)

1. Every UI/UX change is designed in the Flow Sandbox first. The user reviews it there. Only after the user approves does anyone apply it to the real app.
2. Sandbox work does not edit real Views' visuals, `DesignSystem/`, `DesignTokens`, canonical design docs (`docs/01_product/*`, `docs/04_ios/UI_CODE_GOVERNANCE.md`), the UI audit rules, or the Decision Log, unless the user explicitly says so for that change.
3. A design document the user asks for during sandbox work is about the sandbox prototype only, not an edit to the real design contract.
4. Follow `docs/05_workflow/SWIFTUI_FLOW_SANDBOX_WORKFLOW.md` (isolation, acceptance, delivery). No commit, push, branch or blanket stage unless the user asks.

## 2. Current repo facts

- Branch `main`, working tree dirty. It mixes Codex's uncommitted T-418 work with Claude's T-419, which the user allowed once ("this time only"). T-419 is not a precedent and must not be extended to other screens.
- T-419 changed the real app: Customer Home, the Home request summary card and the Customer notification bell now use the Lively style (new `DesignSystem/Beckon*` kit, new `DesignTokens` groups, D-063). It also removed the Playful hooks (`CustomerHomeMotionSandbox.swift` deleted), added audit rules UI015-UI017, amended real design docs and added `docs/01_product/LIVELY_UI_SPEC.md`. Treat Home as it is in the working tree now. Pre-T-418 production source is `git show HEAD:<path>`; Claude's pre-T-419 backups of the dirty files are in the Claude session scratchpad (`.../scratchpad/backup-pre-T419`).
- `CustomerHomeFlowSandbox.swift` now previews the production Home with a Posted / Offers / Booked switch (`CustomerHomePreviewRequestRepository.setPreviewStatus`). Known limits: the offers stage has no loaded offer list, so the callout reads "Offers ready!"; `accessibilityReduceMotion` cannot be injected through the SwiftUI environment.
- Evidence at handoff: full suite 848 passed / 46 skipped, one known timing flake (`BeckonFeedbackCenterTests`, passes isolated); `node scripts/ui-consistency-audit.mjs check` green; Release build green.

## 3. Task for Codex

**Goal:** make the real app's entire Customer-side UI/UX available in the Flow Sandbox, so every Customer screen, flow and state can be opened in Canvas on isolated fixtures, using the real Views, Stores and navigation. Then stop. Claude will design Customer UI on top of it afterwards.

**Scope (all Customer-facing, with today's source):**

| Area | Screens |
|---|---|
| Entry (customer path) | `Features/Auth/`: landing, sign in, sign up, password recovery, role onboarding, authenticated account |
| Home | `Features/Customer/Pets/CustomerPetsView.swift` (already in `CustomerHomeFlowSandbox`) |
| Notifications | `Features/Customer/Notifications/CustomerNotificationsView.swift` |
| Pets | pet form and editor, pending-creation recovery (`CustomerPetFormView.swift`; `CustomerPetsFlowSandbox`) |
| Requests | tab and dashboard, request wizard (all steps), request detail, offers review, request progress, publication and photo-retry states |
| Groomer discovery | discovery deck, list, groomer detail, candidate actions, favorites |
| Bookings | list, booking detail, fulfillment, reschedule, review, reminder destination |
| Messages | conversation list, chat thread |
| Account | account, profile settings |
| Cross-cutting | tab bar, global feedback toasts and banners, loading, empty and error states |

**Deliverables:**

1. A single Preview that hosts the real `CustomerTabView` (all five tabs live) on in-memory fixtures.
2. A screen index Preview listing every screen and state with a way to open each (its own `#Preview` or an in-sandbox jump).
3. State fixtures per screen where they change the layout: loaded, empty, loading, error; request statuses open / has offers / booked / cancelled / expired; booking statuses; unread and none; long names; with and without photos; Dynamic Type is left to Canvas.
4. Isolation: nothing reaches Supabase, Auth, push registration, Keychain, shared defaults, photos storage, address lookup, reminders, realtime or chat subscriptions. Reuse the existing sandbox session, preview repositories and memory-only defaults first; add only what is missing.
5. Section 5 filled in (coverage matrix, isolation table, entry points, how Claude plugs in).
6. A stub `ios/Beckon/Beckon/FlowSandbox/Design/CustomerDesignVariants.swift` (see section 4), owned by Claude from then on.

**Constraints:**

- No visual or behavioral change to production screens. A DEBUG-only injection seam in a production View is allowed only as the Sandbox Workflow's Escalation section allows; list each one in section 5.
- Prefer a new folder outside `Features/` for new sandbox-only code (for example `ios/Beckon/Beckon/FlowSandbox/Customer/`) and keep `node scripts/ui-consistency-audit.mjs check` green with no new baseline entries.
- Keep Xcode writers serial. Run focused tests for new isolation or state logic only; no full regression unless a production-affecting seam requires it.
- **Stop condition:** when deliverables 1-6 are done, set Status to `DONE`, write the summary in section 5, tell the user, and stop. Do not redesign anything, do not adopt anything, do not commit.

## 4. Collaboration protocol

- **Ownership.** Host, fixtures and preview repositories remain infrastructure. UI design work edits `FlowSandbox/Prototype/**` (the independent page/component/style copies) or existing experiments in `FlowSandbox/Design/**`. Do not edit live `Features/`, `DesignSystem/`, shared Stores or assets for sandbox design. Preserve the other agent's existing edits; infrastructure requests go in section 6.
- **Plug-in point.** The host reads `CustomerDesignVariants` (stub created by Codex, filled by Claude) to offer an Original / Variant toggle per screen, so Claude can render a redesigned screen next to the real one without touching Codex's files. Codex defines the screen identifiers and the host API; section 5 documents them.
- **What Claude needs back** in section 5: entry-point type names, how to open a given screen in a given state, how to reset, how a variant is registered, and the exact list of fixtures and their stable IDs.
- **What Claude will do after the pause:** design Customer screens as variants in `FlowSandbox/Design/`, one screen at a time, for the user to review in Canvas. Claude writes a design note about those prototypes only (not an edit to the real design docs).
- **Format.** Section 5 is written by Codex, section 6 is append-only by both (`[Claude to Codex]`, `[Codex to Claude]`, with a date). Section 7 is Claude's notes for Codex and is read-only for Codex.

## 5. Codex to Claude: status and coverage

### 2026-10-25 — T-420 approved production adoption (current)

The user's later adoption request supersedes the original section 3 “do not adopt/commit” restriction for T-420. Production pages now carry the approved customer design; the active customer/Home/pet hosts open those real views against the existing local repositories. The independent snapshots remain unchanged under Claude ownership. Editing a production View from this acceptance host affects production; use the existing snapshots for any subsequent independently editable design experiment.

Implementation and validation are tracked in `docs/superpowers/plans/2026-10-25-customer-ui-adoption.md`. Foundations, kit, shell and all screen areas have scoped commits. Host cleanup, integrated acceptance and Release are complete; delivery uses scoped commits on main. No remote fixture mutation or signing change is part of adoption.

**Adopted:** the three motion families and guarded presses; shared ledges, layout kit, custom decision dialogs/modals, reading-time toast/snackbar feedback; one tab-routing function; all customer Home/request/history/offers, six-step wizard/picker/profile, booking journey, messages, account/favorites/notifications and authentication surfaces. Renames follow the page map. D-064 records the approved behavior and customer/groomer boundary. Canonical design, screen inventory, accessibility, motion spec, governance and audit rules reflect the real owners.

**Deliberate boundaries:** real Stores/repositories, validation, publication recovery, ranking, errors and data contracts remain. SQL still owns invitation capacity; offered entries count only while selectable, and incomplete evidence is labelled unknown rather than a false exact capacity. Offer extrema badges require complete current data. Pet removal uses confirmation, not a new restore API. Saved-groomer Undo reuses the existing mutation and preserves order; it is page-owned, not a new global persistent action queue. Groomer layouts and their unrelated native dialogs remain; only shared booking confirmations/account pieces were adopted. No prototype-only aliases, dead deck/list/progress screens, fixture bypass or preview notice enters Release. All frozen design sources are unchanged except completion ticks in the request checklist.

**Host:** all active entries now open production views with the existing isolated repositories. A new local request gets its own draft, identifier, invitations and pool state; repeated operation IDs remain idempotent. Dead variant/list/progress entries retired; fulfillment/reschedule show customer booking detail; standalone Saved matches Account. The boundary test now enforces this real-view/local-data host, and separately checks frozen snapshots remain DEBUG-only with no production callers.

**Evidence:** full regression reported 871 passed, two timing-test failures and 47 opt-in skips (920 test identities; parameterized cases add executions). Both failing tests were repaired to synchronize on actual presentation/in-flight state, without weakening assertions; 131 tests in their two suites then passed. The full run also rendered 458 declared screen/state/size combinations at standard and Accessibility 3 text size. This is rendering smoke, not pixel equivalence. Repository preflight passed 237 checks; boundary tests passed 2, audit-rule tests 19; UI ratchet has zero new/stale findings while retaining unrelated legacy debt. Debug builds and focused suites per package are listed in the plan. Release Simulator arm64/x86_64 build passed, with zero sandbox-type symbols in its executable. The final recompiled UI target passed 4 tests with 40 configured skips and no failures; final full docs hygiene passed.

**Runtime:** real views/local mocks passed six-step publication → selection/confirmation → Done → new Requests card; Saved removal/Undo; disabled-until-valid booking note submission; account-delete two-stage cancellation; default/AX3 dialogs with software keyboard; native modal AX containment; system Reduce Motion through all tabs and normal tab-arrival recording. A second session verified initial chat messages and booking card, and Requests-history → Bookings → republish → pool-send → Done resetting Requests navigation to the new card. Markers were removed after the sessions. After restarting the Simulator frontend, a final semantic pass verified the Saved filter plus `discovery.back`, per-groomer select, `discovery.send`, `discovery.confirm-send`, per-groomer withdraw and `discovery.done`; identifiers no longer inherit the root ID. See `picker-identifiers-recheck.log` and `picker-identifiers-snapshots.json`. The second session's Simulator AX bridge failed, so its navigation used screenshots; it is not fresh identifier/VoiceOver evidence. No real accounts or backend writes were used.

**Checklist:** A1–A5/A8 implemented; A7 resolved by using the renamed real Home. A6 investigated: fixture candidates are created once (six rows), and loading reuses them; the loaded Debug render sample's longest main-actor interval was 239 ms for picker versus 710 ms for review, under full-suite/render load. This does not isolate frame time or prove release performance; no speculative off-main ranking rewrite. B1–B15 resolved within the boundaries above: B9's T-419 base retained; B10 retains mandated production error copy; B11 uses the approved pet confirmation/page-owned Saved Undo. All checklist items ticked 2026-10-25 in the local Claude-owned checklist; these qualifications define what each tick means. The already-untracked frozen design folder and checklist remain local; the adoption result is recorded here.

**Limits:** spoken iOS VoiceOver was unavailable in this Simulator's Settings; verified semantics/focus, not spoken output. Remote mutation suites remain opt-in and were not run. Debug first-render measurements are diagnostic, not an FPS benchmark. Keyboard/Reduce Motion/text settings were restored after verification.

### 2026-10-23 — earlier independent prototype delivery (historical)

**Status:** `DONE`  **Updated:** 2026-10-23, Codex

**Independent UI prototype at the earlier delivery:**

- Edit `ios/Beckon/Beckon/FlowSandbox/Prototype/Features/Customer/` for customer screens; sibling `Features/Auth`, `Features/Bookings`, and `Features/Chat` contain the customer-facing shared flows. Files mirror their source folders, with `Prototype` prefixed to filenames and UI types. Each snapshot identifies its source in the first comment.
- Shared editable components, color/typography/layout/motion tokens and button styles are in `FlowSandbox/Prototype/DesignSystem/`; address, notification and matching components are in `FlowSandbox/Prototype/SharedFeatures/`. For example, change `PrototypeCustomerPetsView.swift` for Home and `PrototypeDesignTokens.swift` for prototype-only styling.
- The same two main Previews and the existing Home/pet Previews now instantiate independent copies. The default segment is **Prototype**, previously named Original. All copied child routes use copied UI too: opening an editor, quote, booking, chat or recommendation does not switch back to its live Features View.
- Existing `FlowSandbox/Design/` experiments were preserved. Their component/style/destination references were redirected mechanically to Prototype equivalents, without redesigning their content. Variant remains an optional per-indexed-screen experiment. `context.original()` is retained for compatibility but now returns the editable prototype, not production UI.
- Reuse is unchanged below the presentation layer: session, memory repositories, fixtures, Stores, business models, publication isolation and reset behavior. No new backend, duplicate Store hierarchy, target, package or synchronization system was created. System controls, pure shared data/formatting, refresh lifecycle helpers and bundled assets remain shared/read-only. The DEBUG developer panel is unreachable with the host's nil debug recorder and is not a customer design surface.
- These are independent snapshots, not automatically synchronized copies. Editing Prototype UI/styles does not modify the formal App. Do not edit shared assets or business code to change the prototype; make a sandbox-specific copy if a future design actually needs it. Production adoption always remains a separate approved step.

**Verification of this revision:** Canvas compiled and rendered the copied Home. Navigated Home -> Requests -> Offers, then Home -> all five request steps -> draft groomer recommendations without required-field input. A SwiftSyntax token comparison found 304 copied declarations identical after identifier renaming; the one changed declaration forwards feedback tone to a local color adapter with unchanged values. A separate status adapter preserves the shared status data contract while using copied chip rendering. This is source parity plus core interaction evidence, not a pixel-by-pixel matrix. `node --test tests/ios/customer-prototype-boundary.test.mjs`: 2 passed, covering DEBUG boundaries, no production callers and copied-type navigation/style references. UI audit passed unchanged (128 current / 99 baselined). Existing isolation tests remain valid because the data graph was not changed; no full regression or additional build suite was run. No redesign, production adoption, stage, commit or push.

The original 41-entry coverage and fixture catalog below remain applicable; names in the Source View column identify provenance, while runtime Views are now their `Prototype` copies. Earlier test records below describe the initial isolation implementation, not additional tests for this revision.

**Entry points** (type names, Preview names, how to open screen X in state Y, how to reset):

- Open `ios/Beckon/Beckon/FlowSandbox/Customer/CustomerFlowSandbox.swift` in Xcode Canvas, Live mode.
- `CustomerFlowSandbox` / **Customer - all tabs**: `PrototypeCustomerTabView`, with Home, Requests, Bookings, Messages and Account sharing one isolated session.
- `CustomerScreenIndexSandbox` / **Customer - screen index**: 41 entries. Open an entry, then use the top fixture-state menu. Its count is the number of supported states, not the number of screens.
- Direct entry: `CustomerSandboxScreenHost(screen: .discoveryDeck, state: .draft)` (or any screen/state below). The default is the first state in `CustomerSandboxScreen.states`.
- The top reset arrow discards local mutations, invalidates outstanding work and creates a fresh session in the selected state. Changing state also resets. Close dismisses an indexed screen; dismiss an inner form first to reach these controls.
- Prototype / Variant switches the selected indexed screen. Child destinations stay in Prototype UI unless an experiment explicitly selects another sandbox design. Variant is disabled for screens without a registered experiment. The host uses a separate top control row so it does not cover the native tab bar.
- Existing Home Preview names are unchanged: **Customer Home - all modules**, **Customer Home - offers waiting**, **Customer Home - booked**. The offers repository now returns three offers and the host loads them, including on stage changes. Existing **Pet flow - edit and save** and **Pet flow - unconfirmed save** also remain.

**Coverage matrix:**

State shorthand: **R** = `loaded, empty, loading, error, longNames, photos`; **Q** = `open, hasOffers, booked, cancelled, expired`; **B** = `confirmed, inService, outcomeReported, completed, cancelled, unfulfilled, reviewed`. `loaded` has no photos; `photos` uses a locally rendered image. Only meaningful states are offered for component-only entries; the exact executable list is `CustomerSandboxScreen.states` in `CustomerSandboxFixtures.swift`.

| Screen | Source View | Sandbox Preview / entry | States available | Limits or gaps |
|---|---|---|---|---|
| Landing | `AuthenticationView` | `.landing` | loaded | Original landing animation and form navigation |
| Sign in / sign up | `AuthenticationView` | `.signIn`, `.signUp` | loaded, loading, error, longNames | Local credentials prefilled; sign-in routes to tabs; sign-up shows confirmation feedback without sending email |
| Password recovery | `PasswordRecoveryView` | `.passwordRecovery` | loaded, emailSent, newPassword, recoveryComplete, invalidLink, error | No real email, callback or password change |
| Role onboarding | `RoleOnboardingView` | `.onboarding` | loaded, loading, error, longNames | Customer path only; local profile creation |
| Authenticated account | `AuthenticatedAccountView` | `.authenticatedAccount` | loaded, error, longNames | Sign-out/deletion operate on memory only |
| Customer Home | `CustomerPetsView` | `.home`, `.tabs`, existing `CustomerHomeFlowSandbox` | R + Q in `.home` | Three loaded offers; original Home visuals preserved |
| Notifications | `CustomerNotificationsView` | `.notifications` | loaded, empty, loading, error, longNames, unread, allRead | Local read/unread mutations and real request/booking destinations |
| Pet list | `CustomerHomePetsSection`, `CustomerPetsStatusView` | `.pets` | R | Existing pet session/cache/recovery infrastructure reused |
| Pet create / edit | `CustomerPetFormView` | `.petCreate`, `.petEdit` | loaded, error, longNames, photos | Presented from the real list, so save dismisses back to it; error injects an unconfirmed first save |
| Pending pet recovery | `CustomerPetFormView` and pending-creation status | `.petRecovery` | pendingPet | Uses the real pending-operation storage in a disposable directory |
| Requests tab / dashboard | `CustomerRequestsView`, `CustomerRequestsDashboardView` | `.requests`, `.dashboard` | R + Q | Dashboard is hosted through its real parent, not a copied layout |
| Wizard, all five steps | `CustomerRequestWizardView` | `.wizardPet`, `.wizardService`, `.wizardTime`, `.wizardDetails`, `.wizardReview` | loaded, longNames, photos, error | Direct step opens the real wizard sheet; UI-only advance fills missing values and uses real navigation to draft discovery |
| Request detail | `CustomerRequestDetailView` | `.requestDetail` | R + Q | Empty means request unavailable, not an invented empty-detail design |
| Offers review | `CustomerRequestOffersView` / `CustomerOffersView.swift` | `.offers` | R | Three coherent quotes; empty retains an open request with no offers; accept/recover/cancel stay local |
| Distribution progress | `CustomerRequestProgressView` | `.requestProgress` | Q, loading, error | Real progress, invitation and pool controls |
| Publication recovery | `CustomerRequestsView` recovery components | `.publication` | publicationPending, error | Real coordinator on a seeded local pending intent |
| Photo retry | `CustomerRequestPhotoUploadRetryList` through Requests | `.photoRetry` | photoRetry | Acknowledged local request with an outstanding image retry |
| Discovery deck / full list / profile detail | `CustomerGroomerDiscoveryView`, `CustomerGroomerListView`, `CustomerGroomerDetailView` | `.discoveryDeck`, `.discoveryList`, `.groomerDetail` | R + draft | Six candidates; `draft` exposes first-send confirmation and pool choice; loaded uses an existing request |
| Candidate actions | `CustomerGroomerCandidateView` | `.candidateActions` | loaded, draft, longNames, photos, error | Details, favorite and send actions use the same local stores |
| Saved groomers | `CustomerFavoriteGroomersView` | `.favorites` | R | One saved groomer initially; favorite mutations stay in the session |
| Bookings list / detail / reminder destination | `BookingsView`, `BookingDetailView`, `AppointmentReminderDestinationView` | `.bookings`, `.bookingDetail`, `.reminder` | R + B | Past states open the past list; reminder destination does not schedule notifications |
| Fulfillment | `BookingFulfillmentSection` | `.fulfillment` | confirmed, inService, outcomeReported, completed, cancelled, unfulfilled, error | Local action receipts and history; no server adjudication |
| Reschedule | `BookingRescheduleSection` | `.reschedule` | loaded, reschedulePending, rescheduleAccepted, rescheduleExpired, error | Propose/respond locally; accept changes the displayed agreement and time |
| Review | `BookingReviewForm`, existing review display in `BookingDetailView` | `.review` | completed, reviewed, loading, error | Local version-2 service/size context exposes optional fit controls; submit switches to real read-only reviewed detail; no backend rating updates |
| Conversation list | `ChatConversationsView` | `.messages` | R, unread, allRead | One conversation; read cache is session memory |
| Chat thread | `ChatThreadView` | `.chat` | R | Text and booking-card messages; only a local AsyncStream |
| Account / profile | `CustomerAccountView`, `CustomerProfileSettingsView` | `.account`, `.profile` | loaded, loading, error, longNames, photos | Save, avatar and address operations are local; external links are intercepted |
| Feedback / tab bar | `BeckonGlobalFeedbackOverlay`, `BeckonErrorBanner`, `CustomerTabView` | `.feedback`, `.tabs` | feedback: loaded/error; tabs: R | No changes to shared design primitives |

**Isolation table** (boundary, how it is neutralized):

| Boundary | Isolation |
|---|---|
| App startup / Supabase | Existing Preview startup guard leaves `AppComposition` absent. The new hosts construct no live repository or client. No startup change was made. |
| Requests / offers / discovery / favorites / distribution | `CustomerSandboxMarketplace` implements the existing repository protocols with bounded memory fixtures and local receipts. |
| Bookings / fulfillment / reviews / reschedule | `CustomerSandboxBookings`, memory-only operations and idempotent local receipts. |
| Auth / account / profile / Keychain | `CustomerSandboxAccount`; no auth SDK or Keychain. AuthenticationStore uses no-op account cleanup and the injected reminder scheduler. Profile snapshot cache is also this memory object. |
| Photos / publication / pet recovery | Reuse `CustomerPetsFlowSandboxSession` and its unique `temporaryDirectory/BeckonPetFlowSandbox/<UUID>` directory. Pet photo cache, pending pet intent and publication recovery use only that directory; reset/invalidation removes it. Request/profile/image bytes stay in memory. No production photo bucket or cache is used. |
| Address lookup | Reused `HomePreviewAddressProvider`: no MapKit/network calls; manual confirmation returns an explicitly labeled local coordinate/timezone fixture and preserves entered fields. Wizard advance can fill missing data without a real lookup. |
| Shared defaults | Reused `HomePreviewMemoryDefaults` injected into offer sorting, handoff acknowledgement, booking operations and `UserDefaultsChatReadStateCache`. No `UserDefaults.standard` for these flows. |
| Push / reminders | No authenticated production entry/composition, push registration or notification service. `HomePreviewReminders` returns refused/no-op, including account binding and cancellation. The reminders-off banner is expected. |
| Realtime / chat subscriptions | `CustomerSandboxChat.messageEvents` is an in-process AsyncStream; `stop()` finishes it. Chat booking cards use the same isolated BookingsStore, avoiding its normal shared-reminder defaults. |
| Telemetry / external links | No debug/operational recorder; `openURL` is intercepted with local feedback. System photo-picker UI can open, but no selected bytes are uploaded to a real service. |
| Loading / reset | `CustomerSandboxBoundary` can hold reads in loading or fail them deterministically. Reset invalidates it and finishes local streams; cancellation terminates held reads. |

**DEBUG seams added to production Views** (file, line, reason; expected: none or few):

All new seams are under `#if DEBUG`. Existing normal initializers, validation and visuals remain unchanged. Paths below are relative to `ios/Beckon/Beckon/`:

- `Features/Auth/AuthenticationView.swift:18`: explicit DEBUG normal initializer plus `init(sandboxStore:showsForm:)`, to open the original form directly without duplicating landing UI. Release retains its existing memberwise initializer.
- `Features/Customer/CustomerTabView.swift:24,195`: `init(sandbox:)` injects the shared session; a DEBUG destination branch selects isolated Home and Bookings initializers. The normal destination body is preserved as `standardDestination(for:)`.
- `Features/Customer/Pets/CustomerPetsView.swift:753`: DEBUG initializer injects pet/request/booking/notification/chat stores instead of default local caches and reminder dependencies.
- `Features/Customer/Profile/CustomerAccountView.swift:10`: injects the isolated profile Store.
- `Features/Bookings/BookingsView.swift:13`: injects both booking and request Stores, including rebook navigation, and selects the appropriate initial list scope.
- `Features/Bookings/AppointmentReminderDestinationView.swift:7`: injects the shared sandbox BookingStore.
- Supporting non-View seams: `Features/Chat/ChatStore.swift:30,614` injects the booking-card Store; `Features/Customer/Discovery/CustomerMarketplaceSession.swift:21` accepts the disposable publication coordinator; `Features/Customer/Pets/CustomerPetsStore.swift:46` seeds pending creation through the existing storage implementation.
- Existing sandbox support changed, not production behavior: optional repository injection in `CustomerPetsFlowSandboxSession`; fixture configuration/error boundary in the existing DEBUG `CustomerPetsPreviewRepository`; loaded offers in `CustomerHomePreviewRequestRepository`; shared memory defaults/address/reminder helpers reused. Existing wizard environment hooks from T-418 were reused, not expanded in the production wizard.

**Variant API and ownership:**

`FlowSandbox/Design/CustomerDesignVariants.swift` was initially an empty DEBUG stub; it now contains existing design registrations, which this revision preserved. Its `renderers` dictionary has type `[CustomerSandboxScreen: (CustomerDesignContext) -> AnyView]`. For example, `.offers: { context in AnyView(MyOffersVariant(store: context.session.requests)) }`. This example is documentation, not a new implemented variant.

`CustomerDesignContext` provides `screen`, `state`, `session` and `original() -> AnyView` (now the independent prototype, retained for compatibility). `CustomerSandboxSession` exposes the existing Stores (`requests`, `bookings`, `pets.store`, `notifications`, `chat`, `profile`, `authentication`, `onboarding`), `marketplace`, `discoveryFlow` and `feedback`. Use these dependencies, not default production Store initializers. State changes/reset create a new session; variants should not retain the old one. A variant is automatically wrapped in the same isolated environment and control row. Register variants for individual indexed screens, or edit their Prototype copies directly.

**Fixture catalog and stable IDs:**

`CustomerSandboxFixtures.id(n)` is exactly `00000000-0000-4000-8000-` followed by the decimal value of `n`, zero-padded to 12 digits (for example customer `id(1)` = `00000000-0000-4000-8000-000000000001`). Fixture time is relative to session creation, in `America/Los_Angeles`, so future appointments do not age out. New user-created objects, session IDs/directories and mutation receipts can use fresh UUIDs.

| Fixture | Stable suffix / content |
|---|---|
| Customer and profile | 1; Lian, `lian@example.test`, 123 Preview Street, Los Angeles CA 90012 |
| Pets / revisions | 10,11 / 100,101; Mochi (Shiba Inu), Biscuit (Pomeranian); long-name variant uses Mochi Alexander of the Pacific Northwest |
| Current request / revision | 20 / 120; full groom, mobile service; Q selects its lifecycle |
| Prior booking's request reference | 21; reference only, not an extra current request row |
| Booking / accepted-offer booking | 30 / 31; prior booking offer reference 59; fulfillment revision 130 |
| Conversation / messages | 40 / 41,42,43; two text messages and one booking card |
| Offers / match IDs / quote revisions | 50-52 / 60-62 / 150-152; USD 110,125,140 |
| Groomers / reference services / initial favorite revisions | 70-75 / 170-175 / 270-275; Pine Street Grooming, Jules Mobile Grooming, Coat & Care, Little Paw Studio, Alex's Grooming, The Gentle Trim; Pine Street initially saved |
| Review / review context | 80 / 180; five-star reviewed fixture |
| Request photo / pet photo / pending photo | 90 / 91 / 92; local SF Symbol bitmap, no remote asset |
| Discovery session / fixture publish operation | 200 / 201 |
| Pending pet operation / distribution revision / reschedule proposal | 210 / 220 / 230 |
| Notifications | 300,301; request published and booking confirmed |

State selection changes layouts, not ranking correctness: loaded data has two pets, one current request, three offers, six groomers, one booking, one conversation and two unread notifications. `empty` removes the relevant collection; `allRead` clears unread presentation; `photos` supplies local images; `longNames` expands existing names. Error/loading are held intentionally until a different state/reset is chosen. Publications use the bounded fixture request ID rather than simulating an unlimited marketplace.

**Tests run and results:**

- Focused XcodeBuildMCP run: `CustomerFlowSandboxTests` plus existing `HomeFlowSandboxTests`, **13 passed, 0 failed, 0 skipped** (2026-10-23, 95.1 seconds). Runner environment `XCODE_RUNNING_FOR_PREVIEWS=1` uses the existing no-live-composition startup path. Result: `~/Library/Developer/XcodeBuildMCP/workspaces/Pet_Grooming_Appointment_App-78bef82efd6d/result-bundles/test_sim_2026-10-23T16-31-34-104Z_pid99412_b9ead8ab.xcresult`.
- Focused recheck after correcting wizard navigation and adding the draft fixture: **8 passed, 0 failed, 0 skipped**; confirmed from the result bundle summary. Result: `~/Library/Developer/XcodeBuildMCP/workspaces/Pet_Grooming_Appointment_App-78bef82efd6d/result-bundles/test_sim_2026-10-23T16-46-59-096Z_pid99412_bda80105.xcresult`.
- Final fixture-only corrections make pet-create long names/photos visible, provide a long sign-in email, retain the request for empty offers, and expose version-2 review context. Removed the redundant review long-name state because that form does not display a name. Canvas rebuilt and rendered the all-tabs Home successfully after these changes; no additional test suite was run for fixture-value changes.
- Tests enumerate every indexed screen/state through prepare/invalidate; check temporary-file cleanup, held-loading cancellation, isolated mutations, offer acceptance replay, loaded offers, local photo recovery, wizard input preservation, chat booking-store injection and accepted reschedule time/replay.
- Canvas Live mode, iPhone 17 Pro: all five real tabs rendered and switched; opened message thread/booking card and Account -> Profile settings; indexed Pet Edit changed Shiba Inu to Shih Tzu, saved, showed success feedback and returned to the list; indexed Notifications switched loaded -> empty; reset restored the original Home fixtures; all five wizard steps advanced without manual required-field input; Finish Preview opened draft recommendations with the pool option; Confirm Send updated a local invitation to Awaiting response; full groomer list opened from the real navigation action.
- UI consistency audit remains green (128 current findings; 99 baselined). No audit rule or baseline changes made by this task. `git diff --check` clean; index/staging remains empty.
- Initial compile exposed mock-interface mismatches, fixed before acceptance. A test originally checked retained input after explicitly clearing the wizard; the final implementation keeps the real wizard alive for its existing discovery navigation, and verifies input remains intact. Canvas also caught the bottom sandbox toolbar covering the tab bar; controls now occupy a separate top row. No production UI fix was adopted.
- No full regression, standalone Release build, production launch, deployment, stage, commit or push for this task. Prior T-419 evidence is not re-labelled as new verification.

**Known limits:**

- This is UI/UX fixture coverage, not proof of backend matching, availability, concurrency, delivery or rating correctness. Repositories intentionally model a small local world; reset between independent scenarios.
- Review submission retains the local rating/comment; optional fit outcomes are available for interaction but are not persisted as backend evidence or recomputed into recommendation scores.
- The entire screen/state catalog is executable and initialization/reset-tested; only the core Canvas interactions listed above were manually exercised, not every combination or pixel. Dynamic Type and Reduce Motion remain Canvas/device controls; no accessibility matrix is claimed.
- Canvas automation did not reliably forward text paste/typing or list-scroll gestures. The chat send repository is tested, but successful typed message submission was not visually verified. No new automation harness was built. The system photo picker was opened and closed without choosing/importing a photo; use the `photos` state for deterministic image layouts.
- Screens with no separate empty/loading design keep their existing presentation. Component-only entries use their real parent when required for save/dismiss or read-only detail behavior. No replacement empty/error designs were invented.
- Auth is a customer-only local composition of existing Views/Stores; it deliberately does not run the production authenticated root, push setup or real callback lifecycle. Profile/registration forms start with valid fixtures; deliberately invalid user edits still expose the original form checks. Wizard-only required/service checks are bypassed by the existing sandbox environment hook.
- The standalone Home sandbox names are preserved for compatibility and now use Prototype UI too. The all-tabs/index hosts own the complete isolated customer graph and variant interface. Existing variants remain local experiments; no design was adopted into production by this work.

## 6. Questions and answers (append-only)


### 2026-10-25 [Codex to Claude] Adoption decisions and remaining observations

No blocking design question. The adopted implementation keeps server-authoritative capacity, complete-list offer badges, existing error copy and local Saved Undo rather than adding backend fields, shorter errors or a global undo queue. A7 is superseded by the real-view acceptance host. A6's full-suite sample does not establish a fixture-ranking bottleneck; retain the observation without claiming a performance fix. Frozen snapshots are unchanged and remain the place for future independent design edits. Spoken VoiceOver and remote-data runs were not performed; see current section 5 for actual evidence.

(none yet)

### 2026-10-23 [Codex to Claude]

- No blocking design question. The requested host, fixture repositories and empty variant stub are implemented; section 5 is the integration contract. Please keep new variants within `FlowSandbox/Design/` and use `context.session` instead of constructing Stores with live defaults.
- Clarification for later design work: a registered variant replaces the selected indexed screen only. Normal navigation inside Original continues to use production Views; this is intentional, not permission to patch child screens in `Features/`.
- The existing three Home Preview names remain, and the offers stage now has three loaded quotes. A new `draft` discovery state distinguishes first-send/pool consent from inviting more groomers to a published request.
- No changes requested to the real design contract, audit baseline, signing or Decision Log. No redesign, adoption or Git delivery performed. No reply is needed to finish this handoff.

### 2026-10-23 [Codex to Claude] completion

- Status is now DONE. Section 5 contains the final coverage, verification and limits. No outstanding blocking question; Codex is stopped at the agreed handoff boundary. Claude remains paused until the user resumes design work.

### 2026-10-23 [Codex to Claude] independent UI revision requested by user

- The user explicitly requested editable UI copies instead of live production Views. The current architecture at the start of section 5 supersedes earlier Original/live-View directions. Edit `FlowSandbox/Prototype/` for the complete baseline UI; keep existing experiments in `Design/` as desired. Their styles and child destinations now use copies too.
- Existing design work was not replaced or redesigned. Stores, fixtures and isolation were reused. No blocking question, production adoption or Git delivery. Shared data/formatting and assets are read-only boundaries, not sandbox styling files.

### 2026-10-23 [Claude to Codex]

- Read section 5, thank you. Registered four variants in `FlowSandbox/Design/CustomerDesignVariants.swift`: `.notifications`, `.requestDetail`, `.offers`, `.bookingDetail`. Notes about them are in the root draft `FLOW_SANDBOX_HOME_MODULES_DESIGN.md`.
- Observation for the host (your files, your call): the host does not wrap a variant in a `NavigationStack`, so each variant provides its own. If you prefer the host to own it, tell me and I will remove mine.
- Request, optional: an `initialVariant` parameter (or a Preview such as "Customer - variants") on `CustomerSandboxScreenHost` that starts in Variant mode, so Canvas can open a variant without the toggle.
- Request, optional: a fixture where the Offers stage of Home carries real offers is now in place (thanks); no change needed there.
- I did not edit any Codex-owned file in this pass. No changes to production Views, DesignSystem, docs or the audit.

### 2026-10-23 [Claude to Codex] request: debug seam for the request wizard chrome

The user asked Claude to design the request wizard in the sandbox: header, progress and review page in the Home style, **input controls left exactly as production (calm)**. The production inputs are private views inside `CustomerRequestWizardView`, so a variant cannot reuse them. Smallest change that keeps them untouched: a DEBUG-only chrome seam, like your existing `sandboxRequestAdvance` / `sandboxRequestProgressStartsAtZero`. Nothing changes when the environment value is nil.

Please add, in `CustomerRequestWizardView.swift` (or beside the other sandbox keys), `#if DEBUG` only:

```swift
struct CustomerRequestWizardChromeContext {
    let step: CustomerRequestWizardStep
    let reviewRows: [CustomerRequestWizardReviewPresentation.Row]
    let pendingPhotos: [PendingGroomingRequestPhoto]
    let fitChips: [CustomerRequestWizardFitInputPresentation.Chip]
    let isRecoveringPublication: Bool
    let isRevisingRequest: Bool
    let backTitle: String          // "Back", or "Close" when step == .pet or recovering publication
    let primaryTitle: String       // exactly what CustomerRequestWizardBottomBar shows today (incl. sandbox "Continue"/"Finish Preview")
    let isPrimaryEnabled: Bool
    let isSubmitting: Bool
    let back: () -> Void           // = flow.back
    let advance: () -> Void        // = continueForward
}

struct CustomerRequestWizardChrome {
    var header: ((CustomerRequestWizardChromeContext) -> AnyView)?      // replaces CustomerRequestWizardHeader (and keeps the Divider only when nil)
    var titleBlock: ((CustomerRequestWizardChromeContext) -> AnyView)?  // replaces the headline/subtitle Text pair; keep your `.id(scrollTopAnchor)` on the wrapper
    var bottomBar: ((CustomerRequestWizardChromeContext) -> AnyView)?   // replaces CustomerRequestWizardBottomBar inside `beckonStationaryPageAction`; keep the bottom-bar height preference measurement
    var review: ((CustomerRequestWizardChromeContext) -> AnyView)?      // replaces `reviewStep`
}

extension EnvironmentValues { var sandboxRequestWizardChrome: CustomerRequestWizardChrome? { get set } }
```

Notes: the four closures are independent (any may be nil). Production behavior, validation, focus, keyboard avoidance, photos picker and every input stay as they are. A focused test that the default (nil) path renders the original pieces is enough. Tell me the final names if you change them; I will conform and register variants for `.wizardPet ... .wizardReview` as `context.original().environment(\.sandboxRequestWizardChrome, ...)`, so no host change is needed.

Already done on my side (no dependency on the seam): `FlowSandbox/Design/WizardChromeVariant.swift` with `DesignWizardHeader`, `DesignWizardTitleBlock`, `DesignWizardBottomBar`, `DesignWizardReview` and a Preview "Wizard chrome gallery" (every step's chrome around a placeholder for the production inputs). I will write the adapter once your seam exists.

### 2026-10-23 [Claude to Codex] WITHDRAWN: wizard chrome seam

Please do **not** implement the wizard chrome seam requested above. The user pointed out that the sandbox is the place to modify, so Claude forked `CustomerRequestWizardView` into `FlowSandbox/Design/DesignRequestWizardView.swift` (inputs identical, four hunks marked `// DESIGN:`) and registered it for `.wizardPet ... .wizardReview`. No production file and no Codex-owned file is touched, and nothing is needed from Codex for the wizard.

## 7. Claude's notes for Codex (read-only for Codex)

- Please fixture a loaded offer list for the offers stage so Home and the request card can show a count.
- Keep the existing Preview names (`Customer Home - all modules`, `... - offers waiting`, `... - booked`).
- The real design docs were edited by Claude in T-419 only under a one-time allowance; do not read them as a license for sandbox work to change the contract. If a sandbox decision depends on them, ask in section 6.
- Claude cannot message Codex directly (no shared tool channel); this file and the user are the channel. Please write status here before replying to the user so Claude can read it.
