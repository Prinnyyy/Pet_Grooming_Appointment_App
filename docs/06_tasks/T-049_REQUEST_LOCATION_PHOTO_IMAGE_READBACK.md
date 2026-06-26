# T-049 Request Location, Photo Upload, and Image Readback

Mode: Deep

Date: 2026-06-26

## User Request

Fix code-review findings:

- Request wizard service location fields were local-only and dropped on publish.
- Request wizard Add Photo was a local placeholder.
- Uploaded pet and portfolio images were stored but not rendered back as images in UI.

## Primary Task

Persist the request wizard location inputs, make Add Photo use the existing pet-photo upload path, and render uploaded pet/portfolio Storage images through signed URLs without creating duplicate backend data paths.

## Scope

Included:

- Add request location mode, street address, and travel range to request models, repository rows, RPC parameters, and local migration.
- Wire wizard location controls to `CustomerRequestsStore` and include them in request drafts.
- Replace the wizard Add Photo placeholder with `PhotosPicker` upload to the selected pet's existing photo repository path.
- Render pet photos, request photo snapshots, and groomer portfolio photos with a shared signed-URL thumbnail component.
- Add targeted Store tests for request location draft persistence and wizard photo upload.

Out of scope:

- Remote Supabase migration apply. This run did not perform remote schema writes.
- A new request-specific photo table. Request photos continue to use existing pet photo metadata and the existing request `photo_snapshot`.
- Image transforms, caching layers, moderation, or attachment features.

## Implementation Plan

1. Add red Store tests for persisted request location fields and Add Photo upload behavior.
2. Extend request models/repositories and Supabase RPC parameters for location mode, street address, and travel range.
3. Add a local Supabase migration for request location columns, RPC signature/body, and matched-groomer pet-photo Storage read policy.
4. Add a signed Storage URL provider and shared SwiftUI thumbnail component.
5. Wire customer pet, customer request, groomer request, and groomer portfolio surfaces to show image thumbnails.
6. Run targeted tests, build validation, diff check, and simulator launch.

## Code Review Fix Record

Template: `docs/06_tasks/CODE_REVIEW_FIX_TASK_TEMPLATE.md`

Review source:

- Reviewer/source: user-provided code review findings.
- Reviewed branch/commit/scope: current local workspace; reviewed files named in the user request.
- Review date: 2026-06-26.

Review findings:

| Finding ID | Priority | Finding | Evidence | Impact | Decision |
|---|---|---|---|---|---|
| CR-049-1 | P1 | Request wizard location inputs were silently dropped. | `CustomerRequestsView.swift`, `CustomerRequestsStore.swift`, `SupabaseCustomerRequestRepository.swift`, `20260621000444_t012_grooming_request_match_backend.sql` | Customer-selected service mode, street address, and travel range could not affect publish/readback. | fix |
| CR-049-2 | P2 | Request wizard Add Photo was a local placeholder. | `CustomerRequestsView.swift` | Users could believe a photo was attached when no upload or draft data changed. | fix |
| CR-049-3 | P2 | Uploaded pet and portfolio images could not render back as images. | `CustomerPetsView.swift`, `GroomerProfileManagementView.swift`, Storage repositories | Existing uploaded files were shown only as metadata instead of thumbnails. | fix |

Fix matrix:

