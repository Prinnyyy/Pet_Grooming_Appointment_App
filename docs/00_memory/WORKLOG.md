# Worklog

```text
Date: 2026-07-11
Task: T-292 - Shared Apple Maps address domain and parser.
Files changed: Provider-neutral address input/candidate/resolved/confirmed values; Apple Maps provider contract; complete secondary-address parser; compatible-query retention; selected/manual resolution; focused tests; queue and memory closeout.
Checks: Forced RED for missing Q-105 contracts; Customer Requests focused suite; `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene.
Result: Completed Q-105. Address Line 1 now extracts only complete Apt/Apartment/Unit/Suite/Ste/Floor/Fl/Building/Bldg/Room/Rm/# suffixes, preserves partial tokens, and never overwrites a conflicting Line 2. Provider-neutral confirmation models distinguish material building edits from Line 2-only changes. MapKit autocomplete now publishes up to five direct localized candidates, retains compatible results while the next query loads, performs one search only after selection, and supports Apple manual geocoding without forced translation.
Risks: Current Request/Profile forms still use their existing presentation and persistence contracts; the reusable editor/confirmation surface belongs to Q-106 and coordinate persistence begins only after Q-107/Q-108. No migration or remote write occurred in T-292.
Next: Use T-293 to adopt Q-106 Shared editor and confirmation UI; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-291 - Apple Maps address system design and execution plan.
Files changed: Authoritative R-040 Apple Maps/PostGIS plan; roadmap and Q-105...Q-112 queue; task/data-flow/feature/decision indexes; memory closeout.
Checks: Current iOS/Supabase location-flow inspection; read-only remote PostGIS/profile-count evidence; Apple Maps and Supabase PostGIS primary documentation; plan placeholder/contradiction self-review; local Markdown links; `git diff --check`; context hygiene; preflight.
Result: Adopted one reusable Address Line 1/Line 2 editor for Customer Profile, Groomer Profile, and Customer Request. Complete misplaced Unit/Apt suffixes auto-move unless an occupied Line 2 requires user choice. MapKit candidates display directly, only selected/manual addresses resolve, Place ID is optional, and complete coordinates plus explicit user confirmation are mandatory. Private PostGIS points make Customer travel radius or Groomer service radius authoritative; localized text becomes display-only after controlled backfill and strict cutover. Q-105 through Q-112 provide the dependency-ordered execution path.
Risks: Apple confirmation is not postal-deliverability validation. PostGIS is available but not remotely enabled; migrations, backfill, remote TestOps, and fallback removal require their own explicit authorization/evidence. Current app/schema behavior is unchanged.
```

```text
Date: 2026-07-11
Task: T-290 - Completion-driven English address autocomplete.
Files changed: Shared MapKit completion-resolution pipeline; Customer Request five-row suggestion presentation and focused tests; memory closeout.
Checks: Forced RED/green Customer Requests suite for stable concurrent completion ordering and localized-candidate exclusion; live unbounded MapKit probe resolving five `760 S Harbor Blvd` completions to en_US street/city/state/ZIP; `./scripts/ios-build.sh`; `git diff --check`; context hygiene.
Result: Removed T-289's whole-query forward geocode, which naturally returned one best address rather than autocomplete. The shared search now follows Apple's documented `MKLocalSearchCompleter` -> `MKLocalSearch.Request(completion:)` flow, resolves the leading completions concurrently, preserves MapKit relevance order, deduplicates real addresses, and displays up to five en_US reverse-geocoded candidates. No city/county/market region bias is configured. Request, Customer Profile, and Groomer Profile retain the same shared search service; UNIT/APT suffixes are excluded from search and restored only after selection.
Risks: MapKit search/reverse geocoding remains network-dependent. Failed or non-English-resolved candidates are omitted rather than fabricated; no third-party address provider or API key was added. No backend, persistence, or remote state changed.
```

```text
Date: 2026-07-11
Task: T-289 - Truthful English address autocomplete candidates.
Files changed: Shared MapKit address candidate/resolution pipeline; Customer Request address tests; memory closeout.
Checks: Live `MKLocalSearchCompleter` and en_US `MKGeocodingRequest` probes for `760 S Harbor Blvd`; forced-clean RED test; Customer Requests focused tests including async candidate publication; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Device evidence showed the completer returned English street titles but Chinese-localized city/country subtitles. The prior fallback collapsed five real locations into the typed text plus United States, which was not autocomplete. That fallback is removed. After 260ms input stabilization, iOS 26 uses `MKGeocodingRequest.preferredLocale = en_US`; older systems use `CLGeocoder` with the same preferred locale. Published rows contain actual street/city/state/ZIP data, Han-localized completer rows are excluded, already-English completer rows may supplement the list, semantic duplicates are removed, and selection directly fills the resolved candidate with any UNIT/APT suffix restored.
Risks: MapKit geocoding is network-dependent and may return one prioritized candidate for an ambiguous street unless city/state context is present. The UI never fabricates an alternative candidate. No backend, persistence, or remote state changed.
```

```text
Date: 2026-07-11
Task: T-288 - Customer Request address suggestion presentation regression fix.
Files changed: Customer Request Wizard suggestion positioning; memory closeout.
Checks: Direct `MKLocalSearchCompleter` query for `760 S Harbor Blvd`; Customer Request Wizard focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: The device MapKit API returned five completions, proving search input/network were not the failure. T-287 had replaced T-286's working Anchor preference rendering with a separately propagated CGRect overlay. The dropdown now uses the proven anchor-preference geometry again while retaining the simultaneous outside-tap recognizer, scroll passthrough, unit parsing, English fallback, sheet dismissal guard, compact bottom spacing, and hidden indicator.
Risks: The first focused-test attempt collided with a concurrently running build and locked DerivedData; the standard build passed and the focused test then passed when rerun serially. No backend, persistence, or remote state changed.
```

```text
Date: 2026-07-11
Task: T-287 - Customer Request address overlay interaction and detailed-address search correction.
Files changed: Shared MapKit address query/resolution; Request Wizard overlay gesture/sheet/scroll behavior; focused tests; memory closeout.
Checks: Customer Request Wizard focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: The address dropdown no longer installs a full-screen hit layer. A simultaneous single-tap recognizer dismisses it outside the street field, while vertical drags continue scrolling Wizard content and temporarily cannot dismiss the sheet. UNIT/APT/APARTMENT/SUITE/STE/# suffixes are removed only from the MapKit query and restored after selection. Han-script localized completion copy falls back to the typed English address, and selected locations use en_US MapKit reverse geocoding on iOS 26 with an English legacy fallback. Wizard bottom padding now follows the standard XL token and its scroll indicator is hidden.
Risks: A localized completion that contains Han script intentionally collapses to the typed English base/fallback context; this prioritizes safe English autofill over displaying multiple indistinguishable localized rows. MapKit remains network-dependent. No Store schema, repository, backend, persistence, or remote state changed.
```

```text
Date: 2026-07-11
Task: T-286 - Customer Request address input rules and overlay autocomplete.
Files changed: Shared limited form input rules; Customer Request Wizard address/search overlay; focused tests; memory closeout.
Checks: Customer Request Wizard focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: Request street, city, and ZIP edits now reject unsupported characters through the existing UIKit pre-display interception path while retaining 160/100/5 length limits and Apple's address-specific text content types. Existing MapKit address-only suggestions are rendered in a page-level overlay anchored below the street field, so results no longer push later fields downward; tapping outside dismisses the panel.
Risks: The outside-dismiss layer intentionally consumes that dismissal tap, matching dropdown behavior; the next control can be activated on the following tap. No Store, repository, backend, persistence, or remote state changed. XcodeBuildMCP Simulator interaction was unavailable, so validation used focused tests and the standard build without screenshot self-review.
```

```text
Date: 2026-07-11
Task: T-285 - Automatic meta-review chaining and compaction boundary.
Files changed: AGENTS and active workflow/context/meta-review rules; D-029; task/current-state/worklog closeout.
Checks: Rule diff review; `git diff --check`; `node scripts/context-hygiene-check.mjs`; preflight.
Result: When a completed task makes the immediate next task a required periodic meta-review, Codex now finishes the first task's own commit/push and automatically executes the reserved review without waiting for another user message. The review remains a separate task and commit. Every completed meta-review creates a mandatory compaction boundary.
Risks: The current Codex desktop toolset exposes no callable context-compaction API. In that environment the agent must emit an explicit `/compact` handoff and stop; it cannot truthfully claim that an assistant-authored text command compacted the host conversation. Address-input implementation is preserved as T-286.
```

```text
Date: 2026-07-11
Task: T-284 - Periodic meta-review.
Files changed: Current-state migration/meta-review markers; Feature Index Pet Name contract; task-ledger closeout; worklog closeout.
Checks: Branch/status/recent history; 63-file migration mirror; active roadmap/index/task/current-state consistency; root Markdown ignore state; conflict-marker scan; `node scripts/context-hygiene-check.mjs`; `git diff --check`.
Result: Active branch, task sequence, migration mirror, links, rolling windows, root ignore behavior, and conflict state align. Corrected CURRENT_STATE's last remote migration from T-263 to T-283 and Feature Index's superseded 80-character Pet Name statement to the active 20-character pre-display limit. No workflow, app, or backend behavior changed.
Risks: APP_STATUS_OVERVIEW.md and V1.0_RELEASE_TASK_PLAN.md remain ignored review input rather than active truth. Q-104 and APNs remain unchanged. The user's address-input requirement is preserved as T-285 rather than mixed into this governance task.
```

```text
Date: 2026-07-11
Task: T-283 - Groomer Availability save and Request match recovery.
Files changed: T-283 avatar relationship RLS migration; migration contract tests; memory closeout.
Checks: Remote log/SQL diagnosis; migration RED/GREEN plus all 53 migration tests; Matching TestOps unit tests; `./scripts/supabase-check.sh`; linked migration list/dry-run/push/alignment; rollback-only authenticated profile-update and availability-backfill verification; Supabase security/performance advisors; `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; diff/preflight/context hygiene.
Result: T-263's profiles avatar policy had created the recursive path groomer_profiles -> profiles -> bookings -> groomer_profiles, so Availability stopped at updateProfile and never persisted weekly hours. T-283 moves offer/booking relationship checks into a private SECURITY DEFINER helper with explicit current-customer validation, preserving the avatar access boundary without recursive RLS. A rollback-only remote test proved the affected Groomer can update the owned profile and that temporarily enabling Sunday immediately backfills the affected open Request through the existing T-155 trigger.
Risks: The rollback verification intentionally did not retain the user's attempted Sunday setting or create a permanent match. The Groomer must retry Save Availability with the intended days; the currently open Sunday Request will then backfill automatically. Security advisor retains the existing leaked-password-protection warning; performance advisor is clear.
```

```text
Date: 2026-07-11
Task: T-282 - Reusable pre-edit text-length interception.
Files changed: Shared form primitives; Edit Pet Name field; Request address fields; focused limit tests; memory closeout.
Checks: Customer Pets and Requests focused tests; `./scripts/ios-build.sh`; `git diff --check`; preflight/context hygiene.
Result: BeckonLimitedTextField uses UITextFieldDelegate to calculate and apply the allowed edit before UIKit displays it. Rapid typing cannot pass the limit, and oversized paste accepts only remaining capacity. The component owns reusable red border/cursor feedback and now enforces Pet Name 20, Request street 160, city 100, and ZIP 5 while preserving address suggestions and validation clearing.
Risks: The reusable control is intentionally single-line; existing multiline care/service-note fields remain SwiftUI TextFields. A legacy pure Pet Name helper remains for incremental test-binary compatibility but is not used by production input. No backend or remote state changed.
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



















This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.
