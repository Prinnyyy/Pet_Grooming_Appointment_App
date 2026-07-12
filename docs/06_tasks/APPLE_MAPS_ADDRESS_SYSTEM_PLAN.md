# Apple Maps Address System Plan

Approved direction: T-291, 2026-07-11. This is the authoritative execution plan for R-040. Adopt one package at a time from `ROADMAP_EXECUTION_QUEUE.md`; each package receives the then-current next `T-###` from `TASK_LEDGER.md`.

## Goal

Build one reusable Apple Maps address module for Customer Profile, Groomer Profile, and Customer Request flows. Address text remains presentation/user-entered data; an Apple-resolved coordinate is the authoritative matching input. Supabase PostGIS applies real distance and the correct party's radius without depending on city language.

## Product Contract

- V1 service addresses remain United States addresses because the active domain model requires `USStateCode` and US ZIP codes. This is contract validation, not an LA/Orange County ranking bias.
- Apple Maps provides autocomplete, structured address components, an optional Place ID, and WGS84 coordinates.
- Beckon calls the result `Confirmed Service Address`, never `USPS Verified`, `Deliverable`, or equivalent.
- A missing Apple Place ID does not invalidate an otherwise complete result. A complete coordinate and required US address components are mandatory.
- `Address Line 1` contains the premise street address only.
- `Address Line 2` contains optional Apt/Apartment/Unit/Suite/Ste/Floor/Fl/Building/Bldg/Room/Rm/# data.
- Unit data never changes the building coordinate or distance result.
- No Google Places, Google Address Validation, external geocoder, locale-forcing translation, or new map-first discovery belongs to this roadmap item.

## Shared Domain Contract

The shared module must expose provider-neutral value types; SwiftUI views and Stores must not retain `MKLocalSearchCompletion` or `MKMapItem`.

```swift
nonisolated struct BeckonAddressInput: Equatable, Sendable {
    var line1: String
    var line2: String
    var city: String
    var stateCode: USStateCode?
    var postalCode: String
    var countryCode: String
}

nonisolated struct BeckonAddressCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

nonisolated struct BeckonAddressCandidate: Equatable, Identifiable, Sendable {
    let id: String
    let primaryText: String
    let secondaryText: String
}

nonisolated struct BeckonResolvedAddress: Equatable, Sendable {
    let provider: String                 // "apple_maps"
    let placeID: String?                 // optional MKMapItem.Identifier string
    let coordinate: BeckonAddressCoordinate
    let suggested: BeckonAddressInput
    let resolutionSource: String         // "autocomplete_selection" or "manual_geocode"
}

nonisolated struct BeckonConfirmedAddress: Equatable, Sendable {
    let entered: BeckonAddressInput
    let accepted: BeckonAddressInput
    let provider: String
    let placeID: String?
    let coordinate: BeckonAddressCoordinate
    let resolutionSource: String
    let confirmedAt: Date
}
```

`MapKitAddressProvider` owns MapKit objects and exposes:

```swift
@MainActor
protocol BeckonAddressProviding {
    func updateSuggestions(for line1Query: String) async -> [BeckonAddressCandidate]
    func resolve(candidateID: String, preservingLine2: String) async throws -> BeckonResolvedAddress
    func geocode(_ input: BeckonAddressInput) async throws -> [BeckonResolvedAddress]
    func clear()
}
```

The provider retains candidate-ID-to-completion mappings only for the active autocomplete session. It must discard them when the editor ends or the query becomes unrelated.

## Address Line Semantics

`BeckonSecondaryAddressParser` recognizes a secondary component only as a complete suffix, optionally following a comma:

```text
Apt 5B, Apartment 5B, Unit 2410, Suite 300, Ste 300,
Floor 2, Fl 2, Building A, Bldg A, Room 12, Rm 12, #2410
```

Rules:

1. Do not move partial tokens such as `U`, `Un`, `Unit`, `A`, or `Apt` without a value.
2. When Line 2 is empty and Line 1 ends in a complete secondary component, remove that suffix from Line 1, place it in Line 2, and show `Unit 2410 was moved to Address Line 2.` using the existing global feedback center.
3. Apply the same rule to typing, paste, profile autofill, and request-template reuse.
4. If Line 2 already contains a different value, preserve both fields, mark the conflict inline, and require the user to choose one. Never overwrite silently.
5. Autocomplete always queries the parsed Line 1 base. It never sends Unit/Apt data to MapKit.
6. Line 1 validation still requires a street number and a Latin street-name character under the current US contract. Line 2 is optional, trimmed, single-line, and limited to 60 characters.
7. Use `.streetAddressLine1` and `.streetAddressLine2` text content types.

