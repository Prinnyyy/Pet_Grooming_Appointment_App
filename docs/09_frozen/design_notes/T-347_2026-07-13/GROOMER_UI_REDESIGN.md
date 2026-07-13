# Groomer UI Redesign

- Status: approved design contract.
- Approved: 2026-07-10.
- Task: T-249.
- Roadmap: R-039.

## Purpose

Redesign the Groomer experience as a calm professional workspace while preserving the Customer experience's Beckon brand language. The Groomer side should answer three questions within seconds: what is next, what needs attention, and where to act.

This contract changes navigation and presentation only. It preserves the request -> offer -> customer acceptance -> booking/chat -> completion -> review lifecycle and existing repository/backend contracts.

## Evidence And Targets

Current Simulator captures:

- [Current Board](groomer_ui_redesign/current/groomer-board-current.png)
- [Current Offers](groomer_ui_redesign/current/groomer-offers-current.png)
- [Current Schedule](groomer_ui_redesign/current/groomer-schedule-current.png)
- [Current Messages](groomer_ui_redesign/current/groomer-messages-current.png)
- [Current system More](groomer_ui_redesign/current/groomer-more-current.png)
- [Current Account](groomer_ui_redesign/current/groomer-account-current.png)
- [Current Edit Profile](groomer_ui_redesign/current/groomer-edit-profile-current.png)

Approved visual targets:

- [Approved Home](groomer_ui_redesign/approved/groomer-home-approved.png)
- [Approved Requests](groomer_ui_redesign/approved/groomer-requests-approved.png)
- [Approved Account](groomer_ui_redesign/approved/groomer-account-approved.png)
- [Approved Edit Profile](groomer_ui_redesign/approved/groomer-edit-profile-approved.png)

The approved images define hierarchy, density, grouping, navigation, spacing, and visual tone. Their names, dates, counts, addresses, pet photos, and biography text are illustrative. Production SwiftUI must render live models and preserve existing validation, accessibility, and business rules.

## Product Direction

Customer and Groomer use the same product family, not identical layouts:

- Customer remains decision-oriented and pet-led.
- Groomer becomes action-oriented and schedule-led.
- Both retain the warm off-white background, white surfaces, semantic SF typography, familiar icons, and role accent colors.
- Coral identifies Groomer selection, primary action, and urgent/current state. It must not color every icon or section.
- Cards represent standalone objects. Normal navigation and work queues use one grouped surface with row separators.

## Navigation Contract

Replace the current six-tab layout and system-generated More screen with exactly five primary tabs:

| Tab | Responsibility |
|---|---|
| Home | Next appointment, limited attention queue, availability status, notification entry |
| Requests | Matches and Groomer-submitted Offers in one segmented pre-booking workspace |
| Schedule | Date selection, confirmed bookings, and booking navigation |
| Messages | Participant conversations and unread state |
| Account | Business profile, services, availability, fit, portfolio, evidence, support, and account actions |

Rules:

- Offers is not a primary tab. Requests owns a `Matches` / `Offers` segmented control.
- Notifications is not a primary tab. Home owns a top-trailing bell and navigates to the existing Groomer notifications screen.
- Account is a direct primary tab and must not show a More back button.
- Feature editors hide the tab bar and expose exactly one navigation back action.
- Existing deep links from notifications, bookings, and messages continue to select the relevant target tab and focused item.

## Shared Visual Contract

### Hierarchy

- Use semantic SwiftUI text styles. Remove feature-local fixed page and row font sizes where the redesign touches them.
- Page titles, section titles, row titles, metadata, and captions each have one consistent role.
- Screen horizontal padding remains 20 pt unless safe-area or native-control behavior requires otherwise.
- Space between sections is visibly larger than space within a section.

### Surfaces

- Use the app background as the page surface.
- Use one white grouped surface for related rows, with thin warm-gray separators.
- Reserve stronger elevation for the next appointment, sheets, overlays, and other genuinely raised objects.
- Do not nest cards, wrap page sections in decorative cards, or make each list row a separate floating card.
- Use a small, fixed set of semantic radii through `DesignTokens`; do not add raw feature-local radii.

### Color And Status

- Coral is limited to Groomer primary actions, selected navigation, unread/current emphasis, and small role accents.
- Success, warning, and error states use existing semantic colors plus text or icons; color alone is insufficient.
- Normal icons and chevrons are neutral unless their state requires emphasis.

### Images

- Continue using authenticated image loading and `BeckonModuleImage` behavior.
- Module images remain centered and aspect preserving. The redesign does not introduce public URLs, new buckets, or alternate image caches.
- Missing or failed remote images fall back to existing local/default avatars without layout movement.

