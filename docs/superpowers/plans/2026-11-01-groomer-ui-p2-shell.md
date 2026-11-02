<!-- task-artifact
task: T-430
status: completed
type: plan
-->

# Handoff 4 P2: shell, host, Home and notifications

Reads: section 0; section 6 P2; section 3 items 2, 3, 4, 16; D3/D5/D7; section 7; appendix A P2/host and B. User now requests continuous P2–P8 execution. D2/D3 and Auto-ready choices explicitly answered; see Current State authorization and D-069.

- [x] Reuse prototype local fixtures behind production stores; build groomer host first.
- [x] Adopt Home/header/notifications, preserve real repositories and failure handling.
- [x] Shell sets role/design; stable stack paths and outgoing deep-link cleanup, no generation id.
- [x] Validate scoped runtime, unit/Release/static checks, record section-10 report; continue P3.

## Section 10 report

| Production files | Prototype twin / change |
|---|---|
| `FlowSandbox/Groomer/GroomerSandboxSession.swift`, `GroomerSandboxSchedule.swift`, `GroomerFlowSandbox.swift` | Fixtures from the two named groomer sandbox sources; DEBUG-only, memory repositories, temporary preferences/snapshots, real Stores and shell; loaded/empty/loading/busyDay/slotsFull |
| `Features/Groomer/Home/GroomerHomeView.swift` | `PrototypeGroomerHomeView`: coral scene, no pup, greeting/bell, next appointment, count tiles, Coming up, exceptional availability alert; no six-second first-load timeout |
| `DesignSystem/HomeHeader.swift`, `Features/Customer/Home/CustomerHomeView.swift` ⚑ | Extract production greeting as shared HomeHeader; new bell identifier parameter. Keep production typography/startup fixes, not the older prototype header |
| `Features/Groomer/GroomerTabView.swift`, new `GroomerNavigation.swift` | `PrototypeGroomerTabView` layout/role/icons/bar ownership; retain production repositories/session/debug plumbing; stable NavigationPath ownership instead of generation ids; shared Stores prepared for subsequent packages |
| `Features/Customer/CustomerNavigation.swift`, `CustomerTabView.swift` ⚑ | D3 manual selection clears outgoing path/detail focus; no identity rebuild; action handoffs keep incoming destination |
| `Features/Groomer/Notifications/GroomerNotificationsView.swift` | `PrototypeGroomerNotificationsView`: banner, New/Earlier groups, in-place failed pagination; retain real destination/participant checks and current request-detail adapter until P3 |
| `Features/Groomer/GroomerPetAvatar.swift` | 23-line `PrototypeGroomerRequestParts` dependency needed by P2 Home; reused in P3 |
| `Core/Repositories/BookingRepository.swift`, Supabase implementation, debug wrapper, `GroomerHomeStore.swift` | Bounded chronological upcoming read, four confirmed bookings; avoids the descending general-list first-page error. Production query preserves participant filter/RLS; old nearest-only implementations keep a compatible default |
| `Features/Auth/AuthenticatedEntryView.swift` ⚑, `Features/Bookings/AppointmentReminderDestinationView.swift` | Role on authenticated presenter and reminder destination; prevents the outer presentation carrier applying default customer color to a groomer reminder |
| Existing groomer Requests/Profile/Availability/Services/Fit/Portfolio pages | Replace page-local tab bar hiding with P1's owner request. Page redesign remains in its assigned package |
| `DesignTokens.swift` ⚑; spec, screen inventory, audit allowlist/baseline | Keep validated count tile scale as bounded token; Home L / Notifications M; prune seven resolved legacy findings, no new broad exemption |

D-069 records decisions. The user reiterated that approved handoff UI/UX overrides the older app's design/workflow rules. Preserve the prototype's Open Account landing when paused, and the 0.6 count scaling; validation/authentication/data guards remain. D5 uses a four-row chronological read because sorting a descending partial page cannot find the actual nearest appointments. Home load errors follow handoff item 13 (inline cards, not competing toasts).

Protected production: customer navigation, launch, header typography and chat loading safeguards; immutable migrations, credentials, user governance/signing edits and both prototype trees. No role capability was added. The old closed profile-route enum remains intact so the unedited prototype still compiles. The compiler's actor-isolated Binding method-reference IRGen crash was resolved with an explicit setter closure; no project/compiler-flag workaround.

Checks: Debug generic Simulator build passed; Release generic Simulator build passed, including a final incremental Release build after entry-role wiring. Focused P2 tests **31/31 passed**; entry/role follow-up **10/10 passed**, zero failures. Tests cover customer/groomer outgoing path cleanup, incoming target preservation, Home/notification Stores, four chronological local bookings, default/AX3 layout and actual presented-sheet traits. Node source/boundary/audit tests **47/47 passed**; preflight, context hygiene and whitespace passed. Bundles/logs under `/tmp/beckon-handoff4/p2-*`. No additional screenshot campaign or spoken VoiceOver/visual approval claimed; user owns visual inspection. Full shared regression is reserved for the final gate, reusing prior unchanged evidence.

| Handoff question | Result |
|---|---|
| D1 | P1 trait/carrier preserved; P2 shell and reminder presenter select correct role |
| D2 | Explicitly approved for P7, including test-backend migration; no timing removal yet |
| D3 | Explicitly approved and implemented without stack identity changes |
| D4 | P4 uses existing authorized immutable booking snapshot fields |
| D5 | Bounded chronological next four; paused action follows prototype Account landing |
| D6 | Adopt accepted stages in P3 |
| D7 | P2–P8 first; T-428 independent, not a prerequisite |
| D8 | Current chat Updating/no skeleton preserved |
| D9 | Tier/spec/token additions documented, no new baseline exemption |
| D10 | Adopt pet owner user-facing wording in P6 |

P2 technical scope complete; continue directly to P3 under the user's continuous-execution instruction.
