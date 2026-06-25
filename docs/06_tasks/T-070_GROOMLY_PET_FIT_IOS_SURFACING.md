# T-070 Groomly Pet-Fit iOS Surfacing

## Status

Completed on 2026-06-25.

## Goal

Surface the existing backend-generated match score and match reason in the groomer request/offer UI more deliberately, without changing matching, repositories, Supabase schema, RLS, Storage, or request/offer/booking lifecycle behavior.

## Scope

- Add a small model-level presentation helper for groomer match fit evidence.
- Show the fit evidence in the groomer matched-request list and request detail.
- Keep the existing `GroomerMatchedRequest`, `GroomerRequestMatch`, repository, and Supabase fields as the only data source.
- Do not add a customer groomer directory, direct booking, new RPC, new table/view, or client-authored matching logic.

## Plan

1. Write RED tests for fit-evidence presentation from existing `matchScore` and `matchReason`.
2. Add the minimal model presentation helper.
3. Update `GroomerRequestsView` to show the presentation in the list and Match detail card.
4. Update this closeout and durable memory after validation.

## Validation Plan

- Targeted `GroomerRequestsStoreTests` for the new presentation behavior.
- `git diff --check`.
- `./scripts/ios-build.sh`.
- Simulator launch because this changes visible iOS UI.

## Implementation

- Added `GroomerMatchFitPresentation` and `GroomerMatchedRequest.fitEvidencePresentation` in the groomer request model.
- Trimmed and ignored blank backend `matchReason` values instead of drawing empty evidence UI.
- Added a reusable `GroomerFitEvidenceBlock` in `GroomerRequestsView`.
- Surfaced the existing backend-generated score/reason in groomer matched-request rows and the request detail Match card.
- Updated the preview fixture to show a T-069-style pet-fit reason.

## Validation

- RED targeted tests failed as expected because `GroomerMatchedRequest` had no `fitEvidencePresentation` member.
- GREEN targeted tests passed:
  - `PetGroomerMarketplaceTests/GroomerRequestsStoreTests/fitEvidencePresentationUsesBackendReasonAndRoundedScore`
  - `PetGroomerMarketplaceTests/GroomerRequestsStoreTests/fitEvidencePresentationIgnoresBlankReason`
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed for `platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro`.
- XcodeBuildMCP installed and launched `com.prinnyyy.PetGroomerMarketplace` on `iPhone 17 Pro` iOS 26.5 simulator `45D452E8-DC6C-4CD4-A747-4D21671E68A6`; launch succeeded with pid `39820`.
- XcodeBuildMCP screenshot confirmed the app reached a visible Groomer Requests root screen.

## Risks and Non-Goals

- No repository, Supabase schema, RLS, Storage, RPC, or migration changes.
- No customer groomer directory, direct booking, customer offer-review fit surfacing, matching-score calculation, availability enforcement, or lifecycle change.
- The new UI displays only the backend-generated reason already available on `request_matches.match_reason`.