## Autocomplete Behavior

1. Start suggestions after three normalized Line 1 characters.
2. Use `MKLocalSearchCompleter` with `.address`; do not configure LA/Orange County region bias.
3. Display MapKit's returned text directly in the system-provided language. Do not reverse-geocode every visible candidate and do not translate candidate strings.
4. Preserve the last compatible suggestion set while the next query is in flight. Prefix extension/deletion is compatible; an unrelated replacement clears immediately.
5. Replace suggestions only when the newest query generation returns. Ignore stale/cancelled generations without surfacing an error.
6. Keep up to five suggestions and preserve MapKit relevance order.
7. Unit typing must not close the dropdown because the provider queries only parsed Line 1.
8. An empty final result clears the list; a transient request cancellation does not.
9. Selecting a candidate performs one `MKLocalSearch.Request(completion:)`, not one request per displayed row.
10. The floating list keeps the existing non-reflowing overlay, outside-tap dismissal, content-scroll behavior, hidden scroll indicators, and global feedback system.

## Resolution And Confirmation State Machine

```text
empty
  -> editing
  -> suggesting
  -> resolvingSelection | resolvingManualInput
  -> needsConfirmation
  -> confirmed

resolving* -> recoverableFailure -> editing
confirmed + material address edit -> editing
```

Material edits are Line 1, city, state, ZIP, or country changes. They clear Place ID, coordinate, resolution source, and confirmed timestamp immediately. Line 2-only changes preserve the building resolution but set `confirmedAt` to the new explicit confirmation time before persistence.

Candidate selection:

1. Resolve the selected completion to one `MKMapItem`.
2. Require a finite coordinate, US country code, full street, city/locality, two-letter state code, and five- or nine-digit ZIP.
3. Preserve the current Line 2 in the suggested address.
4. If MapKit returns no Place ID, retain `placeID = nil`; do not fabricate one.
5. Present Entered Address and Apple Maps Suggested Address in one confirmation sheet.

Manual entry:

1. Pressing Continue/Save without an active confirmed resolution calls `MKGeocodingRequest` once with the complete Line 1/city/state/ZIP input and no forced locale.
2. Zero complete results produces `We could not locate this service address. Check the street, city, state, and ZIP.`
3. One complete result proceeds to confirmation.
4. Multiple complete results present a selection list, then the same confirmation sheet.

Confirmation actions:

- `Use Suggested Address`: accept MapKit's structured Line 1/city/state/ZIP and preserve Line 2.
- `Edit Address`: dismiss confirmation, keep entered text, clear resolution, and focus Line 1.
- Do not offer `Keep Unverified Address`; matching requires coordinates.

## Shared SwiftUI Surface

Create one `BeckonAddressEditor` used by all three owner flows. It owns presentation only and binds to an injected `BeckonAddressEditorState`.

Required surface order:

1. Address Line 1
2. Address Line 2 (Optional)
3. City
4. State
5. ZIP Code
6. Compact status row: Editing / Locating / Confirmed with Apple Maps / Needs Review

The confirmation sheet is shared. Customer Request may present it before advancing from Time & Location; profile editors present it before Save. No screen creates a second autocomplete implementation.

Basic labels, focus order, button traits, error associations, and stable test identifiers are required. Q-104's broader Dynamic Type/Accessibility audit remains deferred and is not reactivated by this plan.

## Persistence And Privacy Contract

Enable PostGIS in the existing `extensions` schema. Exact matching metadata lives in a private table inaccessible through the Data API:

```sql
create table app_private.address_locations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider = 'apple_maps'),
  place_id text,
  country_code text not null check (country_code = 'US'),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  location extensions.geography(point, 4326) generated always as (
    extensions.st_setsrid(extensions.st_makepoint(longitude, latitude), 4326)::extensions.geography
  ) stored,
  resolution_source text not null check (
    resolution_source in ('autocomplete_selection', 'manual_geocode', 'legacy_backfill')
  ),
  user_confirmed_at timestamptz not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp()
);
```

Add a GiST index on `location`, an owner index, and nullable `address_location_id` foreign keys on `customer_profiles`, `groomer_profiles`, and `grooming_requests`. Authenticated clients receive no schema usage or table privileges for `app_private.address_locations`.

Existing display fields remain separate:

- Customer: `street_address` becomes Line 1 and new `address_line_2` stores optional secondary data.
- Groomer: `base_street_address` becomes Line 1 and new `base_address_line_2` stores optional secondary data.
- Request: `street_address` becomes Line 1 and new `address_line_2` stores the request-time snapshot.

