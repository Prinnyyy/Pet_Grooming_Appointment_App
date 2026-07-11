# Worklog

```text
Date: 2026-07-11
Task: T-280 - Customer notification marker and tab-heading consistency.
Files changed: Customer Notification unread marker; shared Customer tab title visibility/Requests adoption; Home Active Request/Next Booking empty descriptions; memory closeout.
Checks: `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Unread dots sit outside notification cards in the left screen gutter and align to each card's vertical center. Requests uses the exact 36pt bold CustomerTabTitle used by Bookings, preserving the count chip as a trailing overlay. Home empty request/booking sections retain only their descriptive sentence beneath the section heading.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. Notification read state and all data behavior are unchanged. No backend or remote state changed.
Next: Use T-281 for the next user-selected task; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-279 - Customer notification-card and page-copy refinement.
Files changed: Customer Notification row layout; Requests root header; Home welcome typography; Edit Pet notes grouping; memory closeout.
Checks: `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Notification title, saturated unread dot, and timestamp share one compact metadata row while the description uses the full card width below, avoiding the prior forced wrapping from a persistent right column. Requests uses one Requests heading with no subtitle, Welcome Back is title3, and the redundant Care Notes label is removed.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. Notification read behavior/data and Request behavior are unchanged. No backend or remote state changed.
```

```text
Date: 2026-07-11
Task: T-278 - Immediate Customer notification refresh after Request mutations.
Files changed: Customer Requests mutation refresh hook; CustomerTab shared-store wiring; Notifications Store load coalescing; focused cancellation test; memory closeout.
Checks: Customer Requests and Notifications focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Supabase request notification triggers are synchronous, but iOS previously reloaded notifications only at tab startup or notification-page entry. Successful publish/cancel now immediately reloads the shared Store, and a refresh overlapping an active load is queued once rather than dropped. Home/tab unread counts and notification rows update from the same source.
Risks: Refresh uses one additional first-page notification read after each successful request mutation. No schema, trigger, RLS, backend, or remote state changed.
```

```text
Date: 2026-07-11
Task: T-277 - App-wide SwiftUI scroll-indicator suppression.
Files changed: Beckon app root scroll-indicator environment; memory closeout.
Checks: `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: SwiftUI-native scroll indicators are hidden from the AppRootView hierarchy, complementing the existing UIScrollView appearance fallback. Customer tabs, nested detail/edit pages, and future descendants inherit the same behavior without per-screen modifiers.
Risks: This intentionally hides indicators for both roles and authentication flows, matching the app-wide requirement. Scrolling behavior itself is unchanged. No backend or remote state changed.
```

```text
Date: 2026-07-11
Task: T-276 - Customer Pet Card sizing, birthday control, and photo-editor parity correction.
Files changed: Customer Home Pet Card height; Edit Pet birthday control; Pet Photo shared-component button/border parameters; memory closeout.
Checks: `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Age remains visible without increasing the original 252pt Pet Card height. Birthday Known reveals a label-free date control aligned at the original Birthday-label leading edge. Pet Photo now uses the exact Profile Photo full-width secondary button, 96pt avatar geometry, and border strength while its PhotosPicker still writes through CustomerPetsStore.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. No upload, cache, persistence, backend, or remote state changed.
```

```text
Date: 2026-07-11
Task: T-275 - Customer Pets age, shared photo editor, and horizontal-card shadow consistency.
Files changed: Shared photo-editor card; Customer Profile/Edit Pet adoption; CustomerPet age presentation; Home Pet Card copy/layout; Pet/Request horizontal shadow behavior; focused tests; memory closeout.
Checks: Customer Pets focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Home says Pets and Pet Cards show age derived from the stored birthday. Account Profile Photo and Edit Pet Photo now render through one reusable card while keeping customer-avatar and pet-avatar upload paths separate; only Account shows its saved badge. Pet and Request horizontal cards share one lighter shadow and allow it to render beyond the scroll viewport without rectangular clipping.
Risks: Age is device-date derived and displays Age not set when birthday is unknown. Visual acceptance remains with the user; no screenshot self-review was performed. No backend, Storage, upload contract, or remote state changed.
```

```text
Date: 2026-07-11
Task: T-274 - Customer Edit Pet photo/action/typography and carousel-shadow refinement.
Files changed: Shared form-field cursor tint; Edit Pet photo card, Details text roles, name limiter, save bar; Customer Request carousel containment; focused test; memory closeout.
Checks: Customer Pets focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Pet Photo now matches Profile Settings with a 96pt avatar, saved check, matching text hierarchy, and Upload/Replace Photo action. Details follows the same field-label/value/supporting roles. Save Pet uses the Request Wizard gradient footer. Names stop at 20 characters and flash the field/cursor red on rejected input. Request carousel shadows stay inside internal scroll padding.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. Upload, cache, persistence, backend, and remote state are unchanged.
```

```text
Date: 2026-07-11
Task: T-273 - Periodic meta-review.
Files changed: Current-state, task-ledger, and worklog closeout only.
Checks: Branch/status/diff; 62-file migration mirror and contract; root Markdown/conflict-marker audit; `node scripts/context-hygiene-check.mjs`; `git diff --check`.
Result: Active branch/task facts, migration count, links, ignore behavior, and rolling context windows align. No documentation structure or workflow correction was needed. The user's Edit Pet follow-up is preserved as T-274.
Risks: Root external reports remain review input under existing rules. No app, backend, Supabase, or remote state changed.
```

```text
Date: 2026-07-11
Task: T-272 - Customer Edit Pet visual hierarchy and Profile Settings action placement.
Files changed: Edit Pet Pet Profile photo/data cards, shared local typography roles, selected chip border rendering, Profile Settings save order, and memory closeout.
Checks: `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Pet Photo is a separate screenshot-informed card beneath the Pet Profile annotation while identity fields remain in a sibling card. Form headings, labels, values, and supporting copy use consistent text roles. Horizontal selection outlines render inside chip bounds, and Save Profile follows all Profile Settings modules.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. Existing photo upload/cache, pet persistence, profile persistence, backend, and remote state are unchanged.
```












This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.
