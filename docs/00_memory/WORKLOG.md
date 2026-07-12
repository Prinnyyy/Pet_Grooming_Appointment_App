# Worklog

```text
Date: 2026-07-11
Task: T-296 - Authorized remote PostGIS address schema application.
Files changed: Remote Beckon schema state plus backend contract, access matrix, roadmap queue, feature/task/current-state, and Worklog closeout.
Checks: Linked Beckon identity and only-pending dry-run; remote migration push; rollback-only private privilege, owner RPC, cross-role denial, exact/outside radius, both service directions, multilingual-city, and legacy fallback tests; zero fixture residue and zero backfill; aligned migration history and clean repeat dry-run; security/performance advisors; Supabase contract and focused migration tests; diff/context/preflight.
Result: Completed Q-108. PostGIS and private address locations are deployed with opaque public references, owner-checked profile RPCs, Request v2, and direction-correct distance matching. Authenticated clients cannot select/insert private locations. The rollback transaction created two generated geography rows then removed all fixtures; remote address/location references remain zero until later integration/backfill tasks.
Risks: Advisor INFO for the no-policy private table is expected because clients have no schema/table grants; new indexes are unused because Q-108 intentionally created no location rows. Existing leaked-password and unrelated index findings are unchanged. Legacy state/city fallback must remain until Q-112 proves a zero active-coordinate gap.
Next: Use T-297 for Q-109 Customer and Groomer Profile address integration; Q-104 remains deferred.
```

```text
Date: 2026-07-11
Task: T-295 - Periodic meta-review.
Files changed: Current-state, task-ledger, feature-index, and Worklog governance closeout.
Checks: Clean branch and origin alignment; active root/ignore/seed visibility; conflict scan; 64-file migration mirror; linked migration history; docs tests; context hygiene; diff/preflight.
Result: Active Markdown structure and routing remain sound. Q-105 through Q-107 are represented consistently as local implementation, and T-295 is the latest meta-review. Linked history confirms `20260712014418` is pending, matching the clarified instruction to continue the migration task next.
Risks: T-296 must recheck linked project identity/history immediately before applying the migration and must not backfill addresses.
```

```text
Date: 2026-07-11
Task: T-294 - PostGIS private address contract preparation.
Files changed: Append-only T-294 PostGIS/private address migration; Address Line 2 and opaque location references; owner-checked profile read/write wrappers; coordinate-backed Request v2 RPC; private direction-correct location-fit helper; upgraded reusable match insertion; rollback-only runtime validation; migration contract tests; backend/queue/memory docs.
Checks: Supabase current docs/changelog review; linked Beckon/Postgres 17.6 identity, migration history, and extension availability via MCP; forced RED then six focused T-294 contracts; all 59 migration tests; `./scripts/supabase-check.sh`; `supabase db push --linked --dry-run` showing only T-294; `git diff --check`; context hygiene; preflight.
Result: Completed Q-107 locally. The prepared migration enables PostGIS in `extensions`, keeps coordinates and optional Apple Place IDs in an RLS-enabled private table with no authenticated table grants, adds GiST/owner/FK indexes, and exposes only owner-checked profile wrappers plus `create_grooming_request_v2`. Coordinate matches use Customer travel radius or Groomer service radius according to service direction and a 60...80 distance score; legacy state/city fallback is explicit only when either point is missing. Existing service, pet-fit, availability, time-off, advance-notice, capacity, and notification paths remain intact.
Risks: PostGIS is available but still remotely uninstalled, and T-294 is not deployed. The rollback SQL has static contract coverage but cannot execute locally because Docker/Postgres are unavailable; Q-108 must apply only this migration, then run the rollback transaction, privilege checks, both radius directions, multilingual-city case, migration history, and advisors before any profile/request integration.
```

```text
Date: 2026-07-11
Task: T-293 - Shared Apple Maps address editor and confirmation UI.
Files changed: Provider-injected Address Editor state and SwiftUI surface; candidate overlay; Line 2 feedback/conflict handling; status row; manual-choice and entered-vs-suggested confirmation sheets; stable selectors; focused tests; queue and memory closeout.
Checks: Forced RED for missing shared Editor contracts; nine focused Address Editor tests; `./scripts/ios-build.sh`; `git diff --check`; context hygiene; preflight.
Result: Completed Q-106. One reusable Editor owns Address Line 1, optional Line 2, city, state, ZIP, direct MapKit candidates, compact status, recoverable validation, and explicit Apple Maps confirmation. Complete secondary suffixes auto-move through the global feedback center, occupied Line 2 conflicts stay inline, ordinary typing preserves trailing spaces, compatible candidates remain visible during refresh, and multiple manual results transition into the same final confirmation sheet. Basic labels, traits, error semantics, and selectors are included without reactivating Q-104.
Risks: The component is intentionally not wired into Customer/Groomer Profile or Request persistence yet; Q-109/Q-110 own those integrations after the private location contract exists. No migration or remote write occurred in T-293, and visual approval remains with the user when feature pages adopt the component.
```

```text
Date: 2026-07-11
Task: T-292 - Shared Apple Maps address domain and parser.
Files changed: Provider-neutral address input/candidate/resolved/confirmed values; Apple Maps provider contract; complete secondary-address parser; compatible-query retention; selected/manual resolution; focused tests; queue and memory closeout.
Checks: Forced RED for missing Q-105 contracts; Customer Requests focused suite; `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; context hygiene.
Result: Completed Q-105. Address Line 1 now extracts only complete Apt/Apartment/Unit/Suite/Ste/Floor/Fl/Building/Bldg/Room/Rm/# suffixes, preserves partial tokens, and never overwrites a conflicting Line 2. Provider-neutral confirmation models distinguish material building edits from Line 2-only changes. MapKit autocomplete now publishes up to five direct localized candidates, retains compatible results while the next query loads, performs one search only after selection, and supports Apple manual geocoding without forced translation.
Risks: Current Request/Profile forms still use their existing presentation and persistence contracts; the reusable editor/confirmation surface belongs to Q-106 and coordinate persistence begins only after Q-107/Q-108. No migration or remote write occurred in T-292.
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


























This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived under `docs/09_frozen/worklogs/`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Only the newest entry should keep a `Next:` line.