Owner-checked private functions atomically save display fields and location metadata. Public security-invoker wrappers expose only the minimum mutation contract. Request publication uses a versioned `create_grooming_request_v2`; do not create ambiguous overloads with default parameters.

No token, complete Place ID, coordinate, or exact address is written to Debug Console metadata. Log only source, completion state, candidate count, failure class, and a short correlation ID.

## Distance Matching Contract

`app_private.create_request_matches_for_request` remains the single insertion path.

For rows with both private locations:

```text
distance_miles = ST_Distance(request.location, groomer.location) / 1609.344

customer_comes_to_groomer:
  allowed_radius = request.travel_radius_miles

groomer_comes_to_customer:
  allowed_radius = groomer_profile.service_radius_miles

eligible when distance_miles <= allowed_radius
```

The location score stays within the existing 60...80 contribution:

```text
location_score = round(80 - 20 * min(distance_miles / allowed_radius, 1))
```

The match reason reports rounded distance and controlling radius, for example `4.2 miles away, within the customer's 15-mile travel range`. City language, case, street spelling, ZIP, and Place ID never determine eligibility once both coordinates exist.

During migration only, if either side lacks coordinates, retain the current state/city fallback and mark the reason `Legacy location fallback`. Never mix coordinate and text scoring in one match. Remove this fallback only after the backfill gate reports zero active address owners/requests without coordinates.

Service type, location mode, active profile/service, pet fit, time off, minimum advance notice, daily capacity, and exact offer/acceptance availability rules remain unchanged.

## Existing Data Backfill

Current remote evidence at plan time: 51/51 Groomers have complete base addresses and service radii; 51 Customer profiles have addresses. PostGIS is available but not enabled.

Build a macOS-only, dry-run-default backfill tool that:

1. Requires service-role credentials from ignored environment configuration and `ADDRESS_BACKFILL_REMOTE_WRITE_APPROVED=1` plus `--execute` for writes.
2. Reads only rows with complete display addresses and missing `address_location_id`.
3. Resolves each base address with Apple Maps using no Unit/Apt suffix.
4. Rejects zero-result, multi-result-without-exact-components, non-US, missing-coordinate, and incomplete-component cases into a manual-review artifact.
5. Writes through a service-role-only backfill RPC; it never directly changes Auth users.
6. Processes Groomer profiles, Customer profiles, then active/open Request snapshots.
7. Records counts and redacted support references, never full addresses or credentials.
8. Reruns in verification mode and proves zero unreviewed active rows before strict cutover.

Remote migration, extension enablement, backfill, and fallback removal each require explicit authorization at their execution gate.

## Execution Packages

### Q-105 Shared address domain and parser

Files: shared address models/provider/parser, focused Swift tests, and shared test fixtures.

Steps:

1. Write RED tests for all secondary suffixes, comma handling, partial tokens, occupied-Line-2 conflict, Unit-preserving MapKit query, and material-edit invalidation.
2. Add provider-neutral domain values and `BeckonSecondaryAddressParser`.
3. Replace T-289/T-290 English-candidate batch logic with direct completer candidates and selected-only resolution.
4. Add query-generation retention tests proving `770 S` -> `770 S H` never clears compatible suggestions and `Unit 2410` queries the same base street.
5. Run focused address tests, `./scripts/ios-build.sh`, and `git diff --check`.

Exit: one tested non-UI state/provider layer; no backend or remote change.

### Q-106 Shared editor and confirmation UI

Files: reusable address editor, confirmation sheet, form primitives, focused presentation tests.

Steps:

1. Build `BeckonAddressEditor` and one suggestion overlay around the Q-105 state.
2. Add Address Line 2, auto-move notice, conflict state, status row, and confirmation comparison.
3. Preserve content scrolling, outside-tap dismissal, keyboard behavior, and global feedback routing.
4. Add stable selectors and basic accessibility semantics without starting Q-104.
5. Validate focused tests and one iOS build; user remains the visual reviewer.

Exit: reusable editor works with an in-memory provider fixture and no feature-specific persistence.

### Q-107 PostGIS and private location contract preparation

Files: append-only migration, SQL rollback-only tests, Supabase contract docs.

Steps:

1. Add RED migration tests for private privileges, coordinate constraints, generated geography, GiST index, versioned RPCs, and radius semantics.
2. Enable PostGIS in `extensions` and create `app_private.address_locations`.
3. Add address-line-2/address-location references and owner-checked profile/request mutations.
4. Replace location eligibility/scoring in the reusable match helper while retaining explicit legacy fallback.
5. Test both travel directions, exact radius boundary, outside-radius exclusion, multilingual city invariance, null-coordinate fallback, and unchanged time/service/pet-fit gates.
6. Run migration tests and `./scripts/supabase-check.sh`.

