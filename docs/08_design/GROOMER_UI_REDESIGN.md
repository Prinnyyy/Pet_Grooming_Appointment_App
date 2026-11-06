# Groomer UI Redesign

- Decision: D-026 / R-039
- Approved: 2026-07-10
- Implemented packages: Q-97 through Q-103
- Q-104: local Simulator acceptance completed under T-402; evidence and limits are recorded below.

This active file retains only the current Groomer visual contract and regression scope. The complete T-249 execution contract is frozen at `../09_frozen/design_notes/T-347_2026-07-13/GROOMER_UI_REDESIGN.md`.

## Read Condition

Read this file only for Q-104, a focused R-039 visual regression, or a Groomer screen task that needs the role-specific layout contract. Use `../01_product/DESIGN_SYSTEM.md` and `../01_product/ACCESSIBILITY_RULES.md` as the shared authority.

## Current Contract

- Groomer is a calm, schedule/action-oriented workspace; Customer remains pet/decision oriented.
- The five direct Groomer tabs are Home, Requests, Schedule, Messages, and Account. There is no system More tab.
- Requests owns Matches and Offers segments. Notifications open from Home. Account is direct; feature editors hide the tab bar and expose one back action.
- Operational queues use one grouped surface with separators. Cards are reserved for standalone or genuinely raised objects.
- Coral is limited to Groomer actions, selection and role accents. D-060 uses Groomer Fill with Ink, Deep for links/controls, and opaque Tint for selected surfaces. Status and unread dots use shared semantic roles, not coral.
- Current request, offer, booking, chat, notification, profile, repository, and backend behavior remains authoritative.
- Do not add revenue, payments, ranking, maps, attachments, read receipts, typing state, new push behavior, schema, RLS/RPC, Storage, dependencies, or public assets through visual work.

## Local Acceptance

The user restored Q-104 on 2026-10-04 for local Simulator acceptance. The regression scope covers:

- loading, populated, empty, partial-error, retry, disabled, and busy states;
- long names and AX3 Dynamic Type without overlap or clipping;
- VoiceOver labels, grouping, headings, actions, and 44pt targets;
- approved color pairs and non-color status cues;
- image success, cache-first display, missing-image fallback, and remote failure;
- no More tab, duplicate back controls, or unstable selectors;
- preserved TestOps identifiers and updated selector-based automation where semantics change.

Simulator captures are visual evidence, not pixel pass/fail assertions. Behavioral automation remains selector and state based.

[T-402 acceptance](../superpowers/plans/2026-10-04-groomer-ui-accessibility-acceptance.md) owns the module inventory, findings, fixes and validation evidence. Runtime accessibility-tree inspection and announcement-content tests do not certify audible VoiceOver navigation, rotor behavior or speech timing. Physical-device, signing and release work remain outside this local scope.

## Evidence

Approved targets:

These images remain layout references. Their white-on-coral buttons and earlier brown foreground are superseded by D-060's Fill/Ink pairing; links use Deep. Numeric palette values belong only to Swift tokens and tests.

- [Home](groomer_ui_redesign/approved/groomer-home-approved.png)
- [Requests](groomer_ui_redesign/approved/groomer-requests-approved.png)
- [Account](groomer_ui_redesign/approved/groomer-account-approved.png)
- [Edit Profile](groomer_ui_redesign/approved/groomer-edit-profile-approved.png)

Pre-change captures remain under `groomer_ui_redesign/current/` and are read only for a named comparison.

## Architecture Boundary

Views do not call Supabase. Existing feature Stores remain mutation owners; the root tab owns navigation/deep-link coordination. A read-only Home aggregator may use existing repositories. No backend or remote write is part of this visual contract.

## Grooming Subtab Motion (T-468)

Matches location filters, Offers groups and Bookings groups share the same subtab control. Selection moves with a 160 ms ease-out, without spring overshoot; Reduce Motion disables the movement. Selection feedback starts locally and does not wait for list refresh. Keep the existing alignment, colors and touch targets. This replaces the slower general-purpose morph spring only for these subtab controls.

## Grooming presentation corrections (T-469)

Subtab movement animates only one persistent underline (160 ms ease-out; none with Reduce Motion). Label/icon state changes are immediate; switching a filter must not recreate the entire scroll view or replay its entrance. This narrows T-468's animation scope without changing tab layout or colors.

Matches and Offers portraits use the request's authorized frozen pet-photo snapshot, primary photo first, through the existing private image loader. Request attachments are not pet avatars. Preserve already loaded portraits while revalidating; unavailable or unauthorized photos use the existing placeholder, without bypassing access rules.

A Groomer cannot submit a customer review. Awaiting Review has no review footer action. Once a review exists, the existing read-only entry is titled “View review”. A compact read-only review below the hero progress is proposed, not yet adopted.

## Grooming subtab paging (T-470)

Matches, Offers and Bookings use one shared native horizontal pager pattern. Selecting a tab on the right moves the current page left and brings the next page in from the right; swiping left selects the right-hand tab, and vice versa. Pages move together on one plane, with no overlapping fade. Each scope keeps its own cached rows and vertical scroll position. Changing the main section still selects its first subtab.

Subtab touch-down gives immediate opacity feedback through a native ButtonStyle; release commits selection with no added delay or press-pulse wait. Drag cancellation remains native. The pager and selection underline share a 220 ms ease-out for taps; direct swipes follow the finger. Reduce Motion removes programmatic interpolation. This supersedes the 160 ms underline-only interaction from T-468/T-469. No shared card/button style is changed.

Implementation reference: [Apple TabView page style](https://developer.apple.com/documentation/swiftui/tabview).

## Grooming list loading (T-471)

Until a scope's first page arrives, show available account-bound Store rows; do not mark that fallback as a loaded server page. A fetched empty page replaces the fallback. Offers hydrate independent request/evaluation/booking reads concurrently. Groomer booking lists load review state and location concurrently and omit the groomer's own profile/avatar; other booking consumers retain their existing hydration.

Reappearing cards reuse presentation reads for 15 seconds (booking revision changes bypass reuse). Manual pull-to-refresh bypasses this window. Photos remain visible during refresh and failed photo reads remain retryable. Booking presentation and reschedule reads run concurrently. This is a display optimization, not permission to skip detail authorization or mutation validation, and does not introduce cross-restart order persistence.

## Adjacent-page prefetch and cancellation wording (T-472)

After the selected Grooming scope completes its first load, sequentially prefetch only its immediate neighbouring subtab(s), first page only, using the same page cache and in-flight read registry. Do not follow cursors. Skip fresh cached neighbours; prefetched pages older than 60 seconds remain displayable but require foreground revalidation on selection. A user entering an in-flight neighbour joins/promotes that read; unrelated speculative reads are cancelled. Background failures do not show an error on the current page.

Warm at most two pet portraits per neighbouring page through the existing authorized image loader/cache. Offscreen pager cards do not independently hydrate all portraits, customer names or reschedule state. Active cards retain the T-471 behavior. This is bounded prefetch, not an all-orders download or new persistence layer.

The Groomer Manage booking cancellation entry and confirmation title both read “Cancel Booking”. Use `calendar.badge.minus` for cancellation; the legacy stop symbol remains reserved for service-stop actions.
