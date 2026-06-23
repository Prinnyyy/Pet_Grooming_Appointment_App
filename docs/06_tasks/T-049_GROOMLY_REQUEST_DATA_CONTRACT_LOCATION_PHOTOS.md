# T-049 Groomly Request Data Contract, Location, and Photos

## Status

- Status: Completed
- Mode: Deep
- Started: 2026-06-22
- Owner: Codex
- Authorized Supabase project: `lqmasbuqzvcvtawonjlb`

## User Request

Convert grooming request service input from free text to fixed options, persist request location mode/address/travel range, add a matching service-location setting to groomer profiles, add address autocomplete and state selection in the iOS UI, and support real request photo uploads from the new request details step.

The user explicitly authorized preparing and deploying a Supabase migration to the current fresh project `lqmasbuqzvcvtawonjlb`.

## Scope

- Add a shared fixed service option contract for customer requests and groomer services.
- Add request location fields for mobile-to-customer versus customer-visits-groomer modes.
- Add the corresponding groomer service-location capability in the groomer profile.
- Add US state-code selection and stricter address validation.
- Add request photo metadata/storage support using a private Supabase Storage bucket.
- Reuse the current request wizard, groomer profile form, repository boundaries, and existing Storage upload patterns.

## Out Of Scope

- No third-party address/autocomplete SDK.
- No payment, route distance calculation, maps display, or push notification work.
- No request editing flow.
- No persistent draft photo staging before publish; selected request photos are uploaded after the request is created.

## Initial Audit

- Current request model stores `serviceType` as text and only persists city/state/ZIP.
- T-048 location mode, street address, range, and photo tiles are UI-only.
- Current groomer profile has base city/state/radius but no service-location capability.
- Existing pet and groomer portfolio photo flows already use `PhotosPicker`, `Data` upload, private Supabase buckets, metadata rows, and cleanup on metadata failure.
- Current `create_grooming_request` RPC does not match by fixed service title; it only checks that a groomer has at least one active service.

## Implementation Plan

1. Add failing iOS tests for fixed service values, location-mode draft validation, state-code handling, request photo publish/upload behavior, and groomer profile location capability.
2. Prepare a Supabase migration that adds request/groomer location fields, request photo metadata and Storage policies, service option constraints, explicit grants, and a replaced `create_grooming_request` RPC.
3. Deploy the migration through Supabase MCP only, then run metadata/rollback-query/advisor checks.
4. Implement iOS shared models, repository parameters, request photo upload flow, customer wizard UI, groomer profile UI, groomer request/customer request display updates, fakes, and previews.
5. Update backend/product docs and durable memory.

## Validation Plan

- Run targeted red tests before production implementation and verify they fail for missing behavior.
- Run the same targeted tests after implementation.
- Deploy and verify Supabase migration on `lqmasbuqzvcvtawonjlb` through MCP.
- Run Supabase metadata checks for new columns, constraints, grants, policies, bucket, and RPC signature.
- Run Supabase advisor checks and record any non-blocking findings.
- Run `git diff --check`.
- Run `./scripts/ios-build.sh`.
- Launch the app in iOS Simulator after visible app changes.

## Notes

- Apple MapKit `MKLocalSearchCompleter` is the preferred address suggestion mechanism because it is built into iOS and avoids adding a paid third-party dependency.
- Supabase Storage standard uploads are reused for request photos to stay consistent with the current pet photo and portfolio implementation. Long term, very large images should use resumable uploads or client-side compression before upload.

## Implementation Summary

- Added shared iOS taxonomy models for fixed grooming services, request/groomer location mode, US state codes, request photo metadata, request photo MIME types, and generated request photo paths.
- Replaced customer request draft `serviceType` free text with fixed enum values and persisted `locationMode`, `streetAddress`, `stateCode`, and optional `travelRadiusMiles`.
- Replaced groomer service creation/editing free-text service title with the same fixed service enum; groomer service rows still keep a generated title for presentation/backward compatibility.
- Added groomer profile `serviceLocationMode`, with UI labels that differ from customer wording while using the same backend raw values.
- Updated customer request creation UI so service is fixed options, state is a picker, address uses MapKit autocomplete, travel range is 5-100 miles only for customer-visits-groomer, and request photos use `PhotosPicker`.
- Request photos are staged in memory during the wizard and uploaded after `create_grooming_request` returns the new request ID.
- Added client-side street address validation requiring a street number and street name, plus existing city/state/ZIP validation.
- Updated Supabase customer/groomer request and groomer profile repositories, previews, and fakes for the new contract.