| Finding ID | Root Cause | Fix Summary | Primary Files | Tests/Checks | Status |
|---|---|---|---|---|---|
| CR-049-1 | Request location mode/address/range had no model, draft, repository, RPC, or table fields. | Added `GroomingRequestLocationMode`, request draft/model fields, row decoding, RPC parameters, detail display, and local migration columns/RPC signature. | `CustomerRequest.swift`, `GroomerRequest.swift`, `CustomerRequestsStore.swift`, `SupabaseCustomerRequestRepository.swift`, `SupabaseGroomerRequestRepository.swift`, `20260626175855_t049_request_location_and_image_readback.sql` | Targeted `CustomerRequestsStoreTests`, `./scripts/ios-build.sh`, `git diff --check`, simulator launch. | fixed locally |
| CR-049-2 | The Add Photo tile only toggled local placeholder state. | Replaced the placeholder tile with `PhotosPicker`, loaded image data, and uploaded through `CustomerPetRepository.uploadPhoto` for the selected pet. | `CustomerRequestsView.swift`, `CustomerRequestsStore.swift`, `CustomerRequestFeatureTests.swift` | Added `wizardPhotoUploadAddsPhotoForSelectedPet`; targeted Store tests passed. | fixed |
| CR-049-3 | UI had metadata rows but no signed URL provider or `AsyncImage` thumbnail path. | Added `StorageImageURLProvider`, Supabase signed URL adapter, shared `GroomlyStorageImageThumbnail`, and wired thumbnails into pet, request, groomer request, and portfolio surfaces. | `StorageImageURLProvider.swift`, `SupabaseStorageImageURLProvider.swift`, `GroomlyStorageImageThumbnail.swift`, `CustomerPetsView.swift`, `CustomerRequestsView.swift`, `GroomerRequestsView.swift`, `GroomerProfileManagementView.swift` | `./scripts/ios-build.sh`, XcodeBuildMCP `build_run_sim` with no diagnostics warnings/errors. | fixed locally |

Remote or external actions:

- Supabase remote migration apply: yes, required before hosted request publish validation.
- Remote data writes: not performed.
- Git commit/push/PR: not performed.
- Third-party service changes: not performed.
- Approval status: not approved for remote writes in this run.

## Closeout

Status: completed

Review finding outcomes:

| Finding ID | Outcome | Evidence |
|---|---|---|
| CR-049-1 | fixed locally | Request location fields flow through local code and migration; hosted Supabase still needs remote migration apply before publish validation. |
| CR-049-2 | fixed | Wizard Add Photo now uses `PhotosPicker` and selected-pet upload through the existing repository path. |
| CR-049-3 | fixed locally | Signed URL thumbnail UI is wired into pet/request/portfolio surfaces; matched-groomer pet-photo read access depends on the local T-049 migration being applied remotely. |

Changed files:

- `docs/06_tasks/T-049_REQUEST_LOCATION_PHOTO_IMAGE_READBACK.md`
- `docs/06_tasks/CODE_REVIEW_FIX_TASK_TEMPLATE.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`
- `supabase/migrations/20260626175855_t049_request_location_and_image_readback.sql`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/App/`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/CustomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/StorageImageURLProvider.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/GroomlyStorageImageThumbnail.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/GroomerRequestFeatureTests.swift`

Validation:

- TDD red check failed before implementation because `GroomingRequestDraft` had no location mode/address/range fields and `CustomerRequestsStore` had no selected-pet photo upload API.
- Targeted green check passed:
  - `xcodebuild -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests test`
- `git diff --check` passed after code and documentation updates.
- `./scripts/ios-build.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 16 Pro` simulator (`4CB97394-9112-4FBB-8C99-628B416B922F`) with no diagnostics warnings or errors. Screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_1f9a344d-8520-4d14-ad21-a5a57310018e.jpg`.

Additional checks:

- `./scripts/ios-test.sh --filter CustomerRequestsStoreTests` was attempted, but the script ignores `--filter` and ran the whole test action; the app UI smoke test failed independently while the new Store tests passed after the implementation fix.
- `supabase migration list --local` was attempted as a non-writing local check, but it could not connect because local Postgres on `127.0.0.1:54322` was not running.

Risks:

- The T-049 migration is local only in this run. Remote publish with the new request fields requires applying `supabase/migrations/20260626175855_t049_request_location_and_image_readback.sql` to Supabase first.
- Request Add Photo uploads to the selected pet's existing pet-photo path, then request creation snapshots existing pet-photo metadata. It is not a request-specific attachment system.

Next:

- Apply the T-049 Supabase migration remotely with explicit user approval before validating real request publishing against the hosted project.
