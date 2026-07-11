# Worklog

```text
Date: 2026-07-11
Task: T-274 - Customer Edit Pet photo/action/typography and carousel-shadow refinement.
Files changed: Shared form-field cursor tint; Edit Pet photo card, Details text roles, name limiter, save bar; Customer Request carousel containment; focused test; memory closeout.
Checks: Customer Pets focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Pet Photo now matches Profile Settings with a 96pt avatar, saved check, matching text hierarchy, and Upload/Replace Photo action. Details follows the same field-label/value/supporting roles. Save Pet uses the Request Wizard gradient footer. Names stop at 20 characters and flash the field/cursor red on rejected input. Request carousel shadows stay inside internal scroll padding.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. Upload, cache, persistence, backend, and remote state are unchanged.
Next: Use T-275 for the next user-selected task; Q-104 remains deferred.
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

```text
Date: 2026-07-11
Task: T-271 - Customer profile actions, republish button, and Edit Pet form refinement.
Files changed: Customer Profile header/save placement; shared request/booking republish button; Edit Pet navigation title, compact profile layout, field typography, single-line name limiter; focused test and memory closeout.
Checks: Customer Profile, Pets, Requests, and Bookings focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Profile Settings no longer repeats its page header and Save Profile follows the final module. Republish is a normal shared button with template/booking-specific copy. Edit Pet uses a centered toolbar title, compact Customer-Profile-style fields, and a hidden 80-character Name limit that rejects overflow while preserving native focus and cursor blinking.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. No persistence schema, upload behavior, backend, or remote state changed.
```

```text
Date: 2026-07-11
Task: T-270 - Customer card depth, notification lifecycle, scrolling, and Edit Pet refinement.
Files changed: Shared card shadow tokens; app-wide vertical scroll-indicator configuration; notification exit-read lifecycle; request swipe-hint removal; Edit Pet annotation/profile/avatar/name/choice layout; memory closeout.
Checks: Customer Pets, Notifications, and Requests focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Similar card shadows are constrained to 8pt and vertical scroll bars are hidden app-wide. Notifications remain visibly unread while open and mark all read on exit. Request swipe instructions are removed. Edit Pet uses external no-icon annotations, a compact avatar picker inside Profile, a labeled Name field, and leading restoration for selected horizontal options.
Risks: UIAppearance controls the vertical indicator globally by design. Visual acceptance remains with the user; no screenshot self-review was performed. No backend, upload contract, or remote state changed.
Next: Use T-271 for the next user-selected task; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-269 - Customer Home, notification, closed-detail, and carousel polish.
Files changed: Home greeting/bell; notification unread color token; cancelled Request Detail presentation/order; reusable carousel shadow token/application; focused test and memory closeout.
Checks: Customer Requests and tab-badge focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Home greeting copy aligns with page content without the smile tile, the bell uses system-badge red, and Home retains the full notification unread count. Cancelled request details omit Offers and place Create New Request after that logical section. Horizontal request cards have stronger bottom depth through one shared shadow token.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. No backend, mutation, notification-count source, or remote state changed.
Next: Use T-270 for the next user-selected task; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-268 - Customer cross-tab state, unread persistence, and notification consistency.
Files changed: Shared Customer Requests Store injection; closed-request limit/avatar rows; chat read-state cache and Store persistence; Customer Notifications automatic read flow and compact rows; focused tests and memory closeout.
Checks: Customer Requests, Chat, and Customer Notifications focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Cancelling a request updates Home and Requests through one observable Store. Recent Closed Requests shows three rows with the original pet avatar. Conversation read timestamps survive app relaunch. Opening Notifications loads and marks all rows read through the existing repository, with no manual mark-all/read controls or decorative row icons.
Risks: Chat read state remains device-local rather than server-synchronized; reinstalling the app or using another device starts without that local history. No backend, migration, or remote state changed.
Next: Use T-269 for the next user-selected task; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-267 - Customer request annotation and avatar alignment correction.
Files changed: Shared annotated-module alignment; customer request-card avatar dimensions/alignment; memory closeout.
Checks: `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Request Details title/subtitle annotations now sit above each module at the upper-left. The request-card pet avatar is 68pt to match the two-line headline only, aligns to the headline top, and uses equal large spacing from the card top/left and adjacent title.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. No request behavior, data, backend, or remote state changed.
Next: Use T-268 for the next user-selected task; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-266 - Customer request-card avatar proportion and alignment.
Files changed: Customer request-card header avatar dimensions/spacing and memory closeout.
Checks: `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: The request-card pet avatar is 84pt, visually approaches the full title/service text height, stays centerline-aligned with that text group, and uses the same large spacing scale between the avatar and adjacent content.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. No request behavior, data, backend, or remote state changed.
Next: Use T-267 for the next user-selected task; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-265 - Customer request card and detail hierarchy refinement.
Files changed: Request-card header alignment and stable root copy; reusable annotated-module design-system component; Request Details hierarchy, module labels, cancellation removal; focused test and memory closeout.
Checks: Customer Requests Store focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: The request-card pet avatar is centered against its title/service group, the Requests subtitle no longer changes with card count, and Request Details has one fixed navigation title. Every detail content area uses one reusable right-aligned title/subtitle annotation outside the card, while the duplicate page header and Cancellation module are removed.
Risks: Visual acceptance remains with the user; no screenshot self-review was performed. Request cancellation remains available from the request card, and no backend, mutation, or remote state changed.
Next: Use T-266 for the next user-selected task; Q-104 remains deferred.
```





This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.