## Supabase Migration

- Deployed to fresh project `lqmasbuqzvcvtawonjlb` through Supabase MCP as remote migration `20260623065017_t049_request_location_photo_contract`.
- Local mirror: `supabase/migrations/20260623065017_t049_request_location_photo_contract.sql`.
- Normalized existing request/service text values into fixed service raw values: `full_groom`, `bath_and_brush`, `haircut_only`, `nail_trim`, `de_shedding`, and `custom_request`.
- Added `grooming_requests.location_mode`, `street_address`, and `travel_radius_miles` with checks for allowed modes, state/ZIP format, address length, and travel-range mode compatibility.
- Added `groomer_profiles.service_location_mode`, backfilled active profiles to `groomer_comes_to_customer`, and included it in the active-profile completeness constraint.
- Added `groomer_services.service_type` with the same fixed service check used by request creation.
- Added private `request-photos` Storage bucket with 10 MiB limit and JPEG/PNG/HEIC/HEIF MIME restrictions.
- Added `request_photos` metadata table, RLS, explicit grants, and Storage object policies for customer-owned upload/delete and matched-groomer/customer reads.
- Replaced `create_grooming_request` with the new signature that validates fixed service, location mode/address/state/ZIP/range, snapshots pet/photo metadata, and matches active groomers by service-location mode plus active fixed service type.

## Supabase Verification

- Confirmed remote migration list includes `20260623065017_t049_request_location_photo_contract`.
- Confirmed new columns, constraints, request photo policies, private bucket configuration, and `create_grooming_request` signature/grants on `lqmasbuqzvcvtawonjlb`.
- Confirmed RPC execute grants remain restricted to `authenticated`, `postgres`, and `service_role`; no `anon` execute grant.
- Confirmed existing request service values were normalized on the fresh project.
- Supabase advisor MCP was not available in this tool session; this is recorded as a tooling limitation, not a failed advisory finding.

## Validation Log

- Red test command: targeted T-049 CustomerRequestsStore/GroomerProfileStore tests were run before implementation and failed for missing models/fields as expected.
- Green test command: targeted T-049 CustomerRequestsStore/GroomerProfileStore tests passed after implementation.
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`); app launched successfully with no diagnostics warnings or errors.

## Review Follow-up

- Claude review found a real full-suite regression in `CustomerRequestsStoreTests/bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress()` that the original targeted T-049 validation missed.
- Reproduced the failure with `./scripts/ios-test.sh` before the review fix.
- Kept fixed service display as Title Case (`Full Groom`) to match `GroomingServiceType.title` and the app-wide title-copy convention.
- Added `CustomerGroomingRequest.compactLocationSummary` for compact quest action cards so the card address line stays `City, ST ZIP`, while `locationSummary` continues to expose the full street address for detail surfaces.
- Updated the handoff presentation test to assert the Title Case service title and compact location line.
- Follow-up validation: `./scripts/ios-test.sh`, `git diff --check`, and `./scripts/ios-build.sh` passed after the fix.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`) after the review fix; app launched successfully with no diagnostics warnings or errors.

## Files Changed

- `supabase/migrations/20260623065017_t049_request_location_photo_contract.sql`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomingRequestTaxonomy.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/CustomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerProfile.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/CustomerRequestRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseCustomerRequestRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerRequestRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Requests/GroomerRequestsView.swift`
- Related tests and documentation.

## Follow-up Risks

- Address autocomplete depends on Apple MapKit search availability and may return incomplete placemarks in sparse regions; the Store still validates required street/city/state/ZIP before publish.
- Request photo uploads are simple standard uploads. Large-photo compression/resumable upload can be added later if production telemetry shows failures.
- The database enforces state/ZIP/range/service/location constraints and address length; the stricter street-number/name validation is currently client-side.
