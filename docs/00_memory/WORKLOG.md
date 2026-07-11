# Worklog

```text
Date: 2026-07-11
Task: T-284 - Periodic meta-review.
Files changed: Current-state migration/meta-review markers; Feature Index Pet Name contract; task-ledger closeout; worklog closeout.
Checks: Branch/status/recent history; 63-file migration mirror; active roadmap/index/task/current-state consistency; root Markdown ignore state; conflict-marker scan; `node scripts/context-hygiene-check.mjs`; `git diff --check`.
Result: Active branch, task sequence, migration mirror, links, rolling windows, root ignore behavior, and conflict state align. Corrected CURRENT_STATE's last remote migration from T-263 to T-283 and Feature Index's superseded 80-character Pet Name statement to the active 20-character pre-display limit. No workflow, app, or backend behavior changed.
Risks: APP_STATUS_OVERVIEW.md and V1.0_RELEASE_TASK_PLAN.md remain ignored review input rather than active truth. Q-104 and APNs remain unchanged. The user's address-input requirement is preserved as T-285 rather than mixed into this governance task.
Next: Use T-285 for Customer Request address input validation rules, an overlay autocomplete panel that does not reflow content, and outside-tap dismissal.
```

```text
Date: 2026-07-11
Task: T-283 - Groomer Availability save and Request match recovery.
Files changed: T-283 avatar relationship RLS migration; migration contract tests; memory closeout.
Checks: Remote log/SQL diagnosis; migration RED/GREEN plus all 53 migration tests; Matching TestOps unit tests; `./scripts/supabase-check.sh`; linked migration list/dry-run/push/alignment; rollback-only authenticated profile-update and availability-backfill verification; Supabase security/performance advisors; `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; diff/preflight/context hygiene.
Result: T-263's profiles avatar policy had created the recursive path groomer_profiles -> profiles -> bookings -> groomer_profiles, so Availability stopped at updateProfile and never persisted weekly hours. T-283 moves offer/booking relationship checks into a private SECURITY DEFINER helper with explicit current-customer validation, preserving the avatar access boundary without recursive RLS. A rollback-only remote test proved the affected Groomer can update the owned profile and that temporarily enabling Sunday immediately backfills the affected open Request through the existing T-155 trigger.
Risks: The rollback verification intentionally did not retain the user's attempted Sunday setting or create a permanent match. The Groomer must retry Save Availability with the intended days; the currently open Sunday Request will then backfill automatically. Security advisor retains the existing leaked-password-protection warning; performance advisor is clear.
Next: T-284 is reserved for the required periodic meta-review; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-282 - Reusable pre-edit text-length interception.
Files changed: Shared form primitives; Edit Pet Name field; Request address fields; focused limit tests; memory closeout.
Checks: Customer Pets and Requests focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: BeckonLimitedTextField uses UITextFieldDelegate to calculate and apply the allowed edit before UIKit displays it. Rapid typing cannot pass the limit, and oversized paste accepts only remaining capacity. The component owns reusable red border/cursor feedback and now enforces Pet Name 20, Request street 160, city 100, and ZIP 5 while preserving address suggestions and validation clearing.
Risks: The reusable control is intentionally single-line; existing multiline care/service-note fields remain SwiftUI TextFields. A legacy pure Pet Name helper remains for incremental test-binary compatibility but is not used by production input. No backend or remote state changed.
Next: Use T-283 for the next user-selected task; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-281 - Customer Account redesign and Request Wizard presentation ownership.
Files changed: Customer Account hierarchy/profile/menu/support/debug grouping; Customer Home/Requests active-tab sheet ownership; CustomerTab wiring; Request presentation/copy tests; memory closeout.
Checks: Customer Requests focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Customer Account now follows Groomer Account's unframed identity header, labeled grouped surfaces, compact summary rows, and support/access grouping while retaining the original 22pt teal icon treatment. The shared Request Store no longer drives two competing sheets: only the selected Home or Requests tab can present or dismiss the wizard, eliminating the first-open collapse race.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. Account destinations/actions and Request wizard data/persistence are unchanged. No backend or remote state changed.
```

```text
Date: 2026-07-11
Task: T-280 - Customer notification marker and tab-heading consistency.
Files changed: Customer Notification unread marker; shared Customer tab title visibility/Requests adoption; Home Active Request/Next Booking empty descriptions; memory closeout.
Checks: `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Unread dots sit outside notification cards in the left screen gutter and align to each card's vertical center. Requests uses the exact 36pt bold CustomerTabTitle used by Bookings, preserving the count chip as a trailing overlay. Home empty request/booking sections retain only their descriptive sentence beneath the section heading.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. Notification read state and all data behavior are unchanged. No backend or remote state changed.
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