## Screen Contracts

### Groomer Home

Create `GroomerHomeView` as the default Groomer tab.

Visible priority order:

1. Compact profile greeting and notification bell.
2. Next confirmed appointment with pet, service, date/time, location, and one booking action.
3. At most three attention rows: new matches, active/pending offers, unread messages.
4. Availability status and one management shortcut.

Home uses existing repositories. It must not invent revenue, payments, public ranking, map, or analytics data. Independent source failures must not blank unrelated sections; existing global feedback handles the error while the affected section provides retry or a truthful unavailable state.

### Requests And Offers

Use one Requests workspace with `Matches` and `Offers` segments.

- Matches uses a grouped list with pet photo, pet/service identity, preferred date, location, concise fit reason, state, and disclosure action.
- Offers retains pending/accepted/declined/withdrawn/expired behavior and existing detail/withdraw controls.
- Existing pagination, refresh, deduplication, and focused-request navigation remain active.
- Request detail keeps the pet snapshot as its identity anchor, separates service/time/location/photos/fit evidence, and places the primary offer action in a stable bottom action area when appropriate.

### Schedule And Booking

- Dates use stable dimensions and must not clip or resize as selection changes.
- Show one daily summary, then appointments or one truthful empty state; do not show duplicate zero-count and empty-state cards.
- Appointment rows prioritize time, pet/customer context, service, and status.
- Shared booking behavior remains role-correct. Groomer completion/cancellation actions stay explicit and duplicate-submit safe.

### Messages And Notifications

- Conversation rows share one grouped surface with separators instead of one raised card per conversation.
- Keep existing pagination, unread behavior, focused booking navigation, and chat thread behavior.
- Notifications open from Home and keep mark-read, mark-all-read, pagination, and deep-link behavior.
- Do not add attachments, read receipts, typing state, or new push behavior.

### Account And Editors

- Account is a direct tab with no back button.
- Group rows under Business, Matching & Schedule, and Support.
- Rows use compact labels and truthful trailing summaries derived from existing state.
- DEBUG-only Debug Console remains available without appearing in production visual targets.
- Edit Profile, Services, Availability, Fit Signals, Portfolio, and Evidence use a focused editor/detail shell with the tab bar hidden.
- Mutation editors use one stable bottom action area and immediate existing feedback after success/failure.
- Edit Profile combines avatar, business details, service area, and location mode without duplicated page/section titles or nested cards.

## State And Accessibility Matrix

Every implementation package must verify:

- initial loading, populated, empty, partial-error, retry, and disabled/busy states;
- long business/pet/customer names and Dynamic Type without overlap or clipping;
- minimum 44 pt interactive targets and meaningful VoiceOver labels;
- image success, cache-first display, missing image, and remote-load failure;
- no system More tab and no duplicate navigation back controls;
- existing accessibility identifiers remain stable where semantics are unchanged;
- changed tab selectors are updated in TestOps in the same package.

Simulator screenshots are visual review evidence, not automated pass/fail assertions. Behavioral automation remains selector/state based and does not depend on screenshot matching.

## Architecture Boundaries

- SwiftUI views do not call Supabase directly.
- `GroomerHomeStore` may aggregate read-only summaries from existing profile, request, offer, booking, notification, and chat repositories.
- Existing feature Stores remain the mutation owners for request dismissal, offers, bookings, messages, notifications, and profile changes.
- The root tab view owns navigation/deep-link coordination and shared badge sources.
- No migration, RLS/RPC change, Storage change, remote write, dependency, or new production asset package is part of R-039.

## Execution Packages

Implementation is sequenced through `../06_tasks/ROADMAP_EXECUTION_QUEUE.md`:

| Queue | Deliverable |
|---|---|
| Q-97 | Five-tab shell, shared operational primitives, and Groomer Home |
| Q-98 | Unified Requests/Offers workspace and request detail hierarchy |
| Q-99 | Schedule and Groomer booking presentation |
| Q-100 | Messages and notification entry/presentation |
| Q-101 | Direct Account tab and Edit Profile shell |
| Q-102 | Services and Availability editors |
| Q-103 | Fit Signals, Evidence, and Portfolio |
| Q-104 | Cross-screen accessibility, state, visual, and TestOps regression gate |

Each package uses the next available `T-###` only when explicitly started. Later packages may refine shared primitives introduced by Q-97, but must not silently redesign Customer screens or alter marketplace/backend behavior.

## Completion Signal

R-039 is complete when Q-97 through Q-104 pass their task-specific tests, full iOS test/build gates, selector-based TestOps regression, and Simulator visual review on a compact and large iPhone viewport with no overlap, clipping, duplicate navigation, or system More tab.