Exit: locally validated migration only. Stop for fresh remote-migration authorization.

### Q-108 Authorized remote schema application

Steps:

1. Verify linked project identity and migration history using the documented Supabase MCP/SQL path.
2. Apply only the reviewed append-only migration.
3. Run rollback-only radius, privilege, RLS/RPC, and multilingual-city tests.
4. Run security/performance advisors and record only new task-relevant findings.
5. Do not backfill addresses in this package.

Exit: remote schema/RPC contract exists with legacy fallback active.

### Q-109 Customer and Groomer Profile integration

Files: both profile Stores/repositories/views, profile fixtures/tests, Debug events.

Steps:

1. Replace both profile address forms with `BeckonAddressEditor`.
2. Load confirmed address metadata through owner-scoped RPCs.
3. Require confirmation before saving a changed address; unchanged legacy addresses remain editable during backfill.
4. Save display fields and private location atomically.
5. Ensure profile autofill exports Line 1, Line 2, structured components, and confirmed location metadata to Request drafts.
6. Test save/reload, edit invalidation, Unit-only edits, no-Place-ID coordinates, cancellation, and cache behavior.

Exit: new/edited profile addresses become coordinate-backed.

### Q-110 Customer Request integration

Files: Request Store/model/repository/wizard/detail, RPC v2 DTOs, focused tests.

Steps:

1. Replace Request address fields with the shared editor.
2. Make profile autofill retain confirmation only when the profile location metadata is current.
3. Require confirmation before leaving Time & Location.
4. Publish through `create_grooming_request_v2` and snapshot Line 1/Line 2 plus private coordinate reference atomically.
5. Keep republish/template drafts unconfirmed until the user reviews the address.
6. Display Line 2 only where the participant/address-release contract permits it.
7. Test multilingual display with coordinate-equivalent matching, both radius directions, and request cancellation/republish.

Exit: every newly published Request is coordinate-backed and radius-matchable.

### Q-111 Controlled legacy backfill

Files: dry-run backfill tool, unit tests, ignored artifacts, TestOps run record.

Steps:

1. Implement parser/geocoder/report units and remote-write safety gates.
2. Run dry-run for Groomers, Customers, and active Requests.
3. Review ambiguous/missing results; never accept by nearest distance alone.
4. Obtain explicit remote-write authorization.
5. Execute, verify counts, rerun dry-run, and prove zero tagged or partial writes.
6. Run Matching TestOps for near/edge/outside radius and both service directions.

Exit: every active location has a reviewed private coordinate or a documented blocking exception.

### Q-112 Strict coordinate cutover and integration gate

Steps:

1. Add RED SQL tests proving active matching never enters text fallback.
2. Remove legacy state/city eligibility and fallback reason only after Q-111 reports zero active gaps.
3. Run full local iOS tests/build, migration tests, Supabase checks/advisors, lifecycle TestOps, Matching TestOps, privacy review, preflight, and context hygiene.
4. Verify no production copy claims postal deliverability and no screen has an independent address implementation.

Exit: coordinates/radii are the only active location-matching authority.

## Validation Matrix

Required focused cases:

- `770 S` -> `770 S H` retains a visible compatible candidate set.
- `770 S Harbor Blvd Unit 2410` becomes Line 1 `770 S Harbor Blvd`, Line 2 `Unit 2410`.
- Existing Line 2 conflict is never overwritten.
- Candidate without Place ID but with complete coordinate/components can be confirmed.
- Manual input with zero or multiple results cannot silently publish.
- Line 1/city/state/ZIP edits invalidate confirmation; Line 2 edits preserve the coordinate.
- Chinese-device candidate text may remain localized while the same coordinate matches the same Groomer.
- Customer travel radius and Groomer service radius control the correct direction.
- Exactly-on-radius is eligible; over-radius is not.
- Time, service, pet-fit, capacity, and offer/booking safety remain unchanged.
- Authenticated clients cannot query private Place IDs or coordinates directly.

## Stop Conditions

- Stop if Apple returns no complete coordinate for an existing active address; do not invent coordinates.
- Stop before PostGIS/migration/backfill/remote TestOps without task-specific authorization.
- Stop if migration history, project identity, or private privilege evidence conflicts.
- Stop if a change would expose exact coordinates or complete Place IDs through the public Data API.
- Stop strict cutover while any active coordinate gap remains.
